## This script takes the lines dataset in the warehouse and transforms it into a dataframe containing each pair of players that played on a line together and sums up their icetime together. Then, it divides this value by the total icetime of each player, thus resulting in the teammates time distribution of each player.

# Packages ---------------------------------------------------------------
library(dplyr)

# Wrangling --------------------------------------------------------------
data <- readRDS("data/warehouse/lines.rds")  

output <- ptspredictR::get_teammates_time_share(data)
