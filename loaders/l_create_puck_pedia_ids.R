# This scripts creates the warehouse tables *player_capwages_ids*
## It loads a list of player_ids and their infos.
## It checks if the players are already in *player_capwages_ids*
## For the players that are not in *player_capwages_ids*, it:
#### - Tests different possible capwages_ids
#### - Keep the one that works
#### - Creates a dataframe with the result
#### - Adds the dataframe to the existing *player_capwages_ids*
#### - The ones who did not work are stocked with NA value

# Packages ---------------------------------------------------------------
library(dplyr)
library(gemini.R)

# Data -------------------------------------------------------------------
all_players <- readRDS("data/marts/projections/final_points_predictions.RDS")$player_id

## Check if players are already in the warehouse table --------------------

### Load warehouse table
df_player_capwages_ids <- readRDS("data/warehouse/player_capwages_ids.rds")
##### Save a backup
saveRDS(df_player_capwages_ids, "data/warehouse/player_capwages_ids_backup.rds")

players_to_extract <- tryCatch(
  {
    # Tenter d'exécuter la première instruction
    all_players[!(all_players %in% df_player_capwages_ids$player_id)]
  },
  error = function(e) {
    # En cas d'erreur, exécuter cette instruction
    all_players
  }
)

# Create functions to create different possible variants of name ----------------

gemini.R::setAPI(api_key = Sys.getenv("GEMINI_API_KEY2"))

# Function to generate the prompt for Gemini to return R vector style output
generate_gemini_prompt <- function(first_name, last_name) {
  # Context and rules to provide to Gemini
  prompt <- paste0(
    "Hello, glad to have you with me.\n",
    "Context:\n",
    "I want to generate URL-friendly name variants, also known as slugs, based on first and last names. ",
    "These slugs will be used in URLs and should be formatted in lowercase, without accents, and follow certain rules.\n\n",
    
    "Rules:\n",
    "0. First and last names are ALWAYS separated by a hyphen.\n",
    "1. Spaces in first and last names should be replaced with hyphens to make the name URL-friendly.\n",
    "2. If there are initials in the first or last name (e.g., 'T.J.' or 'A.B.'), create one variant where the dots are replaced with hyphens (e.g., 'T.J.' becomes 't-j') and another variant where the dots are removed (e.g., 'T.J.' becomes 'tj').\n",
    "3. Accents should be removed from names to make them ASCII-compliant for URLs. Additionally, umlauts and other special characters should be converted to their English equivalents (e.g., 'Stützle' becomes 'stuetzle').\n",
    "4. If a first or last name contains hyphens, they should be preserved in the slug. Generate a variant with the hyphens intact, and another where the parts are concatenated without the hyphens (e.g., 'Ekman-Larsson' becomes 'ekman-larsson' and 'ekmanlarsson').\n",
    "5. For ambiguous first or last names (such as 'Alex', 'Anderson', 'Karlsson'), generate additional variants by transforming the name into common variants. For example:\n",
    "   - 'Alex' could be 'Alexandre' or 'Alexander'.\n",
    "   - 'Anderson' could also be 'Andersen' or 'Andersson'.\n",
    "   - 'Karlsson' could be 'Carlson', 'Karlson', or 'Carlsson'.\n",
    "   - **'Josh' could be expanded to 'Joshua'.**\n",
    "   - Jake could be expanded to Jacob, Jakub, etc.\n",
    "   This rule should apply to any ambiguous name, not just the examples. Really put emphasis on using multiple different variant of first and last names.\n",
    "   Don't be scared to use variants that are different from the original name, but it is really important **that the variant is a credible name in real life**.\n\n",
    
    "Please return only a valid R vector with the variants. Do not return any code or additional explanations.\n\n",
    
    "Now, generate between 2 and 10 URL-friendly slugs for the following name:\n",
    "First Name: ", first_name, "\n",
    "Last Name: ", last_name, "\n",
    "Return the slugs as a valid R vector in this form: c('slug1', 'slug2', ...).\n\n",
    "Put the most credible names first.\n",
    "Don't forget that first and last names are ALWAYS separated by a hyphen. Good luck!"
  )
  return(prompt)
}

## Clean the output from gemini
clean_and_eval_gemini_output <- function(output) {
  # Remove the backticks and "r" from the start and end of the text
  cleaned_output <- gsub("```r\\n|```", "", output)
  # Remove any extra line breaks or leading/trailing spaces
  cleaned_output <- trimws(cleaned_output)
  output <- eval(parse(text = cleaned_output))
  return(output)
}

# Example usage
first_name <- "Nate"
last_name <- "Smith"
prompt <- generate_gemini_prompt(first_name, last_name)

test <- gemini.R::gemini(
  prompt = prompt,
  maxOutputTokens = 10000
)

clean_and_eval_gemini_output(test)

## Load df_player_infos and only keep players to extract ------------------
df_player_infos <- readRDS("data/warehouse/player_infos.rds") |> 
  filter(player_id %in% players_to_extract)

# Loop through the player_ids and check if an url is found ---------------

retry_count <- 0
max_retries <- 5  # Limite de tentatives pour chaque joueur

for (index in 1:length(players_to_extract)) {
  i <- players_to_extract[index]
  first_name <- df_player_infos$first_name[df_player_infos$player_id == i]
  last_name <- df_player_infos$last_name[df_player_infos$player_id == i]
  prompt <- generate_gemini_prompt(first_name, last_name)
  # Essayer plusieurs fois en cas d'erreur avec Gemini
  repeat {
    gemini_output <- tryCatch({
      setTimeLimit(elapsed = 10)
      suppressMessages(
      gemini.R::gemini(prompt = prompt, maxOutputTokens = 10000)
      )
    }, error = function(e) {
      if (retry_count < max_retries) {
        retry_count <- retry_count + 1
        #cat("\nGemini API error. Retrying in 10 seconds... (Attempt: ", retry_count, ")")
        setTimeLimit()  # Réinitialiser la limite avant Sys.sleep()
        Sys.sleep(10)  # Attendre 10 secondes avant de réessayer
        return(NULL)
      } else {
        stop("Max retries reached for Gemini API. Moving to next player.")
      }
    }, finally = {
      setTimeLimit()  # Réinitialiser la limite de temps après chaque tentative
    })
    
    # Si Gemini renvoie un résultat valide, sortir de la boucle de réessai
    if (!is.null(gemini_output)) break
    if (is.null(gemini_output)){
      variants <- paste0(first_name, "-", last_name)
    }
  }

  variants <- clean_and_eval_gemini_output(gemini_output)
  capwages_id <- NA  # Par défaut, on n'a pas trouvé de variante valide
  
  for (j in variants) {
    url <- paste0("https://capwages.com/players/", j)
    
    # Utiliser tryCatch pour gérer les erreurs et ajouter un timeout pour les requêtes
    response <- tryCatch({
      httr::GET(url, httr::timeout(10), httr::config(ssl_verifypeer = FALSE))
    }, error = function(e) {
      return(NULL)
    })
    
    # Si la réponse est non nulle et le statut est 200, l'URL est valide
    if (!is.null(response) && response$status_code == 200) {
      capwages_id <- j
      break  # Sortir de la boucle dès qu'une URL valide est trouvée
    }
  }

  # Ajouter le résultat dans le dataframe
  df_player_capwages_ids <- rbind(df_player_capwages_ids, data.frame(player_id = i, capwages_id = capwages_id, stringsAsFactors = FALSE))
  
  # Calculer le pourcentage de progression
  progress <- round((index / length(players_to_extract)) * 100, 2)
  
  # Afficher la progression en remplaçant l'ancienne ligne
  cat("\rProgression :", progress, "%")
  saveRDS(df_player_capwages_ids, "data/warehouse/player_capwages_ids.rds")
  
  # Ajouter un léger délai entre les requêtes pour éviter de surcharger le serveur
  Sys.sleep(4)  # Délai de 1 seconde entre les requêtes
}

