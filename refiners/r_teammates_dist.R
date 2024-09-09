library(dplyr)

data <- readRDS("data/warehouse/lines.rds") |> 
  tidyr::pivot_longer(
    cols = starts_with("playerId"),
    names_to = "playerId",
    values_to = 
  )
