# Packages ---------------------------------------------------------------
library(dplyr)

# Load data --------------------------------------------------------------
data_f <- readRDS("data/marts/data_scaled_forwards.rds") |> 
  filter(season >= 2020)

df_player_infos <- readRDS("data/warehouse/player_infos.rds")

f_ev_icetime <- keras::load_model_hdf5("apis/lstm/models/f_ev_icetime.keras")

# Fetch projected lineup from NHL api ------------------------------------
lineup <- ptspredictR::get_team_roster("MTL")

ptspredictR::build_past_stats_df_for_projection()

get_name <- function(player_id){
  list <- httr::content(httr::GET(paste0("https://api-web.nhle.com/v1/player/", player_id ,"/landing")))
  message(list$firstName, list$lastName)
}

i <- 25
get_name(lineup$forwards[i])
ptspredictR::get_past_data(
  lineup$forwards[i],
  season = 2024,
  data = data_f,
  variables = c("game_score", "ev_icetime", "onice_xg_pct", "finishing_mediumdanger"),
  window = 4 
)

