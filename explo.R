library(keras)

# Exemple de séries temporelles pour plusieurs joueurs
time_on_ice <- list(
  player1 = list(past = c(3, 8, 10), target = 12, age = 25, height = 180),
  player2 = list(past = c(15, 14, 16, 12, 8), target = 1, age = 30, height = 185),
  player3 = list(past = c(13), target = 17, age = 22, height = 178)
)

# Trouver la longueur maximale des séries temporelles pour faire du padding
max_length <- max(sapply(time_on_ice, function(player) length(player$past)))

# Padding des séries temporelles pour qu'elles aient toutes la même longueur
padded_series <- lapply(time_on_ice, function(player) {
  c(rep(0, max_length - length(player$past)), player$past)  # Padding avec des zéros
})

# Extraire les cibles et les variables fixes (âge, grandeur)
targets <- sapply(time_on_ice, function(player) player$target)
age <- sapply(time_on_ice, function(player) player$age)
height <- sapply(time_on_ice, function(player) player$height)

# Transformer les données en matrices (entrée pour le LSTM)
X_time_series <- array(unlist(padded_series), dim = c(max_length, length(time_on_ice), 1))
X_time_series <- aperm(X_time_series, c(2, 1, 3))
X_fixed <- cbind(age, height)  # Variables fixes

# Dimensions des données
num_joueurs <- length(time_on_ice)  # Nombre de joueurs (3 dans cet exemple)
max_length <- dim(X_time_series)[2]  # Longueur maximale des séries temporelles (4 ici)
num_features_fixed <- dim(X_fixed)[2]  # Nombre de variables fixes (2 ici: âge, grandeur)

# Définir les entrées pour le modèle LSTM
input_time_series <- layer_input(shape = c(max_length, 1), name = "time_series_input")
input_fixed <- layer_input(shape = c(num_features_fixed), name = "fixed_input")
