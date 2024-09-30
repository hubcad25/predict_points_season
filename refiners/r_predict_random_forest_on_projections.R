# Packages ---------------------------------------------------------------
library(dplyr)

# Load data and models ---------------------------------------------------
df_projections <- readRDS("data/marts/projections/final_projections.rds")

real_data_f <- readRDS("data/marts/data_random_forest_forwards.rds") |> 
  filter(season >= 2022)
real_data_d <- readRDS("data/marts/data_random_forest_defensemen.rds") |> 
  filter(season >= 2022)

## Separate by position ---------------------------------------------------
df_projections_f <- df_projections |> 
  filter(position %in% c("C", "L", "R"))

df_projections_d <- df_projections |> 
  filter(position == "D")

model_f <- readRDS("apis/points_predictor_api/models/points_f.rds")
model_d <- readRDS("apis/points_predictor_api/models/points_d.rds")

# Create function to scale predicted values on a credible distribution ---------------------------------------

rescale_points_to_real_distribution <- function(predicted_points, real_points_centiles, projected_points_centiles) {
  return(approx(x = projected_points_centiles, y = real_points_centiles, xout = predicted_points)$y)
}

# Predict models and scale -----------------------------------------------

centiles_to_check <- c(0, 0.05, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 0.95, 0.975, 0.99, 0.995, 0.9995, 1)

## Forwards ---------------------------------------------------------------
unscaled_projections <- predict(model_f, newdata = df_projections_f)
projected_points_centiles <- quantile(unscaled_projections, centiles_to_check)
real_points_centiles <- quantile(real_data_f$points, centiles_to_check)

df_projections_f$points <- rescale_points_to_real_distribution(
  predicted_points = unscaled_projections,
  real_points_centiles = real_points_centiles,
  projected_points_centiles = projected_points_centiles
)

## Defensemen -------------------------------------------------------------
unscaled_projections <- predict(model_d, newdata = df_projections_d)
projected_points_centiles <- quantile(unscaled_projections, centiles_to_check)
real_points_centiles <- quantile(real_data_d$points, centiles_to_check)

df_projections_d$points <- rescale_points_to_real_distribution(
  predicted_points = unscaled_projections,
  real_points_centiles = real_points_centiles,
  projected_points_centiles = projected_points_centiles
)

# Bind it all together ---------------------------------------------------

df_predictions <- rbind(
  df_projections_f,
  df_projections_d
) |> 
  relocate(player_id, first_name, last_name, points, age)


saveRDS(df_predictions, "data/marts/projections/final_points_predictions.RDS")
