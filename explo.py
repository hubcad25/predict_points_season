import numpy as np
import tensorflow as tf
from tensorflow.keras.models import Model
from tensorflow.keras.layers import Input, LSTM, Dense, Concatenate

# Exemple de séries temporelles pour plusieurs joueurs
time_on_ice = {
    'player1': {'past': [3, 8, 10], 'target': 12, 'age': 25, 'height': 180},
    'player2': {'past': [15, 14, 16, 12, 8], 'target': 1, 'age': 30, 'height': 185},
    'player3': {'past': [13], 'target': 17, 'age': 22, 'height': 178}
}



# Trouver la longueur maximale des séries temporelles pour faire du padding
max_length = max([len(player['past']) for player in time_on_ice.values()])

# Padding des séries temporelles pour qu'elles aient toutes la même longueur
padded_series = [
    [0] * (max_length - len(player['past'])) + player['past']
    for player in time_on_ice.values()
]

# Extraire les cibles et les variables fixes (âge, grandeur)
targets = np.array([player['target'] for player in time_on_ice.values()])
ages = np.array([player['age'] for player in time_on_ice.values()])
heights = np.array([player['height'] for player in time_on_ice.values()])

# Transformer les données en matrices (entrée pour le LSTM)
X_time_series = np.array(padded_series).reshape(len(time_on_ice), max_length, 1)
X_fixed = np.column_stack((ages, heights))  # Variables fixes

# Définir les dimensions
num_players = len(time_on_ice)  # Nombre de joueurs (3 dans cet exemple)
num_fixed_features = X_fixed.shape[1]  # Nombre de variables fixes (2 ici: âge, grandeur)

# Définir les entrées pour le modèle LSTM
input_time_series = Input(shape=(max_length, 1), name="time_series_input")
input_fixed = Input(shape=(num_fixed_features,), name="fixed_input")

# LSTM pour les séries temporelles
lstm_output = LSTM(units=50, activation='relu')(input_time_series)

# Combiner la sortie du LSTM avec les variables fixes
combined = Concatenate()([lstm_output, input_fixed])

# Ajouter une couche dense pour la prédiction finale
output = Dense(1)(combined)

# Définir et compiler le modèle
model = Model(inputs=[input_time_series, input_fixed], outputs=output)
model.compile(optimizer='adam', loss='mse')

# Afficher le résumé du modèle
model.summary()

# Entraîner le modèle avec les données
model.fit([X_time_series, X_fixed], targets, epochs=100, batch_size=1)

# Faire des prédictions après l'entraînement
predictions = model.predict([X_time_series, X_fixed])
print("Predictions:", predictions)
