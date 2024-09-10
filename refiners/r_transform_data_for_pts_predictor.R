## This script takes **3** warehouse tables to transform it into a dataset that is ready to use to train the random forest model that predicts points
#### 1. individual_skaters
#### 2. lines
#### 3. players_infos
## It also adjusts raw values as to assume each player played 82 games

# Packages ---------------------------------------------------------------
library(dplyr)

# Data -------------------------------------------------------------------

df_individual_skaters <- readRDS("data/warehouse/individual_skaters.rds") |> 
  ## Here we fabricate our added variables composed of multiple variables
  mutate(
    assists = assists1 + assists2,
    place_shots_net = shots / xon_goal,
    finishing_lowdanger = goals_lowdanger / xg_lowdanger,
    finishing_mediumdanger = goals_mediumdanger / xg_mediumdanger,
    finishing_highdanger = goals_highdanger / xg_highdanger,
    finishing_rebound = goals_rebound / xg_rebound
  ) |> 
  # Replace NA, NaN with 0
  tidyr::replace_na(list(
    place_shots_net = 0,
    finishing_lowdanger = 0,
    finishing_mediumdanger = 0,
    finishing_highdanger = 0,
    finishing_rebound = 0
  )) |>
  # Remove aberrations by bringing back to XX centile
  mutate(
    place_shots_net = ptspredictR::cap_values_above_threshold(place_shots_net, 0.99),
    finishing_lowdanger = ptspredictR::cap_values_above_threshold(finishing_lowdanger, 0.95),
    finishing_mediumdanger = ptspredictR::cap_values_above_threshold(finishing_mediumdanger, 0.95),
    finishing_highdanger = ptspredictR::cap_values_above_threshold(finishing_highdanger, 0.98),
    finishing_rebound = ptspredictR::cap_values_above_threshold(finishing_rebound, 0.975),
  )

df_dependent_variables <- df_individual_skaters |> 
  filter(situation == "all") |> 
  select(
    player_id, season,
    games_played, points, goals, assists
  )

# 1. Players infos (from NHL API) ----------------------------------------




# 2. Individual stats ----------------------------------------------------------------
  
df_even <- df_individual_skaters |> 
  filter(situation == "5on5") |> 
  select(
    player_id,
    season,
    ev_icetime = icetime,
    all_of(names(ptspredictR::independant_variables))
    ) |> 
  mutate(

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

# 3. Teammates stats -----------------------------------------------------------


# 4. Team stats ----------------------------------------------------------

