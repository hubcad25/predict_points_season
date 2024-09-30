## This script will take the data for forwards and defensemen and train a random forest

# Packages ---------------------------------------------------------------

# Data -------------------------------------------------------------------
data_f <- readRDS("data/marts/data_random_forest_forwards.rds") |> 
  dplyr::select(-points, -player_id, -games_played)
data_d <- readRDS("data/marts/data_random_forest_defensemen.rds") |> 
  dplyr::select(-points, -player_id, -games_played)

# Forwards ---------------------------------------------------------------

model_goals <- ptspredictR::train_random_forest(
  data_f |> dplyr::select(-assists),
  "goals"
)

randomForest::varImpPlot(model_goals)

saveRDS(model_goals, "apis/points_predictor_api/models/goals_f.rds")

model_assists <- ptspredictR::train_random_forest(
  data_f |> dplyr::select(-goals),
  "assists"
)

randomForest::varImpPlot(model_assists)
hist(predict(model_assists))

saveRDS(model_assists, "apis/points_predictor_api/models/assists_f.rds")

# Defensemen ---------------------------------------------------------------

model_goals_d <- ptspredictR::train_random_forest(
  data_d |> dplyr::select(-assists),
  "goals"
)

randomForest::varImpPlot(model_goals_d)

saveRDS(model_goals_d, "apis/points_predictor_api/models/goals_d.rds")

model_assists_d <- ptspredictR::train_random_forest(
  data_d |> dplyr::select(-goals),
  "assists"
)

randomForest::varImpPlot(model_assists_d)

saveRDS(model_assists_d, "apis/points_predictor_api/models/assists_d.rds")


