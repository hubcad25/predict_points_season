# Packages ---------------------------------------------------------------
library(dplyr)

# Load data --------------------------------------------------------------
data <- rbind(
  readRDS("data/marts/data_random_forest_forwards.rds"),
  readRDS("data/marts/data_random_forest_defensemen.rds")
)

variables <- c(ptspredictR::ev_variables, names(ptspredictR::pp_variables))

df_past <- ptspredictR::build_past_stats_df(
  data = data,
  variables = variables,
  window = 5
)

