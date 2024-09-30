# Packages ---------------------------------------------------------------
library(dplyr)
library(ggplot2)

# Load data --------------------------------------------------------------
data_f <- readRDS("data/marts/data_scaled_forwards.rds") |> 
  filter(season >= 2020)

data_d <- readRDS("data/marts/data_scaled_defensemen.rds") |> 
  filter(season >= 2020)

df_player_infos <- readRDS("data/warehouse/player_infos.rds")

scale_info_f <- readRDS("data/marts/lstm_scale_info_f.rds")
scale_info_d <- readRDS("data/marts/lstm_scale_info_d.rds")

# Fetch projected lineup from NHL api ------------------------------------
target <- "pp_icetime"
model_f <- keras::load_model_hdf5(paste0("apis/lstm/models/f_", target, ".keras"))
model_d <- keras::load_model_hdf5(paste0("apis/lstm/models/d_", target, ".keras"))
iters <- 2000

for (i in ptspredictR::nhl_api_2024_teams){
  message("\n", i)
  # Generate naive projections for forwards
  df_forwards_naive_projections <- ptspredictR::predict_model_on_team(
    model = model_f,
    target = target,
    team = i,
    historic_data = data_f,
    df_player_infos = df_player_infos,
    position = "forwards",
    variables = ptspredictR::lstm_features,
    fixed_variables = ptspredictR::lstm_fixed_features,
    window = 4
  ) |>
  dplyr::mutate(
    pred = ptspredictR::unscale(pred_scaled, mean = scale_info_f[[target]][["mean"]], sd = scale_info_f[[target]][["sd"]]),
    implied_odds = (log(career_games_played + 1) * 0.25) + (pred_scaled * 0.75),
    implied_odds = implied_odds + abs(min(implied_odds)) + 0.01,
    implied_odds = implied_odds ^ 4.5
  ) |> 
  dplyr::arrange(-implied_odds)

  # Generate naive projections for defensemen
  df_defensemen_naive_projections <- ptspredictR::predict_model_on_team(
    model = model_d,
    target = target,
    team = i,
    historic_data = data_d,
    df_player_infos = df_player_infos,
    position = "defensemen",
    variables = ptspredictR::lstm_features,
    fixed_variables = ptspredictR::lstm_fixed_features,
    window = 4
  ) %>%
    dplyr::mutate(
      pred = ptspredictR::unscale(pred_scaled, mean = scale_info_d[[target]][["mean"]], sd = scale_info_d[[target]][["sd"]]),
      implied_odds = (log(career_games_played + 1) * 0.25) + (pred_scaled * 0.75),
      implied_odds = implied_odds + abs(min(implied_odds)) + 0.01,
      implied_odds = implied_odds ^ 4
    ) |> 
    dplyr::arrange(-implied_odds)

  # Simulate multiple games
  for (j in 1:iters) {
    df_game <- ptspredictR::simulate_one_pp_game(
      df_forwards = df_forwards_naive_projections,
      df_defensemen = df_defensemen_naive_projections,
      target = "pred"
    ) |> 
      dplyr::mutate(iteration = j)
    if (j == 1) {
      df_lines <- df_game
    } else {
      df_lines <- rbind(df_lines, df_game)
    }
    cat("\rSimulate game: ", j, "/", iters)  # Overwrite the current line with the current iteration number
    flush.console()
  }
  # Calculate total icetime by player
  df_total_by_playeri <- df_lines |> 
   dplyr::group_by(player_id) |> 
   dplyr::summarise(
     total_icetime = sum(icetime)
   ) |> 
   dplyr::mutate(
     pp_icetime = total_icetime * 82 / iters,
     team = i
   )
  if (i == ptspredictR::nhl_api_2024_teams[1]){
    df_total_by_player <- df_total_by_playeri
  } else {
    df_total_by_player <- rbind(df_total_by_player, df_total_by_playeri)
  }
}

saveRDS(df_total_by_player, "data/marts/projections/pp_icetime_by_player.rds")


