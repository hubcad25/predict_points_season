## This script takes the data that is used to train the random forest models, prepares them for a LSTM model and trains these LSTM models for each predictor of the random forest models.

# Packages ---------------------------------------------------------------
library(dplyr)

# Data -------------------------------------------------------------------
data_f_scaled <- readRDS("data/marts/data_scaled_forwards.rds")
data_d_scaled <- readRDS("data/marts/data_scaled_defensemen.rds")

df_past_stats_f <- readRDS("data/marts/data_lstm_forwards.rds")
df_past_stats_d <- readRDS("data/marts/data_lstm_defensemen.rds")

variables <- c(
  "ev_icetime", "pp_icetime",
  ptspredictR::ev_variables,
  names(ptspredictR::pp_variables)
)

# Train model for each IV ------------------------------------------------

for (i in variables){
  ix <- which(variables == i)
  df_target_only_f <- data_f_scaled |>
    select(player_id, season, all_of(i))
  df_target_only_d <- data_d_scaled |>
    select(player_id, season, all_of(i))
  df_with_target_f <- left_join(
    df_past_stats_f,
    df_target_only_f,
    by = c("player_id", "season")
  ) |>
    select(-all_of(c("player_id", "season")))
  df_with_target_d <- left_join(
    df_past_stats_d,
    df_target_only_d,
    by = c("player_id", "season")
  ) |>
    select(-all_of(c("player_id", "season")))
  data_lstm_f <- ptspredictR::prepare_lstm_data(
    df_with_target_f,
    target = i,
    include = c("game_score", "ev_icetime", "onice_xg_pct", "finishing_mediumdanger"),
    window = 4
  )
  data_lstm_d <- ptspredictR::prepare_lstm_data(
    df_with_target_d,
    target = i,
    include = c("game_score", "ev_icetime", "onice_xg_pct", "finishing_mediumdanger"),
    window = 4
  )
  lstm_model_f <- ptspredictR::train_lstm(data_lstm_f$X, data_lstm_f$y, window = 4, num_threads = 4)
  lstm_model_d <- ptspredictR::train_lstm(data_lstm_d$X, data_lstm_d$y, window = 4, num_threads = 4)
  keras::save_model_hdf5(object = lstm_model_f, filepath = paste0("apis/lstm/models/f_", i,".keras"))
  keras::save_model_hdf5(object = lstm_model_d, filepath = paste0("apis/lstm/models/d_", i,".keras"))
  bar <- paste(rep("+", times = round((ix / length(variables)) * 20)), collapse = "")
  cat(sprintf("\r%s DONE [%s] %d%%                              ", i, bar, round((ix / length(variables)) * 100)))  # Utilisation de "\r" pour revenir au début de la ligne
  flush.console()  # Forcer l'affichage immédiat
}



model2 <- keras::load_model_hdf5("path")

new_X <- X

preds <- model2 %>% tensorflow::tf$keras$Model$predict(new_X)
real <- df_with_target_f$game_score

check <- data.frame(
  pred <- preds[,1],
  real
)

# Set TensorFlow threading configuration
tensorflow::tf$config$threading$set_inter_op_parallelism_threads(12)
tensorflow::tf$config$threading$set_intra_op_parallelism_threads(8)

ggplot(check, aes(x = real, y = pred)) +
  geom_jitter() +
  geom_smooth()
