## This script loads all the IVs from the moneypuck/skaters files into one table containing all seasons.
## It does not make any transformations to the data.
## It does not filter on the situation variable

# Packages ---------------------------------------------------------------
library(dplyr)

# Loop in relevant files to bind into one warehouse dataset -------------------------------------------------------------------

lake_files <- list.files(
  path = "data/lake/moneypuck",
  pattern = "skaters_*",
  full.names = TRUE
)

## Variables to keep in warehouse table
variables <- ptspredictR::independant_variables

for (i in lake_files){
  data <- readRDS(i)
  outputi <- data |> 
    select(
      player_id = playerId,
      season,
      name,
      team,
      games_played,
      points = I_F_points,
      goals = I_F_goals,
      assists1 = I_F_primaryAssists,
      assists2 = I_F_secondaryAssists,
      icetime,
      situation,
      all_of(variables)
    )
  if (i == lake_files[1]){
    output <- outputi
  } else {
    output <- rbind(output, outputi)
  }
  message(i)
}

## Save it
saveRDS(output, "data/warehouse/individual_skaters.rds")
