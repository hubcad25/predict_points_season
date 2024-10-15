# Packages ---------------------------------------------------------------
library(dplyr)
library(ggplot2)
options(scipen = 999)

# Data -------------------------------------------------------------------
df_lineups <- readRDS("data/marts/projections/patriotes/lineups.rds")
df_results <- readRDS("data/marts/projections/patriotes/points_by_lineup.rds")
dead_cap <- readRDS("data/marts/projections/patriotes/dead_cap.rds")
df_cap_space <- df_lineups |> 
  filter(taken == 1) |> 
  group_by(iter) |> 
  summarise(total = sum(cap_hit)) |> 
  mutate(cap_space = 88000000 - dead_cap - total)

df_results |> 
  group_by(injury_gravity) |> 
  summarise(mean = mean(total_points)) |>
  ggplot(aes(x = injury_gravity, y = mean)) +
  geom_point()

df_results |> 
  ggplot(aes(x = injury_gravity, y = total_points)) +
  geom_jitter(alpha = 0.1) +
  geom_smooth()

df_results |>
  group_by(iter) |> 
  summarise(mean_points = mean(total_points)) %>% 
  left_join(., df_cap_space, by = "iter") |> 
  ggplot(aes(x = cap_space, y = mean_points)) +
  geom_point()

# Find best lineup -------------------------------------------------------

## Best scenario: injury_gravity = mean of 0 - 0.2
## Plausible scenario: injury_gravity = mean of 0.4 - 0.6
## Worst scenario: injury_gravity = mean of 0.8 - 1

df_results_by_scenario <- df_results |> 
  mutate(
    scenario = case_when(
      injury_gravity >= 0 & injury_gravity <= 0.2 ~ "best",
      injury_gravity >= 0.4 & injury_gravity <= 0.6 ~ "plausible",
      injury_gravity >= 0.8 & injury_gravity <= 1 ~ "worst"
    )
  ) |> 
  tidyr::drop_na(scenario) |> 
  group_by(iter, scenario) |> 
  summarise(
    points = mean(total_points)
  ) |> 
  group_by(iter) |> 
  mutate(mean = mean(points))

ggplot(df_results_by_scenario, aes(x = scenario, y = points)) + 
  geom_line(aes(group = iter, color = mean, alpha = mean)) +
  scale_alpha_continuous(range = c(0.001, 0.3)) +
  scale_color_viridis_c() +
  clessnize::theme_clean_light()


df_filter_top_iters <- df_results_by_scenario |> 
  tidyr::pivot_wider(
    names_from = "scenario",
    values_from = "points"
  ) |>
  ungroup() |> 
  mutate(rank = rank(-plausible)) |> 
  filter(rank <= 20)
