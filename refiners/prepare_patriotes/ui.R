library(shiny)
library(DT)
library(shinyWidgets)
library(shinythemes)

# Load the data
main_data <- readRDS("data/main_data.rds") |> 
  dplyr::mutate(
    player_id = as.character(player_id),
    mshl_cap_hit_label = ifelse(mshl_cap_hit >= 1000000, 
      paste0("$", round(mshl_cap_hit / 1000000, 1), "M"), 
      paste0("$", round(mshl_cap_hit / 1000), "k"))
  ) |> 
  dplyr::arrange(-points)

# Create vector of players
players_in_picker <- setNames(
  as.character(main_data$player_id),
  paste0(main_data$first_name, " ", main_data$last_name, " || ", round(main_data$points), " pts || ", main_data$mshl_team," ", main_data$mshl_cap_hit_label)
)

# Define UI for application
shinyUI(fluidPage(
  
  theme = shinytheme("cyborg"),

  # Placeholder for tabs
  navbarPage(
    "Préparation Pool",
    tabPanel(
      "Joueurs dans Price Range",
      
      # First row: Player picker, RUN button, Salary, Points, Position info
      fluidRow(
        column(3, 
               pickerInput(
                "player_picker",
                "Sélectionner un joueur",
                choices = players_in_picker,
                multiple = FALSE,
                options = list(`live-search`=TRUE)
              ),
              sliderInput("salary_range", "Range de salaire", min = 0, max = 15000000, value = c(3000000, 5000000), step = 100000, ticks = FALSE)
        ),
        column(1, 
               actionButton("run", "RUN"),
               p("     "),
               actionButton("input_draft", "Input draft")
        ),
        column(2, 
               textOutput("salary"), 
               br(), 
               textOutput("points_predicted"), 
               br(), 
               textOutput("mshl_team"), 
               br(), 
               textOutput("ideal_lineup_spot")
        )
      ),
      
      # Third row: Headers for MSHL and Free Agents
      fluidRow(
        column(6, h3("MSHL")),
        column(6, h3("Agents libres"))
      ),
      
      # Fourth row: Two plots (MSHL and Free Agents)
      fluidRow(
        column(6, plotOutput("points_histogram_mshl", width = "75%", height = "300px")),
        column(6, plotOutput("points_histogram_fa", width = "75%", height = "300px"))
      ),
      
      # Fifth row: Two tables (MSHL and Free Agents)
      fluidRow(
        column(6, DTOutput("mshl_table")),
        column(6, DTOutput("fa_table"))
      )
    ),
    tabPanel(
      "Joueurs Patriotes",
      
      # First row: Headers for Forwards and Defensemen
      fluidRow(
        column(6, h3("Attaquants")),
        column(6, h3("Défenseurs")),
        column(6, h3("Salaire retenu"))
      ),
      
      # Second row: Tables for Forwards and Defensemen
      fluidRow(
        column(6, DTOutput("patriotes_forwards_table")),
        column(6, DTOutput("patriotes_defensemen_table")),
        column(6, DTOutput("patriotes_salaireretenu_table"))
      )
    )
  )
))
