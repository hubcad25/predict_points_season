# Packages ---------------------------------------------------------------
library(dplyr)
library(ggplot2)

# Data -------------------------------------------------------------------
data <- readRDS("data/marts/projections/final_points_predictions.RDS")

model_f <- readRDS("apis/points_predictor_api/models/points_f.rds")
model_d <- readRDS("apis/points_predictor_api/models/points_d.rds")

randomForest::varImpPlot(model_f)
top_f_variables <- names(sort(randomForest::importance(model_f)[,1], decreasing = TRUE)[1:20])
top_f_variables <- top_f_variables[top_f_variables != "season"]

randomForest::varImpPlot(model_d)
top_d_variables <- names(sort(randomForest::importance(model_d)[,1], decreasing = TRUE)[1:20])
top_d_variables <- top_d_variables[top_d_variables != "season"]

# Functions ---------------------------------------------------------------
rescale_points_to_real_distribution <- function(predicted_points, real_points_centiles, projected_points_centiles) {
  return(approx(x = projected_points_centiles, y = real_points_centiles, xout = predicted_points)$y)
}

centiles_to_check <- c(0, 0.05, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 0.95, 0.975, 0.99, 0.995, 0.9995, 1)

predict_rescaled_points <- function(position, updated_data) {
  if (position == "F") {
    unscaled_projections <- predict(model_f, newdata = data |> filter(position %in% c("R", "L", "C")))
    projected_points_centiles <- quantile(unscaled_projections, centiles_to_check)
    real_points_centiles <- quantile(data$points[data$position %in% c("R", "L", "C")], centiles_to_check)
  } else if (position == "D") {
    unscaled_projections <- predict(model_d, newdata = data |> filter(position == "D"))
    projected_points_centiles <- quantile(unscaled_projections, centiles_to_check)
    real_points_centiles <- quantile(data$points[data$position == "D"], centiles_to_check)
  }
  rescale_points_to_real_distribution(
    predict(
      if (position == "D") model_d else model_f,
      newdata = updated_data
    ),
    real_points_centiles,
    projected_points_centiles
  )
}

# Check player's important stats relative -----------------------------------------

check_player_relative_stats <- function(data, position, first_namei, last_namei){
  if (position == "F") {
    variables <- top_f_variables
    positions <- c("C", "L", "R")
  } else if (position == "D") {
    variables <- top_d_variables
    positions <- c("D")
  }
  player_stats <- data |> 
    filter(
      first_name == first_namei &
      last_name == last_namei
      ) |> 
    select(all_of(variables))
  for (i in variables){
    z <- (player_stats[[i]] - mean(data[data$position %in% positions,][[i]])) / sd(data[data$position %in% positions,][[i]])
    if (z > 0){
      message(i, ": ", round(player_stats[[i]], 2), " ", crayon::bgCyan(round(z, 2)))
    } else {
      message(i, ": ", round(player_stats[[i]], 2), " ", crayon::bgRed(round(z, 2)))
    }
  }
}

custom_hist <- function(position, variable){
  if (position == "F") {
    positions <- c("C", "L", "R")
  } else if (position == "D") {
    positions <- c("D")
  }
  vector <- data.frame(col = data[[variable]][data$position %in% positions]) 
  plot <- ggplot(vector, aes(x = col)) +
    geom_histogram()
  message("mean: ", round(mean(vector$col), 2))
  message("sd: ", round(sd(vector$col), 2))
  return(plot)
}

# Predict ----------------------------------------------------------------
first <- "Simon"
last <- "Nemec"
position <- "D"

check_player_relative_stats(data, position = position, first_namei = first, last_namei = last)

custom_hist(position, "onice_xg_pct")
custom_hist(position, "game_score")
custom_hist(position, "pp_icetime")
custom_hist(position, "ev_icetime")
custom_hist(position, "finishing_lowdanger")
custom_hist(position, "pp_xg_rebound")
custom_hist(position, "pp_finishing_highdanger")
custom_hist(position, "finishing_lowdanger")
custom_hist(position, "teammates_earned_rebounds")
custom_hist(position, "teammates_xrebounds_quality")
custom_hist(position, "xplay_continued")
custom_hist(position, "xg_mediumdanger")
custom_hist(position, "xg_flurryscorevenue_adjusted")
custom_hist(position, "pp_earned_rebounds")
custom_hist(position, "teammates_game_score")
custom_hist(position, "teammates_finishing_lowdanger")
custom_hist(position, "pp_place_shots_net")
custom_hist(position, "pp_xg_mediumdanger")
custom_hist(position, "teammates_xg_flurryscorevenue_adjusted")
custom_hist(position, "pp_xg_flurryscorevenue_adjusted")
custom_hist(position, "pp_xrebounds_quality")


round(predict_rescaled_points(
  position,
  data |> 
  filter(
    first_name == first,
    last_name == last
  ) |> 
  mutate(
    teammates_game_score = 0.75,
    pp_icetime = 2700,
    game_score = 0.75
    )
  ),
  2
)
