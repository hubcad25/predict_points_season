# Packages ---------------------------------------------------------------
library(dplyr)

# Data -------------------------------------------------------------------

df_iv_projections <- readRDS("data/marts/projections/independent_variables_projections.rds")

df_icetime <- readRDS("data/marts/projections/ev_icetime_by_player.rds") |>
  rename(ev_icetime = total_icetime) %>% 
  left_join(
    .,
    readRDS("data/marts/projections/pp_icetime_by_player.rds") |> select(player_id, pp_icetime),
    by = "player_id"
  ) |> 
  relocate(player_id, team)

df_teammates_time_share <- readRDS("data/marts/projections/teammates_time_share.rds")

# 3. Teammates stats -----------------------------------------------------------

df_iv_teammates <- df_iv_projections |> 
  select(
    player_id,
    all_of(ptspredictR::teammates_variables)
  )

## Join df_individual_teammates on time share of linemates by player id
df_individual_linemates <- df_teammates_time_share |> 
  mutate(player_id = as.integer(player_id)) %>% 
  left_join(
    ., df_iv_teammates,
    by = c("player_id")
  ) |> 
  tidyr::pivot_longer(
    cols = names(ptspredictR::teammates_variables),
    names_to = "variable"
  ) |> 
  tidyr::drop_na()

df_teammates <- df_individual_linemates |> 
  group_by(player_id, variable) |> 
  summarise(
    mean = weighted.mean(x = value, w = prop_icetime)
  ) |> 
  tidyr::pivot_wider(
    names_from = "variable",
    values_from = "mean"
  )

# 5. Join everything --------------------------------------------------------

output <- df_iv_projections %>%
  left_join(
      ., df_icetime,
      by = "player_id"
    )%>%
  left_join(
    ., df_teammates,
    by = "player_id"
  ) %>%
  mutate(age = season - yob) |> 
  select(
    -past_stats, -yob
  ) |> 
  tidyr::replace_na(list(pp_icetime = 0, country = "RUS")) |> 
  relocate(
    player_id, first_name, last_name, age, team, height, draft_rank, position, country, ev_icetime, pp_icetime
  )

# Save dataset ----------------------------------------------

saveRDS(output, "data/marts/projections/final_projections.rds")

