## This script loads the player ids-capwages_id combination from warehouse/player_capwages_ids_final and extracts the 2024-25 cap hit
## for each player from https://capwages.com/. It then saves the result into warehouse/players_caphits.rds which contains two columns:
## 1. player_id (nhl player id)
## 2. cap hit

# Packages ---------------------------------------------------------------
library(dplyr)
library(rvest)
options(scipen = 999)

# Load capwages ids --------------------------------------------------------------
df_capwages_ids <- readRDS("data/warehouse/player_capwages_ids_final.rds")

# Function to scrape cap hit ---------------------------------------------
get_cap_hit <- function(player_id) {
  # Construire l'URL
  url <- paste0("https://capwages.com/players/", player_id)
  # Lire le contenu de la page
  page <- rvest::read_html(url)
  # Extraire le contenu JSON à partir de la balise <script type="application/ld+json">
  json_data <- page %>%
    html_nodes('script[type="application/ld+json"]') %>%
    html_text()
  # Remplacer les entités HTML manuellement avec gsub
  decoded_json <- gsub("&quot;", '"', json_data)
  # Convertir le texte JSON en R list
  parsed_data <- jsonlite::fromJSON(decoded_json)
  # Extraire le cap_hit_text
  cap_hit_text <- parsed_data$mainEntity$contract$capHit
  # Vérifier si cap_hit_text est manquant
  if (is.na(cap_hit_text) || is.null(cap_hit_text)) {
    warning(paste("Cap hit text is missing for player:", player_id))
    return(NA)
  }
  # Nettoyer cap_hit_text pour garder uniquement les chiffres
  cap_hit <- as.numeric(gsub("[^0-9]", "", cap_hit_text))
  # Vérifier si cap_hit est manquant
  if (is.na(cap_hit)) {
    warning(paste("Cap hit value could not be converted for player:", player_id))
  }
  # Retourner cap_hit
  return(cap_hit)
}


# Loop through all players -----------------------------------------------
for (i in 1:nrow(df_capwages_ids)) {
  player_idi <- df_capwages_ids$capwages_id[i]
  message(player_idi, "  ", round(i / nrow(df_capwages_ids) * 100, 1), "%")
  # Initialiser cap_hit à NA
  cap_hit <- NA
  # Boucle pour réessayer en cas d'erreur
  repeat {
    result <- tryCatch({
      cap_hit <- get_cap_hit(player_idi)
      message("   ", cap_hit)
      break  # Si la requête réussit, sortir de la boucle
    }, error = function(e) {
      message("Error fetching data for player: ", player_idi)
      message("Sleeping for 5 seconds before retrying...")
      Sys.sleep(5)
    })
  }
  # Créer une ligne de données pour ce joueur
  df_cap_hiti <- data.frame(
    player_id = df_capwages_ids$player_id[i],
    capwages_id = player_idi,
    cap_hit = cap_hit
  )
  # Ajouter cette ligne au dataframe de résultats
  if (i == 1) {
    df_cap_hit <- df_cap_hiti
  } else {
    df_cap_hit <- rbind(df_cap_hit, df_cap_hiti)
  }
  Sys.sleep(0.5)
}

saveRDS(df_cap_hit, "data/warehouse/players_caphits.rds")
