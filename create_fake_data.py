import numpy as np
import random
import json

# Fonction pour générer des données de temps de glace (time_on_ice) pour plusieurs joueurs
def generate_fake_data(num_players=150):
    time_on_ice = {}
    
    for i in range(1, num_players + 1):
        player_id = f'player{i}'
        
        # Générer un nombre aléatoire de valeurs passées (entre 1 et 10)
        past_length = random.randint(1, 10)
        past = np.random.randint(1, 20, size=past_length).tolist()
        
        # Générer une cible aléatoire (target) et des variables fixes (âge et taille)
        target = random.randint(1, 20)
        age = random.randint(18, 40)
        height = random.randint(170, 200)
        
        time_on_ice[player_id] = {'past': past, 'target': target, 'age': age, 'height': height}
    
    return time_on_ice

# Générer les données pour 150 joueurs
time_on_ice_data = generate_fake_data(150)

# Affichage des premières données pour visualisation
for player, data in list(time_on_ice_data.items())[:5]:
    print(player, data)

# Sauvegarder le dictionnaire dans un fichier JSON
with open('time_on_ice_data.json', 'w') as f:
    json.dump(time_on_ice_data, f)
