## This script takes the lines dataset in the warehouse and transforms it into a dataframe containing each pair of players that played on a line together and sums up their icetime together. Then, it divides this value by the total icetime of each player, thus resulting in the teammates time distribution of each player.

# Packages ---------------------------------------------------------------
library(dplyr)

# Wrangling --------------------------------------------------------------
data <- readRDS("data/warehouse/lines.rds") |> 
  mutate(
    icetime = icetime / 60,
    linemate_id_1 = player_id_1,
    linemate_id_2 = player_id_2,
    linemate_id_3 = player_id_3
  ) |> 
  tidyr::pivot_longer(
    cols = starts_with("player_id"),
    names_to = "px",
    names_prefix = "player_id_",
    values_to = "player_id"
  )

icetime_by_player <- data |> 
  group_by(player_id, season) |> 
  summarise(total_icetime = sum(icetime))

output <- data |> 
  tidyr::pivot_longer(
    cols = starts_with("linemate_id"),
    names_to = "lx",
    names_prefix = "linemate_id_",
    values_to = "linemate_id"
  ) |> 
  filter(
    player_id != linemate_id &
    player_id != "" &
    linemate_id != ""
  ) |> 
  group_by(
    season, player_id, linemate_id
  ) |> 
  summarise(
    icetime = sum(icetime)
  ) %>%
  left_join(
    ., icetime_by_player,
    by = c("player_id", "season")
  ) |> 
  mutate(prop_icetime = icetime / total_icetime)

saveRDS(output, "data/marts/mart_teammates_time_distribution.rds")
