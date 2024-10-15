# Packages ---------------------------------------------------------------
library(DBI)
library(RPostgres)
library(dplyr)

# Retrieve data ----------------------------------------------------------
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = 'dbpool',
  host = 'intently-obliging-whippoorwill.data-1.use1.tembo.io',
  port = 5432,
  user = 'postgres',
  password = 'VbMOHfh76LsozTRi'
)

df_alignements_raw <- dbGetQuery(
  con,
  "SELECT alignements.idpooler, joueurs.idnhl,
  joueurs.position, joueurs.prenomjoueur, joueurs.nomjoueur,
  alignements.statutjoueur, alignements.prop_caphit
  FROM alignements JOIN joueurs ON alignements.idnhl = joueurs.idnhl
  WHERE alignements.datefin::date >= CURRENT_DATE
  AND idpooler = 'PAT'
  ")

dbDisconnect(con)

### Add Sam Bennett and change Hutson's status
df_alignements <- df_alignements_raw |> 
  add_row(
    idpooler = 'PAT',
    idnhl = as.integer(8477935),
    position = "C",
    prenomjoueur = "Sam",
    nomjoueur = "Bennett",
    statutjoueur = "Alignement",
    prop_caphit = 1
  ) |> 
  ## Change Hutson
  mutate(
    statutjoueur = ifelse(idnhl == 8483457, "Alignement", statutjoueur)
  ) |> 
  ## Remove espoir
  filter(statutjoueur != "Espoir")

# Join cap_hit -----------------------------------------------------------

df_cap_hit <- readRDS("data/warehouse/players_caphits.rds")

df_alignements_cap_hit <- left_join(
  df_alignements,
  df_cap_hit,
  by = c("idnhl" = "player_id")
) |> 
  ## Fill in goalies manually
  mutate(
    cap_hit = case_when(
      idnhl == 8478916 ~ 1200000,
      idnhl == 8480382 ~ 3400000,
      idnhl == 8479312 ~ 900000,
      TRUE ~ cap_hit
    ),
    cap_hit = prop_caphit * cap_hit
  ) |>
  tidyr::drop_na(cap_hit)

dead_cap <- sum(df_alignements_cap_hit$cap_hit[df_alignements_cap_hit$statutjoueur == "SalaireRetenu"])
saveRDS(dead_cap, "data/marts/projections/patriotes/dead_cap.rds")

# Join points ------------------------------------------------------------

df_points <- readRDS("data/marts/projections/final_points_predictions.RDS") |> 
  select(player_id, points)

# Hutson 30
# Boqvist 31
# Dach 55
# Rossi 57
# Daccord 49
# Georgiev 79
# Lyon 45

## Join
sim_data <- left_join(
  df_alignements_cap_hit,
  df_points,
  by = c("idnhl" = "player_id")
) |> 
### Fill in manually for some players
  mutate(
    points = case_when(
      idnhl == 8483457 ~ 30,
      idnhl == 8480871 ~ 31,
      idnhl == 8481523 ~ 55,
      idnhl == 8482079 ~ 57,
      idnhl == 8478916 ~ 49,
      idnhl == 8480382 ~ 79,
      idnhl == 8479312 ~ 45,
      TRUE ~ points
    )
  ) |> 
  filter(
    statutjoueur != "SalaireRetenu"
  ) |> 
  ## Sure players: McDavid, Josi, Robertson, Bedard, Georgiev, Hughes, Verhaeghe, Cooley
  mutate(
    position = ifelse(
      position %in% c("C", "L", "R", "A"),
      "F",
      position
    ),
    sure = ifelse(
      idnhl %in% c(8478402, 8474600, 8480027, 8484144, 8480382, 8480800, 8477409, 8483431),
      1,
      0
    )
  )

# Loop -------------------------------------------------------------------

## Take sure players
## Take a random sample of n players while making sure we have minimum 9F 4D
### If masse_salariale > plafond, redo
## Put the top 9/4 in Alignement, the rest in reserve
## Simulate 20 different scenarios of injuries.
#### Each scenario gets a gravity parameter
#### This parameter indicates how much players are injured and for how long
#### We assume McDavid and Josi won't be injured 

min_n_forwards <- 11 - sum(sim_data$sure[sim_data$position == "F"])
min_n_defensemen <- 5 - sum(sim_data$sure[sim_data$position == "D"])
freq_positions <- table(sim_data$position)
plafond <- 88000000 - dead_cap

## Simulate 2000 lineups --------------------------------------------------
for (i in 1:2000){
  repeat {
    sim_datai <- sim_data |> 
      mutate(
        iter = i,
        taken = sure
      )
    forwards_taken <- sample(
      x = sim_datai$idnhl[sim_datai$position == "F" & sim_datai$taken == 0], 
      size = sample(min_n_forwards:9, size = 1),
      replace = FALSE
    )
    sim_datai$taken[sim_datai$idnhl %in% forwards_taken] <- 1
    players_left_to_pick <- 20 - sum(sim_datai$taken)
    max_defensemen_to_pick <- length(sim_datai$idnhl[sim_datai$position == "D" & sim_datai$taken == 0])
    max_d <- if (players_left_to_pick <= max_defensemen_to_pick){
      players_left_to_pick
    } else {
      max_defensemen_to_pick
    }
    if (max_d == 3){
      defensemen_taken <- sample(
        x = sim_datai$idnhl[sim_datai$position == "D" & sim_datai$taken == 0], 
        size = 3,
        replace = FALSE
      )
    } else {
      defensemen_taken <- sample(
        x = sim_datai$idnhl[sim_datai$position == "D" & sim_datai$taken == 0], 
        size = sample(min_n_defensemen:max_d, size = 1),
        replace = FALSE
      )
    }
    sim_datai$taken[sim_datai$idnhl %in% defensemen_taken] <- 1
    players_left_to_pick <- 20 - sum(sim_datai$taken)
    if (players_left_to_pick > 0){
      goalie_taken <- sample(
        x = sim_datai$idnhl[sim_datai$position == "G" & sim_datai$taken == 0], 
        size = sample(x = 0:1, size = 1, prob = c(0.25, 0.75)),
        replace = TRUE
      )
      sim_datai$taken[sim_datai$idnhl == goalie_taken] <- 1
    }
    masse_salariale <- sum(sim_datai$taken * sim_datai$cap_hit)
    #cap_space <- plafond - masse_salariale
    sim_datai <- sim_datai |> 
      group_by(taken, position) |> 
      mutate(
        rank = rank(-points, ties.method = "random"),
        status = case_when(
          taken == 1 & position == "F" & rank <= 9 ~ "alignement",
          taken == 1 & position == "F" & rank > 9 ~ "reserve",
          taken == 1 & position == "D" & rank <= 4 ~ "alignement",
          taken == 1 & position == "D" & rank > 4 ~ "reserve",
          taken == 1 & position == "G" & rank <= 1 ~ "alignement",
          taken == 1 & position == "G" & rank > 1 ~ "reserve"
        )
      )
    if (masse_salariale < plafond) break
  }
  if (i == 1){
    sim_lineups <- sim_datai
  } else {
    sim_lineups <- rbind(sim_lineups, sim_datai)
  }
  if (i %% 50 == 0){
    message(i)
  }
}

saveRDS(sim_lineups, "data/marts/projections/patriotes/lineups.rds")

## Simulate injury scenarios and calculate points -------------------------
generate_beta_distribution <- function(injury_gravity, n = 1000, intensity = 7, n_values = 8) {
  # Définir les paramètres alpha et beta pour ajuster l'asymétrie (skewness)
  beta <- intensity * (1 - injury_gravity) + 1  # Contrôle le biais vers les petites valeurs
  alpha <- intensity * injury_gravity + 1       # Contrôle le biais vers les grandes valeurs
  # Générer des valeurs avec rbeta qui varient de 0 à 1
  values <- rbeta(n, shape1 = alpha, shape2 = beta)
  # Adapter ces valeurs pour les mapper dans une échelle de 0 à 8
  scaled_values <- round(values * n_values)
  # Calculer les probabilités d'apparition pour chaque valeur (de 0 à 8)
  prob <- table(factor(scaled_values, levels = 0:n_values)) / n
  # Convertir en vecteur de probabilités
  prob <- as.numeric(prob)
  return(prob)
}

generate_rank_probabilities <- function(max_rank, injury_gravity) {
  beta <- 1 + 5 * injury_gravity
  alpha <- 1 + 5 * (1 - injury_gravity)
  rank_values <- 2:max_rank
  probs <- dbeta((rank_values - 1) / (max_rank - 1), alpha, beta)
  probs <- probs / sum(probs)
  return(probs)
}

generate_rank_sample <- function(position, injury_gravity, size) {
  if (position == "F") {
    max_rank <- 9
  } else if (position == "D") {
    max_rank <- 4
  } else if (position == "G") {
    return(1)
  }
  probs <- generate_rank_probabilities(max_rank, injury_gravity)
  probs <- ifelse(probs == 0, .Machine$double.eps, probs)
  return(sample(2:max_rank, size = size, prob = probs))
}

generate_distribution_params <- function(injury_gravity) {
  # Paramètres pour l'exponentielle
  a <- 2.5      # Mean de départ
  final_mean <- 50
  b <- log(final_mean / a) # Calcul du paramètre b pour aller de 2.5 à 50

  # Mean exponentielle en fonction de injury_gravity
  mean_value <- a * exp(b * injury_gravity)
  
  # SD dynamique comme avant
  sd_value <- 0.2 + injury_gravity * (10 - 0.2)  # SD passe de 0.2 à 10
  
  return(list(mean = mean_value, sd = sd_value))
}

for (i in 1:2000){
  df_lineup <- sim_lineups |>
    ungroup() |> 
    filter(iter == i)
  for (j in (0:20)/20){
    n_players_injured <- sample(
      0:8,
      size = 1,
      prob = generate_beta_distribution(j)
    )
    if (n_players_injured == 0){
      df_lineupj <- df_lineup |> 
        rename(final_points = points) |> 
        filter(status == "alignement")
      total_points <- sum(df_lineupj$final_points)
    } else {
      n_games_missed <- sample(
        1:15,
        size = n_players_injured,
        prob = generate_beta_distribution(j, n_values = 14, intensity = 5)
      )
      n_augmented <- round((j * 0.45) * n_players_injured)
      if (n_augmented > 0) {
        indices_augmented <- sample(1:n_players_injured, n_augmented)
        params <- generate_distribution_params(j)
        n_games_missed[indices_augmented] <- n_games_missed[indices_augmented] + ceiling(rnorm(n_augmented, mean = params$mean, sd = params$sd))
      }
      repeat {
        position_of_injured_players <- sample(
          x = c("F", "D", "G"),
          size = n_players_injured,
          replace = TRUE,
          prob = c(9, 4, 1)
        ) 
        # Conditions pour sortir de la boucle
        if (sum(position_of_injured_players == "F") <= 8 && sum(position_of_injured_players == "D") <= 3) {
          break
        }
      }
      players_ranks <- vector("numeric", length = n_players_injured)
      if (!is.na(table(position_of_injured_players)["F"])){
        players_ranks[position_of_injured_players == "F"] <- generate_rank_sample("F", j, table(position_of_injured_players)["F"])
      }
      if (!is.na(table(position_of_injured_players)["D"])){
        players_ranks[position_of_injured_players == "D"] <- generate_rank_sample("D", j, table(position_of_injured_players)["D"])
      }
      players_ranks[position_of_injured_players == "G"] <- 1
      df_injured <- data.frame(
        rank = as.integer(players_ranks),
        position = position_of_injured_players,
        n_games_missed
      )
      df_lineupj <- left_join(
        df_lineup |> filter(taken == 1), df_injured,
        by = c("rank", "position")
      ) |> 
        tidyr::replace_na(list(n_games_missed = 0))
      df_replacements <- df_lineupj |> 
        filter(status == "reserve") |> 
        group_by(position) |> 
        summarise(points = mean(points))
      replacements <- setNames(
        df_replacements$points,
        df_replacements$position
      )
      df_lineupj <- df_lineupj |> 
        filter(status == "alignement") |>
        mutate(
          points_replacement = replacements[position],
          points_replacement = ifelse(is.na(points_replacement), 0, points_replacement),
          final_points = (((82 - n_games_missed) / 82) * points) + (n_games_missed / 82) * points_replacement
        )
      total_points <- sum(df_lineupj$final_points)
    }
    if (j == 0){
      df_resultsi <- data.frame(
        iter = i,
        injury_gravity = j,
        total_points = total_points
      )
    } else {
      df_resultsi <- rbind(
        df_resultsi,
        data.frame(
          iter = i,
          injury_gravity = j,
          total_points = total_points
        )
      )
    }
  }
  if (i == 1){
    df_results <- df_resultsi
  } else {
    df_results <- rbind(
      df_results,
      df_resultsi
  )
  }
  cat("\ri: ", i)
}

saveRDS(df_results, "data/marts/projections/patriotes/points_by_lineup.rds")
