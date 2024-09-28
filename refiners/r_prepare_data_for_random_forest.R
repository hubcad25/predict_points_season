## This script takes **3** warehouse tables to transform it into a dataset that is ready to use to train the random forest model that predicts points
#### 1. individual_skaters
#### 2. lines
#### 3. players_infos
## It also adjusts raw values as to assume each player played 82 games

# Packages ---------------------------------------------------------------
library(dplyr)

# Data -------------------------------------------------------------------

df_individual_skaters <- readRDS("data/warehouse/individual_skaters.rds") |> 
  ## Here we fabricate our added variables composed of multiple variables
  mutate(
    assists = assists1 + assists2,
    place_shots_net = shots / xon_goal,
    finishing_lowdanger = goals_lowdanger / xg_lowdanger,
    finishing_mediumdanger = goals_mediumdanger / xg_mediumdanger,
    finishing_highdanger = goals_highdanger / xg_highdanger,
    finishing_rebound = goals_rebound / xg_rebound
  ) |> 
  # Replace NA, NaN with 0
  tidyr::replace_na(list(
    place_shots_net = 0,
    finishing_lowdanger = 0,
    finishing_mediumdanger = 0,
    finishing_highdanger = 0,
    finishing_rebound = 0
  )) |>
  # Remove aberrations by bringing back to XX centile
  mutate(
    place_shots_net = ptspredictR::cap_values_above_threshold(place_shots_net, 0.99),
    finishing_lowdanger = ptspredictR::cap_values_above_threshold(finishing_lowdanger, 0.95),
    finishing_mediumdanger = ptspredictR::cap_values_above_threshold(finishing_mediumdanger, 0.95),
    finishing_highdanger = ptspredictR::cap_values_above_threshold(finishing_highdanger, 0.98),
    finishing_rebound = ptspredictR::cap_values_above_threshold(finishing_rebound, 0.975),
  ) |> 
  select(-name, -assists1, -assists2)

df_player_infos <- readRDS("data/warehouse/player_infos.rds")

df_dependent_variables <- df_individual_skaters |> 
  filter(situation == "all") |> 
  select(
    player_id, season,
    points, goals, assists, games_played
  )

df_lines <- readRDS("data/warehouse/lines.rds")

# 2. Individual stats ----------------------------------------------------------------
df_even <- df_individual_skaters |> 
  filter(situation == "5on5") |> 
  select(
    player_id,
    season,
    ev_icetime = icetime,
    all_of(ptspredictR::ev_variables)
    )

df_pp <- df_individual_skaters |> 
  filter(situation == "5on4") |> 
  select(
    player_id,
    season,
    pp_icetime = icetime,
    all_of(ptspredictR::pp_variables)
    )

# 3. Teammates stats -----------------------------------------------------------

df_individual_teammates <- df_individual_skaters |> 
  select(
    player_id, season,
    all_of(ptspredictR::teammates_variables)
  )

## Join df_individual_teammates on time share of linemates by player id
df_individual_linemates <- ptspredictR::get_teammates_time_share(df_lines) |> 
  mutate(player_id = as.numeric(player_id)) %>%
  left_join(
    ., df_individual_teammates,
    by = c("player_id", "season")
  ) |> 
  tidyr::pivot_longer(
    cols = names(ptspredictR::teammates_variables),
    names_to = "variable"
  ) |> 
  tidyr::drop_na()

df_teammates <- df_individual_linemates |> 
  group_by(player_id, season, variable) |> 
  summarise(
    mean = weighted.mean(x = value, w = prop_icetime)
  ) |> 
  tidyr::pivot_wider(
    names_from = "variable",
    values_from = "mean"
  )

# 4. Team stats ----------------------------------------------------------




# 5. Join everything --------------------------------------------------------

output <- df_even %>%
  left_join(
    ., df_player_infos,
    by = "player_id"
    ) %>%
  left_join(
      ., df_pp,
      by = c("player_id", "season")
    )%>%
  left_join(
    ., df_teammates,
    by = c("player_id", "season")
  ) %>%
  #left_join(
  #  ., df_team_stats,
  #  by = c("player_id", "season")
  #) %>%
  left_join(
    ., df_dependent_variables,
    by = c("player_id", "season")
  ) |> 
  mutate(age = season - yob) |> 
  select(
    -all_of(c("yob", "first_name", "last_name"))
  ) |> 
  relocate(
    points, goals, assists, games_played, age, height, draft_rank, ev_icetime, pp_icetime
  ) |> 
  tidyr::drop_na()

# Save datasets by position ----------------------------------------------

output_f <- output |> 
  filter(position %in% c("C", "L", "R")) |> 
  select(-position)

saveRDS(output_f, "data/marts/data_random_forest_forwards.rds")

output_d <- output |> 
  filter(position %in% c("D")) |> 
  select(-position)

saveRDS(output_d, "data/marts/data_random_forest_defensemen.rds")
