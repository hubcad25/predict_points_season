## This script takes the warehouse/player_capwages_ids and creates a csv
## used to manually input the missing capwages ids.
## This csv is then loaded to replace the ids of the missing players and saves
## the result in warehouse/player_capwages_ids_final.rds

get_name <- function(player_id){
  list <- httr::content(httr::GET(paste0("https://api-web.nhle.com/v1/player/", player_id ,"/landing")))
  return(paste0(list$firstName, " ", list$lastName))
}

# Load data --------------------------------------------------------------
data <- readRDS("data/warehouse/player_capwages_ids.rds")

df_missing_players <- data |> 
  dplyr::filter(is.na(capwages_id))

# Write missing players to csv -------------------------------------------
#write.csv(df_missing_players, "data/warehouse/missing_player_capwages_ids.csv")

#################################################
### MANUALLY INPUT MISSING PLAYERS IN THE CSV ###
#################################################

df_missing_players_filled <- read.csv("data/warehouse/missing_player_capwages_ids.csv")

output <- rbind(data, df_missing_players_filled) |> 
  tidyr::drop_na()

saveRDS(output, "data/warehouse/player_capwages_ids_final.rds")
