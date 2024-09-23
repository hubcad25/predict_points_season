## This script takes the data that is used to train the random forest models to prepares them for the lstm models that are going to be used to project IVs for the next season and thus use the random forest models to predict the points of a player. It saves data for all players into a json file

# Packages ---------------------------------------------------------------
library(dplyr)

# Load data --------------------------------------------------------------
data_f <- readRDS("data/marts/data_random_forest_forwards.rds") |> 
  mutate(
    ev_icetime = ev_icetime / games_played,
    pp_icetime = pp_icetime / games_played,
    game_score = game_score / games_played,
  )

data_d <- readRDS("data/marts/data_random_forest_defensemen.rds") |> 
  mutate(
    ev_icetime = ev_icetime / games_played,
    pp_icetime = pp_icetime / games_played,
    game_score = game_score / games_played,
  )

### Player infos for fixed variables: age, height, draft_rank, country
df_player_infos <- readRDS("data/warehouse/player_infos.rds") |> 
  select(player_id, yob, height, draft_rank)

# Set variables to include in past stats ----------------------------------------------------------
variables <- c(
  "ev_icetime", "pp_icetime",
  ptspredictR::ev_variables,
  names(ptspredictR::pp_variables)
)

# Scale variables (and save scaling info) --------------------------------------------------------

scale_f <- scale(data_f[, variables])
data_f_scaled <- cbind(
  data_f |> select(-all_of(variables)),
  as.data.frame(scale_f[, variables])
)
scale_info_f <- lapply(variables, function(x) {
  setNames(c(attr(scale_f, "scaled:center")[x], attr(scale_f, "scaled:scale")[x]), c("mean", "sd"))
})
names(scale_info_f) <- variables

saveRDS(scale_info_f, "data/marts/lstm_scale_info_f.rds")

scale_d <- scale(data_d[, variables])
data_d_scaled <- cbind(
  data_d |> select(-all_of(variables)),
  as.data.frame(scale_d[, variables])
)
scale_info_d <- lapply(variables, function(x) {
  setNames(c(attr(scale_d, "scaled:center")[x], attr(scale_d, "scaled:scale")[x]), c("mean", "sd"))
})
names(scale_info_d) <- variables

saveRDS(scale_info_d, "data/marts/lstm_scale_info_d.rds")

# Build past stats dataframe ---------------------------------------------
df_past_stats_f <- ptspredictR::build_past_stats_df(
  data = data_f_scaled,
  variables = variables,
  window = 4
) %>%
  # Add player infos
  left_join(., df_player_infos, by = "player_id") |> 
  filter(season >= 2012) |> 
  mutate(age = season - yob) |> 
  select(-yob)

saveRDS(df_past_stats_f, "data/marts/data_lstm_forwards.rds")

df_past_stats_d <- ptspredictR::build_past_stats_df(
  data = data_d_scaled,
  variables = variables,
  window = 4
) %>%
  # Add player infos
  left_join(., df_player_infos, by = "player_id") |> 
  filter(season >= 2012) |> 
  mutate(age = season - yob) |> 
  select(-yob)

saveRDS(df_past_stats_d, "data/marts/data_lstm_defensemen.rds")