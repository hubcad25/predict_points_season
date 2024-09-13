library(plumber)

pr("apis/points_predictor_api/code.R") %>%
  pr_run(port=8000)