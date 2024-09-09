## This script loads all the IVs from the moneypuck/lines files into one table containing all seasons.
## It does not make any transformations to the data.

options(scipen = 999)

# Packages ---------------------------------------------------------------
library(dplyr)

# Data -------------------------------------------------------------------

lake_files <- list.files(
  path = "data/lake/moneypuck",
  pattern = "lines_*",
  full.names = TRUE
)

for (i in lake_files){
  outputi <- readRDS(i) |> 
    mutate(
      player_id_1 = substr(lineId, 1, 7),
      player_id_2 = substr(lineId, 8, 14),
      player_id_3 = substr(lineId, 15, 22)
    ) |> 
    select(
      line_id = lineId,
      season,
      name,
      team,
      position,
      starts_with("player_id"),
      icetime
    )
  if (i == lake_files[1]){
    output <- outputi
  } else {
    output <- rbind(output, outputi)
  }
  message(i)
}

## Save it
saveRDS(output, "data/warehouse/lines.rds")
