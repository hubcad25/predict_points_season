## This script will fetch player infos from the NHL API player/{player_id}/landing endpoint and stock json file(s) in the lake

# Packages ---------------------------------------------------------------
library(dplyr)

# Get all nhl player_ids to fetch --------------------------------------------
### Take all players currently on a NHL roster
player_ids <- as.character(unlist(sapply(ptspredictR::nhl_api_2024_teams, function(i) {
  roster <- unname(unlist(ptspredictR::get_team_roster(i)))
  message(i)
  return(roster)
})))

# Only keep those that are not already in data/lake/nhlapi/player_infos/ ----
players_already_extracted <- gsub("\\.rds$", "", list.files("data/lake/nhlapi/player_infos"))

## Only extract these players
players_to_extract <- player_ids[!(player_ids %in% players_already_extracted)]

# Extract json files -----------------------------------------------------

for (i in seq_along(players_to_extract)){
  url <- paste0("https://api-web.nhle.com/v1/player/", players_to_extract[i], "/landing")
  json_data <- jsonlite::fromJSON(url)
  saveRDS(json_data, paste0("data/lake/nhlapi/player_infos/", players_to_extract[i], ".rds"))
  if (i %% 50 == 0){
    message(i)
  }
}


