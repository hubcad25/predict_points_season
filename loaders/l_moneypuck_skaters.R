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
variables <- c(
  "gameScore",
  "onIce_xGoalsPercentage",
  "I_F_flurryScoreVenueAdjustedxGoals",
  "I_F_xRebounds",
  "I_F_xPlayContinuedInZone",
  "I_F_shotsOnGoal",
  "I_F_xOnGoal",
  "I_F_reboundxGoals",
  "I_F_lowDangerxGoals",
  "I_F_mediumDangerxGoals",
  "I_F_highDangerxGoals",
  "I_F_xGoalsFromxReboundsOfShots",
  "I_F_xGoals_with_earned_rebounds_scoreFlurryAdjusted",
  "I_F_lowDangerGoals",
  "I_F_mediumDangerGoals",
  "I_F_highDangerGoals",
  "I_F_reboundGoals",
  "I_F_takeaways",
  "I_F_giveaways"
)

for (i in lake_files){
  data <- readRDS(i)
  outputi <- data |> 
    select(
      playerId,
      season,
      name,
      team,
      games_played,
      icetime,
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
