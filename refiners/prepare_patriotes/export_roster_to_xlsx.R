# Packages ---------------------------------------------------------------
library(DBI)
library(RPostgres)
library(dplyr)
options(scipen = 999)

# Connect to SQL db to get MSHL lineups ----------------------------------
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = 'dbpool',
  host = 'intently-obliging-whippoorwill.data-1.use1.tembo.io',
  port = 5432,
  user = 'postgres',
  password = 'VbMOHfh76LsozTRi'
)

alignements <- dbGetQuery(con, paste0(
  "SELECT idpooler, idnhl, statutjoueur, prop_caphit 
   FROM alignements 
   WHERE TO_DATE(datefin, 'YYYY-MM-DD') >= '", Sys.Date(), "'::date 
   AND (statutjoueur <> 'SalaireRetenu' OR (statutjoueur = 'SalaireRetenu' AND idpooler = 'PAT'))"
)) |> 
  rename(
    mshl_team = idpooler,
    player_id = idnhl,
    player_status = statutjoueur,
    prop_cap_hit = prop_caphit
  )

dbDisconnect(con)

# Load points predictions and cap hit ------------------------------------

df_points <- readRDS("data/marts/projections/final_points_predictions.RDS") %>% 
  left_join(
    .,
    readRDS("data/warehouse/players_caphits.rds"),
    by = "player_id") %>%
  left_join(
    .,
    alignements,
    by = "player_id") |> 
  mutate(
    mshl_team = ifelse(is.na(mshl_team), "free_agent", mshl_team),
    player_status = ifelse(is.na(player_status), "free_agent", player_status),
    prop_cap_hit = ifelse(is.na(prop_cap_hit), 1, prop_cap_hit),
    mshl_cap_hit = prop_cap_hit * cap_hit,
    position = ifelse(position %in% c("C", "L", "R"), "F", "D")
  )

patriotes <- df_points |> 
  filter(mshl_team == "PAT") |> 
  select(
    player_id,
    first_name,
    last_name,
    position,
    player_status,
    mshl_cap_hit,
    points
  )

write.csv(patriotes, "../MSHL/OffSeason2024/patriotes.csv")
