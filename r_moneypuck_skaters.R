## This script loads all the IVs from the moneypuck/skaters files into one table containing all seasons.
## It does not make any transformations to the data

# Packages ---------------------------------------------------------------
library(dplyr)

# Data -------------------------------------------------------------------
data <- readRDS("data/lake/moneypuck/skaters_2023.rds")

points <- data |> 
  select(
    playerId, season
  ) |> 
  

at_even <- data |> 
  filter(situation == "5on5") |> 
  select(
    playerId,
    season,
    name,
    team,
    games_played,
    icetime,
    gameScore,
    onIce_xGoalsPercentage,
    I_F_flurryScoreVenueAdjustedxGoals,
    I_F_xRebounds,
    I_F_xPlayContinuedInZone,
    I_F_shotsOnGoal,
    I_F_xOnGoal,
    I_F_reboundxGoals,
    I_F_lowDangerxGoals,
    I_F_mediumDangerxGoals,
    I_F_highDangerxGoals,
    I_F_xGoalsFromxReboundsOfShots,
    I_F_xGoals_with_earned_rebounds_scoreFlurryAdjusted,
    I_F_lowDangerGoals,
    I_F_mediumDangerGoals,
    I_F_highDangerGoals,
    I_F_reboundGoals,
    I_F_takeaways,
    I_F_giveaways
    )

at_pp <- data |> 
  filter(situation == "5on4") |> 
  select(
    playerId,
    season,
    gameScore,
    icetime,
    onIce_xGoalsPercentage,
    I_F_flurryScoreVenueAdjustedxGoals,
    I_F_shotsOnGoal,
    I_F_xOnGoal,
    I_F_reboundxGoals,
    I_F_lowDangerxGoals,
    I_F_mediumDangerxGoals,
    I_F_highDangerxGoals,
    I_F_xGoals_with_earned_rebounds_scoreFlurryAdjusted,
    I_F_lowDangerGoals,
    I_F_mediumDangerGoals,
    I_F_highDangerGoals,
    I_F_reboundGoals
    )

names(at_pp) <- paste0(names(at_pp), "_pp")

output <- left_join(
  at_even, at_pp,
  by = c("playerId" = "playerId_pp", "season" = "season_pp")
)
