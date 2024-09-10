## This script will fetch player infos from the NHL API player/{player_id}/landing endpoint and stock json file(s) in the lake

# Packages ---------------------------------------------------------------
library(dplyr)

# Get nhl player_ids to fetch --------------------------------------------

df_skaters <- readRDS("data/warehouse/individual_skaters.rds")
player_ids <- unique(df_skaters$player_id)

# Extract json files -----------------------------------------------------
for (i in seq_along(player_ids)){
  url <- paste0("https://api-web.nhle.com/v1/player/", player_ids[i], "/landing")
  json_data <- jsonlite::fromJSON(url)
  saveRDS(json_data, paste0("data/lake/nhlapi/player_infos/", player_ids[i], ".rds"))
  if (i %% 50 == 0){
    message(i)
  }
}


