# Packages ---------------------------------------------------------------
library(DBI)
library(RPostgres)
library(dplyr)
library(googlesheets4)
#options(scipen = 999)

setwd("~/Dropbox/Hockey/predict_points_season")

# Connect to SQL db to get MSHL lineups ----------------------------------
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = 'dbpool',
  host = 'intently-obliging-whippoorwill.data-1.use1.tembo.io',
  port = 5432,
  user = 'postgres',
  password = 'VbMOHfh76LsozTRi'
)

alignements <- dbGetQuery(con, paste0(
  "SELECT idpooler, idnhl, statutjoueur, prop_caphit 
   FROM alignements 
   WHERE TO_DATE(datefin, 'YYYY-MM-DD') > '", Sys.Date(), "'::date 
   AND (statutjoueur <> 'SalaireRetenu' OR (statutjoueur = 'SalaireRetenu' AND idpooler = 'PAT'))"
)) |> 
  rename(
    mshl_team = idpooler,
    player_id = idnhl,
    player_status = statutjoueur,
    prop_cap_hit = prop_caphit
  )

dbDisconnect(con)

# Get draft from google sheets -------------------------------------------
gs4_auth(email = "hubertcadieux@gmail.com", cache = TRUE)
df_players_drafted <- read_sheet(
  "https://docs.google.com/spreadsheets/d/17yLc8AGZqzEcUlkf_suthMe_83kkP8Mt-zg97VGKDuI/edit?gid=788317089#gid=788317089",
  sheet = "Pro"
) |> 
  tidyr::drop_na(idnhl) |> 
  select(
    player_id = idnhl, mshl_team = actuel
  )

new_teams <- setNames(
  df_players_drafted$mshl_team,
  as.character(df_players_drafted$player_id)
)

# Load points predictions and cap hit ------------------------------------

df_points <- readRDS("data/marts/projections/final_points_predictions.RDS") %>% 
  left_join(
    .,
    readRDS("data/warehouse/players_caphits.rds"),
    by = "player_id") %>%
  left_join(
    .,
    alignements,
    by = "player_id") |> 
  mutate(
    cap_hit = ifelse(player_id == "8478427", 9750000, cap_hit),
    player_id = as.character(player_id),
    mshl_team = ifelse(is.na(mshl_team), "free_agent", mshl_team),
    player_status = ifelse(is.na(player_status), "free_agent", player_status),
    prop_cap_hit = ifelse(is.na(prop_cap_hit), 1, prop_cap_hit),
    mshl_cap_hit = prop_cap_hit * cap_hit,
    position = ifelse(position %in% c("C", "L", "R"), "F", "D")
  )

df_points$mshl_team[df_points$player_id %in% df_players_drafted$player_id] <- new_teams[as.character(df_points$player_id[df_points$player_id %in% df_players_drafted$player_id])]

saveRDS(df_points, "refiners/prepare_patriotes/data/main_data.rds")

# Get points thresholds by lineup spot -----------------------------------

df_points_lineup_spot <- df_points |> 
  filter(
    mshl_team != "free_agent" &
    !(player_status %in% c("SalaireRetenu", "Espoir"))
  ) |> 
  group_by(position, mshl_team) |> 
  mutate(
    spot = rank(-points)
  ) |> 
  select(
    player_id, first_name, last_name, points, age, team, mshl_team, position, mshl_cap_hit, spot
  ) |> 
  group_by(
    position, spot
  ) |> 
  summarise(
    mean = mean(points),
    sd = sd(points)
  ) |> 
  tidyr::replace_na(list(sd = 1))

# Save the dataframe
saveRDS(df_points_lineup_spot, "refiners/prepare_patriotes/data/points_lineup_spot.rds")
