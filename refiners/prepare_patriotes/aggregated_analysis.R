# Packages ---------------------------------------------------------------
library(dplyr)
library(ggplot2)
library(plotly)

# Data -------------------------------------------------------------------

df_players <- readRDS("refiners/prepare_patriotes/data/main_data.rds") |> 
  filter(player_status != "SalaireRetenu")

df_lineup_spot <- readRDS("refiners/prepare_patriotes/data/points_lineup_spot.rds")

# Loop for cap values -------------------------------------------------------------------

for (i in 1:nrow(df_players)){
  cap_hiti <- df_players$mshl_cap_hit[i]
  positioni <- df_players$position[i]
  pointsi <- df_players$points[i]
  in_range_mshl <- df_players |> 
    filter(
      mshl_cap_hit >= (cap_hiti - 1000000) &
      mshl_cap_hit <= (cap_hiti + 1000000) &
      mshl_team != "free_agent" &
      mshl_team != "PAT" &
      position == positioni
    )
  mshl_cap_valuei <- (pointsi - mean(in_range_mshl$points)) / sd(in_range_mshl$points)
  # Rank of the player in terms of points
  rank_mshl <- rank(-c(in_range_mshl$points, pointsi))[c(in_range_mshl$points, pointsi) == pointsi]
  in_range_fa <- df_players |> 
    filter(
      mshl_cap_hit >= (cap_hiti - 1000000) &
      mshl_cap_hit <= (cap_hiti + 1000000) &
      mshl_team == "free_agent" &
      position == positioni
    )
  fa_cap_valuei <- (pointsi - mean(in_range_fa$points)) / sd(in_range_fa$points)
  # Rank of the player in terms of points within free agents
  rank_fa <- rank(-c(in_range_fa$points, pointsi))[c(in_range_fa$points, pointsi) == pointsi]
  if (i == 1){
    df_players$mshl_cap_value <- NA
    df_players$fa_cap_value <- NA
    df_players$rank_mshl <- NA
    df_players$rank_fa <- NA
  }
    df_players$mshl_cap_value[i] <- mshl_cap_valuei
    df_players$fa_cap_value[i] <- fa_cap_valuei
    df_players$rank_mshl[i] <- ifelse(length(rank_mshl) > 0, rank_mshl, NA)
    df_players$rank_fa[i] <- ifelse(length(rank_fa) > 0, rank_fa, NA)
  message(i)
}


df_plotly <- df_players |> 
  mutate(
    color = ifelse(mshl_team == "PAT", "PAT", "other"),
    color = ifelse(mshl_team == "free_agent", "free_agent", color)
  )

p <- ggplot(df_plotly, aes(x = rank_mshl, y = rank_fa)) +
  geom_jitter(
    aes(
      text = paste0(first_name, " ", last_name),
      color = color
    ),
    width = 0.5, height = 0.5,
    size = 1
  ) +
  scale_color_manual(
    values = c("PAT" = "darkgreen", "free_agent" = "gold", "other" = "darkred")
  )

plotly::ggplotly(p)

plot_ly(df_plotly, 
        x = ~mshl_cap_value, 
        y = ~fa_cap_value, 
        text = ~last_name, 
        color = ~color, 
        colors = c("PAT" = "darkgreen", "free_agent" = "gold", "other" = "darkred"),
        type = 'scatter', 
        mode = 'markers+text', 
        textposition = 'top center') %>%
  layout(
    xaxis = list(title = "Better players in MSHL"),
    yaxis = list(title = "Better players on market"),
    facet = ~position
  )

# Loop to get value by forwards lineup spot ------------------------------

df_forwards <- df_players |> filter(position == "F")
df_defensemen <- df_players |> filter(position == "D")

for (i in 1:9){
  df_spot <- df_forwards |> mutate(spot = i)
  mean <- df_lineup_spot$mean[df_lineup_spot$position == "F" & df_lineup_spot$spot == i]
  sd <- df_lineup_spot$sd[df_lineup_spot$position == "F" & df_lineup_spot$spot == i]
  df_spot$points_value <- (df_spot$points - mean) / sd
}