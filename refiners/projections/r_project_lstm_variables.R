# Packages ---------------------------------------------------------------
library(dplyr)

# Load data --------------------------------------------------------------

## players to project are all players that have predicted ev icetime for the season
players_to_project <- readRDS("data/marts/projections/ev_icetime_by_player.rds")$player_id

df_player_infos <- readRDS("data/warehouse/player_infos.rds") |> 
  filter(
    player_id %in% players_to_project
  )

forwards_to_project <- df_player_infos$player_id[df_player_infos$position %in% c("C", "R", "L")]
defensemen_to_project <- df_player_infos$player_id[df_player_infos$position == "D"]

data_f <- readRDS("data/marts/data_scaled_forwards.rds") |> 
  filter(
    season >= 2020 &
    player_id %in% forwards_to_project
  )

data_d <- readRDS("data/marts/data_scaled_defensemen.rds") |> 
  filter(
    season >= 2020 &
    player_id %in% defensemen_to_project
  )

scale_info_f <- readRDS("data/marts/lstm_scale_info_f.rds")
scale_info_d <- readRDS("data/marts/lstm_scale_info_d.rds")

# Predict all models in a loop -------------------------------------------

variables_to_project <- c(
  ptspredictR::ev_variables,
  names(ptspredictR::pp_variables)
)

for (i in variables_to_project){
  message("\n", i)
  model_f <- keras::load_model_hdf5(paste0("apis/lstm/models/f_", i, ".keras"))
  model_d <- keras::load_model_hdf5(paste0("apis/lstm/models/d_", i, ".keras"))
  df_forwards_projection <- ptspredictR::predict_model_on_players(
    model_f,
    target = i,
    players = forwards_to_project,
    position = "forwards",
    historic_data = data_f,
    df_player_infos = df_player_infos,
    variables = ptspredictR::lstm_features,
    fixed_variables = ptspredictR::lstm_fixed_features
  )
  pred_unscaled_f <- ptspredictR::unscale(df_forwards_projection$pred_scaled, mean = scale_info_f[[i]][["mean"]], sd = scale_info_f[[i]][["sd"]])
  df_defensemen_projection <- ptspredictR::predict_model_on_players(
    model_d,
    target = i,
    players = defensemen_to_project,
    position = "defensemen",
    historic_data = data_d,
    df_player_infos = df_player_infos,
    variables = ptspredictR::lstm_features,
    fixed_variables = ptspredictR::lstm_fixed_features
  )
  pred_unscaled_d <- ptspredictR::unscale(df_defensemen_projection$pred_scaled, mean = scale_info_d[[i]][["mean"]], sd = scale_info_d[[i]][["sd"]])
  if (i == variables_to_project[1]){
    df_projections <- rbind(
      df_forwards_projection,
      df_defensemen_projection
    ) |>
      select(-pred_scaled)
    df_projections[[i]] <- c(pred_unscaled_f, pred_unscaled_d)
  } else {
    df_projections[[i]] <- c(pred_unscaled_f, pred_unscaled_d)
  }
}

saveRDS(df_projections, "data/marts/projections/independent_variables_projections.rds")
