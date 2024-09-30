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

model_goals_f <- readRDS("apis/points_predictor_api/models/goals_f.rds")
model_assists_f <- readRDS("apis/points_predictor_api/models/assists_f.rds")
model_goals_d <- readRDS("apis/points_predictor_api/models/goals_d.rds")
model_assists_d <- readRDS("apis/points_predictor_api/models/assists_d.rds")

# Create function to scale predicted values on a credible distribution ---------------------------------------

## The models underestimate by a lot. We will manually adjust them
scale_value <- function(value, old_max = 35, new_max = 65, exponent = 2) {
  # Applique une transformation non linéaire en utilisant un exposant pour donner plus de poids aux grandes valeurs
  scaled_value <- (value / old_max)^exponent * new_max
  return(scaled_value)
}

## We need to find the optimal exponent to use in the scale_value function.
find_optimal_exponent <- function(
  exponents_to_test = seq(1, 20, by = 0.1),
  unscaled_values,
  real_distribution,
  old_max,
  new_max
) {
  centiles_to_check <- c(0, 0.05, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 0.95, 0.975, 0.99, 0.995, 0.9995, 1)
  real_centiles <- quantile(real_distribution, centiles_to_check)
  # Définir des poids plus élevés pour les centiles du milieu
  weights <- c(0.5, 0.8, 1, 2, 2.5, 3, 2.5, 2, 1.5, 0.8, 0.6, 0.4, 0.3, 0.2, 0.1)
  best_exponent <- NULL
  min_diff <- Inf
  for (exponent in exponents_to_test) {
    # Scaling les valeurs avec l'exposant actuel
    scaled_values <- (unscaled_values / old_max)^exponent * new_max
    # Calcul des centiles prévus
    predicted_centiles <- quantile(scaled_values, centiles_to_check)
    # Différence absolue totale entre les centiles réels et prévus
    diff <- sum(weights * abs(predicted_centiles - real_centiles)) 
    # Vérifie si cet exposant donne une meilleure approximation
    if (diff < min_diff) {
      min_diff <- diff
      best_exponent <- exponent
    }
  } 
  return(best_exponent)
}

# Predict models and scale -----------------------------------------------


predict_adjusted_points <- function(
  model_goals, 
  model_assists, 
  df_projections, 
  real_data_goals, 
  real_data_assists, 
  real_data_points, 
  goals_max = 65, 
  assists_max = 95
) {
  
  # 1. Prédictions des goals
  df_projections$goals <- predict(model_goals, newdata = df_projections)
  
  # Scale des goals
  df_projections$goals <- scale_value(
    df_projections$goals,
    old_max = max(df_projections$goals),
    new_max = goals_max,
    exponent = find_optimal_exponent(
      unscaled_values = df_projections$goals,
      real_distribution = real_data_goals,
      old_max = max(df_projections$goals),
      new_max = goals_max
    )
  )
  
  # 2. Prédictions des assists
  df_projections$assists <- predict(model_assists, newdata = df_projections)
  
  # Scale des assists
  df_projections$assists <- scale_value(
    df_projections$assists,
    old_max = max(df_projections$assists),
    new_max = assists_max,
    exponent = find_optimal_exponent(
      unscaled_values = df_projections$assists,
      real_distribution = real_data_assists,
      old_max = max(df_projections$assists),
      new_max = assists_max
    )
  )
  
  # 3. Calcul des points basés sur goals + assists
  df_projections$points <- df_projections$goals + df_projections$assists
  
  # 4. Rescaling des points pour correspondre aux centiles des vraies données de points
  centiles_to_check <- c(0, 0.05, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 0.95, 0.975, 0.99, 0.995, 0.9995, 1)
  
  projected_points_centiles <- quantile(df_projections$points, centiles_to_check)
  real_points_centiles <- quantile(real_data_points, centiles_to_check)
  
  # Fonction de rescaling des points
  rescale_points_to_real_distribution <- function(predicted_points, real_points_centiles, projected_points_centiles) {
    return(approx(x = projected_points_centiles, y = real_points_centiles, xout = predicted_points)$y)
  }
  
  # Appliquer le rescaling aux points
  df_projections$points_rescaled <- rescale_points_to_real_distribution(
    df_projections$points, 
    real_points_centiles, 
    projected_points_centiles
  )
  
  # 5. Réajuster les goals et assists pour correspondre aux points rescalés
  df_projections$goals_weight <- df_projections$goals / df_projections$points
  df_projections$assists_weight <- df_projections$assists / df_projections$points
  
  df_projections$goals_adjusted <- df_projections$goals_weight * df_projections$points_rescaled
  df_projections$assists_adjusted <- df_projections$assists_weight * df_projections$points_rescaled
  
  # 6. Remplacer les colonnes originales par les valeurs ajustées
  df_projections$goals <- df_projections$goals_adjusted
  df_projections$assists <- df_projections$assists_adjusted
  df_projections$points <- df_projections$goals + df_projections$assists
  
  df_projections <- df_projections |> 
    select(-goals_weight, -assists_weight, -goals_adjusted, -assists_adjusted, -points_rescaled)
  # Retourner le dataframe mis à jour
  return(df_projections)
}

# Exemple d'utilisation
df_projections_f_adjusted <- predict_adjusted_points(
  model_goals = model_goals_f, 
  model_assists = model_assists_f, 
  df_projections = df_projections_f, 
  real_data_goals = real_data_f$goals, 
  real_data_assists = real_data_f$assists, 
  real_data_points = real_data_f$points
)





# END OF FUNCTION TEST ---------------------------------------------------

## Forwards
df_projections_f$goals <- predict(model_goals_f, newdata = df_projections_f)
df_projections_f$goals <-  scale_value(
  df_projections_f$goals,
  old_max = max(df_projections_f$goals),
  new_max = 65,
  exponent = find_optimal_exponent(
    unscaled_values = df_projections_f$goals,
    real_distribution = real_data_f$goals,
    old_max = max(df_projections_f$goals),
    new_max = 65
  )  
)

hist(df_projections_f$goals)
hist(real_data_f$goals)

df_projections_f$assists <- predict(model_assists_f, newdata = df_projections_f)
df_projections_f$assists <-  scale_value(
  df_projections_f$assists,
  old_max = max(df_projections_f$assists),
  new_max = 95,
  exponent = find_optimal_exponent(
    unscaled_values = df_projections_f$assists,
    real_distribution = real_data_f$assists,
    old_max = max(df_projections_f$assists),
    new_max = 95
  )
)

hist(df_projections_f$assists)
hist(real_data_f$assists)

df_projections_f$points <- df_projections_f$goals + df_projections_f$assists

hist(df_projections_f$points)

centiles_to_check <- c(0, 0.05, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 0.95, 0.975, 0.99, 0.995, 0.9995, 1)
projected_points_centiles <- quantile(df_projections_f$points, centiles_to_check)
real_points_centiles <- quantile(real_data_f$points, centiles_to_check)

# Fonction pour rescaler les points prédits en fonction des centiles réels
rescale_points_to_real_distribution <- function(predicted_points, real_points_centiles, projected_points_centiles) {
  return(approx(x = projected_points_centiles, y = real_points_centiles, xout = predicted_points)$y)
}

# Appliquer la fonction de rescaling aux points projetés
df_projections_f$points_rescaled <- rescale_points_to_real_distribution(df_projections_f$points, real_points_centiles, projected_points_centiles)

# Calcul des proportions de "goals" et "assists" dans les points originaux
df_projections_f$goals_weight <- df_projections_f$goals / df_projections_f$points
df_projections_f$assists_weight <- df_projections_f$assists / df_projections_f$points

# Réajustement des goals et assists basés sur les poids et le nouveau total de points
df_projections_f$goals_adjusted <- df_projections_f$goals_weight * df_projections_f$points_rescaled
df_projections_f$assists_adjusted <- df_projections_f$assists_weight * df_projections_f$points_rescaled

# Vérification de la somme des points réajustés
df_projections_f$points_adjusted <- df_projections_f$goals_adjusted + df_projections_f$assists_adjusted


## Defensemen
df_projections_d$goals <- predict(model_goals_d, newdata = df_projections_d)
df_projections_d$goals <- scale_value(
  df_projections_d$goals,
  old_max = max(df_projections_d$goals),
  new_max = 25,
  exponent = find_optimal_exponent(
    unscaled_values = df_projections_d$goals,
    real_distribution = real_data_d$goals,
    old_max = max(df_projections_d$goals),
    new_max = 25
  )  
)

# Histogrammes pour les buts (défenseurs)
hist(df_projections_d$goals)
hist(real_data_d$goals)

# Prédiction et scaling des passes décisives pour les défenseurs
df_projections_d$assists <- predict(model_assists_d, newdata = df_projections_d)
df_projections_d$assists <- scale_value(
  df_projections_d$assists,
  old_max = max(df_projections_d$assists),
  new_max = 75,
  exponent = find_optimal_exponent(
    unscaled_values = df_projections_d$assists,
    real_distribution = real_data_d$assists,
    old_max = max(df_projections_d$assists),
    new_max = 75
  )
)

# Histogrammes pour les passes décisives (défenseurs)
hist(df_projections_d$assists)
hist(real_data_d$assists)

# Calcul des points (buts + passes décisives) pour les défenseurs
df_projections_d$points <- df_projections_d$goals + df_projections_d$assists

# Histogramme des points (défenseurs)
hist(df_projections_d$points)


# Bind it all together ---------------------------------------------------


