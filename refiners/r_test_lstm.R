library(dplyr)
library(keras)
library(ggplot2)
#library(tensorflow)

data <- readRDS("data/warehouse/test_lstm.rds")

# Convertir les past_stats en une matrice et diviser en train/test
X_data <- array(NA, dim = c(nrow(data), 3, length(data$past_stats[[1]])))
for (i in 1:nrow(data)) {
  X_data[i,,] <- as.matrix(unlist(data$past_stats[[i]]))
}

# Extraire les autres variables (age, draft_rank, height) et les répéter 3 fois pour chaque timestep
X_additional <- aperm(
  array(
    rep(array(unlist(data[, c("age", "draft_rank", "height")])), times = 3),
    dim = c(nrow(data), ncol(data[, c("age", "draft_rank", "height")]), 3)
  ),
  perm = c(1, 3, 2)
)

# Combiner les deux matrices en ajoutant les variables supplémentaires à la dimension des features
X <- array(c(X_data, X_additional), dim = c(dim(X_data)[1], dim(X_data)[2], dim(X_data)[3] + dim(X_additional)[3]))

# La variable cible : game_score
y <- as.matrix(data$game_score)


# Train model ------------------------------------------------------------

input_layer <- layer_input(shape = c(3, dim(X)[3]))  # Déclare l'entrée explicitement

output_layer <- input_layer %>%
  layer_lstm(units = 50, return_sequences = FALSE) %>%
  layer_dense(units = 1)

model <- keras_model(inputs = input_layer, outputs = output_layer)

# Compilation du modèle

model %>% tensorflow::tf$keras$Model$compile(
  loss = 'mean_squared_error',
  optimizer = 'adam'
)

history <- model %>% tensorflow::tf$keras$Model$fit(
  X, y,
  epochs = as.integer(100),
  batch_size = as.integer(32),
  validation_split = 0.2
)

plot_data <- as.data.frame(history$history) %>%
  mutate(x = 1:nrow(.)) %>%
  tidyr::pivot_longer(
  cols = c("loss", "val_loss"),
  values_to = "loss"
  )

ggplot(plot_data, aes(x = x, y = loss)) +
  geom_line(aes(group = name, color = name))

# Reformater new_X pour avoir 3 dimensions (1, timesteps, features)
i <- 1:nrow(data)
new_X <- array(X[i,,], dim = c(1, dim(X)[2], dim(X)[3]))

new_X <- X[i,,]

preds <- model %>% tensorflow::tf$keras$Model$predict(new_X)
real <- data$game_score[i]

check <- data.frame(
  pred <- preds[,1],
  real
)

ggplot(check, aes(x = real, y = pred)) +
  geom_jitter() +
  geom_smooth()
