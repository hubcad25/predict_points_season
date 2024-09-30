# Packages ---------------------------------------------------------------
library(dplyr)

get_name <- function(player_id){
  list <- httr::content(httr::GET(paste0("https://api-web.nhle.com/v1/player/", player_id ,"/landing")))
  return(paste0(list$firstName, " ", list$lastName))
}

# Load data --------------------------------------------------------------
data_f <- readRDS("data/marts/data_scaled_forwards.rds") |> 
  filter(season >= 2020)

data_d <- readRDS("data/marts/data_scaled_defensemen.rds") |> 
  filter(season >= 2020)

df_player_infos <- readRDS("data/warehouse/player_infos.rds")

scale_info_f <- readRDS("data/marts/lstm_scale_info_f.rds")
scale_info_d <- readRDS("data/marts/lstm_scale_info_d.rds")

# Fetch projected lineup from NHL api ------------------------------------
target <- "ev_icetime"
model_f <- keras::load_model_hdf5(paste0("apis/lstm/models/f_", target, ".keras"))
model_d <- keras::load_model_hdf5(paste0("apis/lstm/models/d_", target, ".keras"))
iters <- 5000

for (i in ptspredictR::nhl_api_2024_teams){
  message(i)
  lineup_list <- ptspredictR::lineup_projection(
    model_f = model_f,
    model_d = model_d,
    target = "ev_icetime",
    team = i,
    data_f = data_f,
    data_d = data_d,
    df_player_infos = df_player_infos,
    scale_info_f = scale_info_f,
    scale_info_d = scale_info_d,
    iters = iters
  )
  df_total_by_playeri <- lineup_list$df_total_by_player |> 
    mutate(team = i)
  df_teammates_time_sharei <- lineup_list$df_teammates_time_share |> 
    mutate(team = i)
  if (i == ptspredictR::nhl_api_2024_teams[1]){
    df_total_by_player <- df_total_by_playeri
    df_teammates_time_share <- df_teammates_time_sharei
  } else {
    df_total_by_player <- rbind(df_total_by_player, df_total_by_playeri)
    df_teammates_time_share <- rbind(df_teammates_time_share, df_teammates_time_sharei)
  }
}

saveRDS(df_total_by_player, "data/marts/projections/ev_icetime_by_player.rds")
saveRDS(df_teammates_time_share, "data/marts/projections/teammates_time_share.rds")
