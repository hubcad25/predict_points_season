## This script loads all the IVs from the moneypuck/lines files into one table containing all seasons.
## It does not make any transformations to the data.

options(scipen = 999)

# Packages ---------------------------------------------------------------
library(dplyr)

# Data -------------------------------------------------------------------

df_player_infos <- readRDS("data/warehouse/player_infos.rds") |> 
  mutate(player_id = as.character(player_id))

lake_files <- list.files(
  path = "data/lake/moneypuck",
  pattern = "lines_*",
  full.names = TRUE
)

for (i in lake_files){
  outputi <- readRDS(i) %>% 
    mutate(
      id = paste0(season, "_", 1:nrow(.)),
      player_id_1 = substr(lineId, 1, 7),
      player_id_2 = substr(lineId, 8, 14),
      player_id_3 = substr(lineId, 15, 22)
    ) |> 
    #tidyr::separate(
    #  col = name,
    #  into = paste0("name_", 1:3),
    #  sep = "-",
    #  remove = FALSE
    #) |> 
    select(
      line_id = lineId,
      id,
      season,
      starts_with("name"),
      team,
      position,
      starts_with("player_id"),
      icetime
    )
  if (i == lake_files[1]){
    output_dirty <- outputi
  } else {
    output_dirty <- rbind(output_dirty, outputi)
  }
  message(i)
}

# Clean player_ids -------------------------------------------------------

## For each player_id, look up the last name of the player
## Check if this last_name is the same as one of the last names in lines data
## If not, lookup the most probable player_id of last name given the team and 

df_validate_player_ids <- output_dirty %>% 
  tidyr::pivot_longer(
    cols = starts_with("player_id"),
    names_to = "pos",
    values_to = "player_id"
  ) %>% 
  left_join(
    ., df_player_infos[, c("player_id", "last_name")],
    by = "player_id"
  ) |>
  rowwise() |> 
  mutate(
    last_name = iconv(last_name, from = "UTF-8", to = "ASCII//TRANSLIT"),
    player_in_name = as.numeric(grepl(tolower(last_name), tolower(name)))
  ) |> 
  ungroup() |> 
  mutate(
    player_in_name = ifelse(is.na(player_in_name), 0, player_in_name),
    player_in_name = ifelse(position == "pairing", NA, player_in_name)
  )

table(df_validate_player_ids$player_in_name, df_validate_player_ids$pos)
## so pid_1 and pid_2 have a couple mismatch which is normal. Most of them are due to small differences in names from moneypuck and nhl api
## player_id_3 is systematically wrong

# Get each team roster for each year -------------------------------------
get_team_roster_past <- function(team, season) {
  change_teams <- c("N.J" = "NJD", "S.J" = "SJS", "T.B" = "TBL", "L.A" = "LAK")
  if (team %in% names(change_teams)){
      team <- change_teams[team]
  }
  if (team == "ARI" & season <= 2013){
    team <- "PHX"
  }
  url <- paste0("https://api-web.nhle.com/v1/roster/", team, "/", as.character(season), as.character(season + 1))
  if (team == "ARI" & season == 2023){
    url <- paste0("https://api-web.nhle.com/v1/roster/UTA/20242025")
  }
  page <- httr::GET(url)
  content <- httr::content(page)
  lineup <- list(
    forwards = sapply(content$forwards, function(x) setNames(x$id, x$lastName$default)),
    defensemen = sapply(content$defensemen, function(x) setNames(x$id, x$lastName$default))
  )
  message(team, season)
  return(lineup)
}

list_past_rosters <- setNames(
  lapply(sort(unique(df_validate_player_ids$team)), function(x){
    years <- 2008:2023
    if (x == "SEA"){
      years <- 2021:2023
    }
    if (x == "VGK"){
      years <- 2017:2023
    }
    setNames(lapply(years, get_team_roster_past, team = x), as.character(years))
  }),
  sort(unique(df_validate_player_ids$team))
)

backup <- df_validate_player_ids

for (i in 149371:length(unique(df_validate_player_ids$id))){
  idi <- unique(df_validate_player_ids$id)[i]
  df_line <- df_validate_player_ids |>
    filter(id == idi)
  positioni <- ifelse(df_line$position[1] == "line", "forwards", "defensemen")
  if (positioni == "forwards"){
    names <- unlist(stringr::str_split(df_line$name[1], pattern = "-"))
    third_player_last_name <- names[!(tolower(names) %in% tolower(df_line$last_name))]
    if (purrr::is_empty(third_player_last_name)){
      third_player_last_name <- names(which.max(table(names)))
    }
    if (length(third_player_last_name) > 1 & length(names) > 3){
      third_player_last_name <- paste0(third_player_last_name, collapse = " ")
    }
    if (length(third_player_last_name) > 1){
      dist_matrix <- stringdist::stringdistmatrix(names, third_player_last_name)
      # Trouver l'indice du minimum
      min_index <- which(dist_matrix == min(dist_matrix), arr.ind = TRUE)[1, 1]
      third_player_last_name <- names[min_index]
    }
    teami <- df_line$team[1]
    seasoni <- df_line$season[1]
    team_roster <- list_past_rosters[[teami]][[as.character(seasoni)]]$forwards
    distances <- stringdist::stringdist(
      a = stringi::stri_trans_general(
        third_player_last_name, "Latin-ASCII"),
      b = stringi::stri_trans_general(names(team_roster), "Latin-ASCII")
    )
    player_id <- team_roster[which(distances == min(distances))][1]
    warn <- tryCatch({
      df_validate_player_ids$player_id[df_validate_player_ids$id == idi & !(df_validate_player_ids$last_name %in% names)] <- as.character(player_id)
      df_validate_player_ids$last_name[df_validate_player_ids$id == idi & !(df_validate_player_ids$last_name %in% names)] <- names(player_id)
    }, warning = function(w) {
      message(sprintf("Warning occurred at iteration %d: %s", i, conditionMessage(w)))
      })
  } else {
  }
  if (i %% 100 == 0){
    saveRDS(df_validate_player_ids, "data/warehouse/lines_dirty.rds")
    message(i)
  }
}

df_last_validation <- df_validate_player_ids |> 
  rowwise() |> 
  mutate(
    player_in_name = as.numeric(grepl(tolower(last_name), tolower(name)))
  ) |> 
  ungroup() |> 
  mutate(
    player_in_name = ifelse(is.na(player_in_name), 0, player_in_name),
    player_in_name = ifelse(position == "pairing", NA, player_in_name)
  )

table(df_last_validation$player_in_name, df_last_validation$pos)
## It looks OK. 742 / 150k is OK

output <- df_last_validation |> 
  tidyr::pivot_wider(
    id_cols = c(line_id, id, season, name, team, position, icetime),
    names_from = "pos",
    values_from = "player_id"
  )

## Save it
saveRDS(output, "data/warehouse/lines.rds")
