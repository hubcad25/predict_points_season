## This script takes the data that is used to train the random forest models to prepares them for the lstm models that are going to be used to project IVs for the next season and thus use the random forest models to predict the points of a player. It saves data for all players into a json file

# Packages ---------------------------------------------------------------
library(dplyr)

# Load data --------------------------------------------------------------
data <- rbind(
  readRDS("data/marts/data_random_forest_forwards.rds"),
  readRDS("data/marts/data_random_forest_defensemen.rds")
)

### Player infos for fixed variables: age, height, draft_rank, country
df_player_infos <- readRDS("data/warehouse/player_infos.rds") |> 
  mutate(
    forward = ifelse(position %in% c("C", "L", "R"), 1, 0),
    defenseman = ifelse(position == "D", 1, 0)
) |> 
  select(player_id, yob, height, draft_rank, forward, defenseman)

# Set variables to include in past stats ----------------------------------------------------------
variables <- c(
  "ev_icetime", "pp_icetime",
  ptspredictR::ev_variables,
  names(ptspredictR::pp_variables)
)

# Build past stats dataframe ---------------------------------------------
df_past_stats <- ptspredictR::build_past_stats_df(
  data = data,
  variables = variables,
  window = 3
) %>%
  # Add player infos
  left_join(., df_player_infos, by = "player_id") |> 
  filter(season >= 2011) |> 
  mutate(age = season - yob) |> 
  select(-yob)

# Add targets and save as big json ---------------------------------------
path <- "data/marts/lstm_data/"

for (i in variables){
  ## Add target
  df_target_only <- data |>
    select(player_id, season, all_of(i))
  df_with_target <- left_join(
    df_past_stats,
    df_target_only,
    by = c("player_id", "season")
  )
  ptspredictR::save_df_past_stats_as_json(
    df_past_stats = df_with_target,
    output_file = paste0(path, i, ".rds")
  )
}

saveRDS(df_with_target, file = "data/warehouse/test_lstm.rds")

# Fonction pour structurer les past_stats en vecteurs de 3 éléments dans une liste
get_past_stats_as_vector <- function(past_stats) {
  sapply(past_stats[[1]], function(x) as.vector(x), simplify = FALSE)
}

# Fonction principale pour générer le JSON
generate_json <- function(df) {
  # Initialisation d'une liste pour stocker les données finales
  players_list <- list()
  
  # Boucle à travers chaque ligne du dataframe
  for (i in seq_len(nrow(df))) {
    player_id <- paste0("player", i)
    
    # Extraction des past_stats sous forme de vecteurs de 3 éléments
    past_stats_vector <- get_past_stats_as_vector(df$past_stats[i])
    
    # Création d'un dictionnaire pour le joueur
    player_data <- list(
      past_stats = past_stats_vector,
      target = df$target[i],
      age = df$age[i],
      height = df$height[i]
    )
    
    # Ajout des données du joueur à la liste finale
    players_list[[player_id]] <- player_data
    message(i)
  }
  
  # Conversion de la liste en JSON
  json_output <- jsonlite::toJSON(players_list)
  
  return(json_output)
}

json_result <- generate_json(df_with_target)


