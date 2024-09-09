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
  "game_score" = "gameScore",
  "onice_xg_pct" = "onIce_xGoalsPercentage",
  "xg_flurryscorevenue_adjusted" = "I_F_flurryScoreVenueAdjustedxGoals",
  "xrebounds" = "I_F_xRebounds",
  "xplay_continued" = "I_F_xPlayContinuedInZone",
  "shots" = "I_F_shotsOnGoal",
  "xon_goal" = "I_F_xOnGoal",
  "xg_rebound" = "I_F_reboundxGoals",
  "xg_lowdanger" = "I_F_lowDangerxGoals",
  "xg_mediumdanger" = "I_F_mediumDangerxGoals",
  "xg_highdanger" = "I_F_highDangerxGoals",
  "xrebounds_quality" = "I_F_xGoalsFromxReboundsOfShots",
  "earned_rebounds" = "I_F_xGoals_with_earned_rebounds_scoreFlurryAdjusted",
  "goals_lowdanger" = "I_F_lowDangerGoals",
  "goals_mediumdanger" = "I_F_mediumDangerGoals",
  "goals_highdanger" = "I_F_highDangerGoals",
  "goals_rebound" = "I_F_reboundGoals",
  "takeaways" = "I_F_takeaways",
  "giveaways" = "I_F_giveaways"
)

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
