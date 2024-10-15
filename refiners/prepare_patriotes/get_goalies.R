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
   WHERE TO_DATE(datefin, 'YYYY-MM-DD') > '", Sys.Date(), "'::date 
   AND (statutjoueur <> 'SalaireRetenu')"
)) |> 
  rename(
    mshl_team = idpooler,
    player_id = idnhl,
    player_status = statutjoueur,
    prop_cap_hit = prop_caphit
  )

joueurs <- dbGetQuery(con,
  "SELECT idnhl, prenomjoueur, nomjoueur, position FROM joueurs WHERE position = 'G'"
)

dbDisconnect(con)

join <- left_join(joueurs, alignements, by = c("idnhl" = "player_id")) |> 
  tidyr::drop_na(mshl_team)
