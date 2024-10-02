## This script will take the data for forwards and defensemen and train a random forest

# Packages ---------------------------------------------------------------

# Data -------------------------------------------------------------------
data_f <- readRDS("data/marts/data_random_forest_forwards.rds") |> 
  dplyr::select(-goals, -assists, -player_id, -games_played)
data_d <- readRDS("data/marts/data_random_forest_defensemen.rds") |> 
  dplyr::select(-goals, -assists, -player_id, -games_played)

# Forwards ---------------------------------------------------------------

model_f <- ptspredictR::train_random_forest(
  data_f,
  "points"
)

randomForest::varImpPlot(model_f)

saveRDS(model_f, "apis/points_predictor_api/models/points_f.rds")

# Defensemen ---------------------------------------------------------------

model_d <- ptspredictR::train_random_forest(
  data_d,
  "points"
)

randomForest::varImpPlot(model_d)

saveRDS(model_d, "apis/points_predictor_api/models/points_d.rds")