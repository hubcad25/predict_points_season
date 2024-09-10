## This script will take each json file in data/lake/nhlapi/player_infos and structure it into a table containing relevant player infos to the model
## year of birth, height, draft, position, country

# Packages ---------------------------------------------------------------
library(dplyr)

# Files to load ----------------------------------------------------------
files <- list.files(
  "data/lake/nhlapi/player_infos",
  full.names = TRUE
)

# Load json files into a table ---------------------------------

for (i in seq_along(files)){
  row <- ptspredictR::l_player_infos(readRDS(files[i]))
  if (i == 1){
    output <- row
  } else {
    output <- rbind(output, row)
  }
  if (i %% 50 == 0){
    message(i)
  }
}

saveRDS(output, "data/warehouse/player_infos.rds")
