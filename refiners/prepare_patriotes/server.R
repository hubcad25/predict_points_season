library(shiny)
library(dplyr)
library(DT)
library(ggplot2)

# Load the data
main_data <- readRDS("data/main_data.rds") |> 
  mutate(
    player_id = as.character(player_id),
    mshl_cap_hit_label = ifelse(mshl_cap_hit >= 1000000, 
      paste0("$", round(mshl_cap_hit / 1000000, 1), "M"), 
      paste0("$", round(mshl_cap_hit / 1000), "k"))
  )
print("HEEEEEERE")
print(head(main_data$player_id))
df_lineup_spot <- readRDS("data/points_lineup_spot.rds")

get_player_ideal_spot <- function(points, data) {
  # Calculer la différence absolue entre les points et la moyenne
  data <- data |> mutate(diff = abs(points - mean))
  # Sélectionner la ligne avec la différence minimale (moyenne la plus proche)
  comparison <- data |> slice_min(diff, n = 1)
  rank <- comparison$spot[1]
  return(rank)
}

# Define server logic
shinyServer(function(input, output, session) {
  
  # Reactive: get player info
  observeEvent(input$player_picker, {
    message("input:", as.character(input$player_picker))
    message("input:", class(main_data$player_id))
    message("data:", main_data$player_id[1])
    message("data:", class(main_data$player_id))

    player_data <- main_data %>% 
      filter(player_id == as.character(input$player_picker))
    
    print(dim(player_data))

    output$salary <- renderText({ 
      paste("Salaire: ", player_data$mshl_cap_hit_label)
    })
    output$points_predicted <- renderText({ paste("Points: ", round(player_data$points)) })
    output$mshl_team <- renderText({ paste("Équipe MSHL: ", player_data$mshl_team) })
    output$ideal_lineup_spot <- renderText({ paste("Spot idéal: ", get_player_ideal_spot(player_data$points, df_lineup_spot |> filter(position == player_data$position))) })
    
    updateSliderInput(session, "salary_range", 
                      min = 0, 
                      max = 15000000, 
                      value = c(player_data$mshl_cap_hit - 1000000, player_data$mshl_cap_hit + 1000000))
  })

  observeEvent(input$input_draft, {
    source("prepare_data.R")
    print(getwd())
    setwd("refiners/prepare_patriotes")
    print(getwd())
    main_data <- readRDS("data/main_data.rds") |> 
      mutate(
        player_id = as.character(player_id),
        mshl_cap_hit_label = ifelse(mshl_cap_hit >= 1000000, 
          paste0("$", round(mshl_cap_hit / 1000000, 1), "M"), 
          paste0("$", round(mshl_cap_hit / 1000), "k"))
      ) |> 
      arrange(-points)
    # Create vector of players
    players_in_picker <- setNames(
      as.character(main_data$player_id),
      paste0(main_data$first_name, " ", main_data$last_name, " || ", round(main_data$points), " pts || ", main_data$mshl_team," ", main_data$mshl_cap_hit_label)
    )
    # Mettre à jour le pickerInput des joueurs dans l'UI
    updatePickerInput(session, "player_picker", choices = players_in_picker)
    df_lineup_spot <- readRDS("data/points_lineup_spot.rds")
    print(dim(main_data))
    print(dim(df_lineup_spot))
  })

  # Reactive: run filter for MSHL Players
  observeEvent(input$run, {
    player_position <- main_data$position[main_data$player_id == input$player_picker]
    filtered_players <- main_data %>% 
      filter(
        !(mshl_team %in% c("free_agent", "PAT")) &
        mshl_cap_hit >= input$salary_range[1] &
        mshl_cap_hit <= input$salary_range[2] &
        position == player_position &
        player_id != input$player_picker
      )
    
    output$points_histogram_mshl <- renderPlot({
      player_data <- main_data %>% 
        filter(player_id == input$player_picker)
      ggplot(filtered_players, aes(x = points)) +
        geom_density(fill = "lightblue", color = NA, adjust = 0.5) +
        clessnize::theme_clean_dark() +
        geom_vline(xintercept = player_data$points, color = "red", linewidth = 1.5) +
        scale_x_continuous(limits = c(0, 155), breaks = seq(from = 0, to = 155, by = 10))
    })
    
    output$mshl_table <- renderDT({
      datatable(
        filtered_players %>%
          mutate(name = paste0(first_name, " ", last_name)) |> 
          select(name, mshl_team, mshl_cap_hit_label, points) |>
          mutate(points = round(points)) |>
          arrange(-points), 
        options = list(searching = TRUE, pageLength = 20)
      )
    })
  })
  
  # Reactive: run filter for Free Agents
  observeEvent(input$run, {
    player_position <- main_data$position[main_data$player_id == input$player_picker]
    filtered_players_fa <- main_data %>% 
      filter(
        mshl_team == "free_agent" &
        mshl_cap_hit >= input$salary_range[1] &
        mshl_cap_hit <= input$salary_range[2] &
        position == player_position &
        player_id != input$player_picker
      )
    
    output$points_histogram_fa <- renderPlot({
      player_data <- main_data %>% 
        filter(player_id == input$player_picker)
      ggplot(filtered_players_fa, aes(x = points)) +
        geom_density(fill = "lightblue", color = NA, adjust = 0.5) +
        clessnize::theme_clean_dark() +
        geom_vline(xintercept = player_data$points, color = "red", linewidth = 1.5) +
        scale_x_continuous(limits = c(0, 155), breaks = seq(from = 0, to = 155, by = 10))
    })
    
    output$fa_table <- renderDT({
      datatable(
        filtered_players_fa %>% 
          mutate(name = paste0(first_name, " ", last_name)) |> 
          select(name, mshl_team, mshl_cap_hit_label, points) |>
          mutate(points = round(points)) |>
          arrange(-points), 
        options = list(searching = TRUE, pageLength = 20))
    })
  })
  # Reactive: filter players from Patriotes for Forwards and Defensemen
  patriotes_data <- main_data %>% filter(mshl_team == "PAT") |> 
    mutate(
      name = paste0(first_name, " ", last_name)
    ) |> 
    select(name, mshl_cap_hit_label, points, position, player_status) |>
    mutate(points = round(points))

  output$patriotes_forwards_table <- renderDT({
    datatable(
      patriotes_data %>% filter(position == "F") %>% 
        filter(player_status != "SalaireRetenu") %>%
        mutate(spot = rank(-points)) |> 
        arrange(-points) %>%
        left_join(
          .,
          df_lineup_spot |> filter(position == "F"),
          by = "spot"
        ) |> 
        mutate(
          value = round((points - mean) / sd, 2)  
        ) |> 
        select(
          name,
          player_status,
          mshl_cap_hit_label,
          points,
          value
        ),
      options = list(pageLength = 20, searching = TRUE)
    ) %>%
      formatStyle(
        'value',
        backgroundColor = styleInterval(
          seq(-2, 2, length.out = 99),  # 100 intervals for a smoother gradient
          scales::col_numeric(palette = c("red", "black", "blue"), domain = c(-2, 2))(seq(-2, 2, length.out = 100))
        )
      )
  })

  output$patriotes_defensemen_table <- renderDT({
    datatable(
      patriotes_data %>% filter(position == "D") %>% 
        filter(player_status != "SalaireRetenu") %>%
        mutate(spot = rank(-points)) |> 
        arrange(-points) %>%
        left_join(
          .,
          df_lineup_spot |> filter(position == "D"),
          by = "spot"
        ) |> 
        mutate(
          value = round((points - mean) / sd, 2)  
        ) |> 
        select(
          name,
          player_status,
          mshl_cap_hit_label,
          points,
          value
        ),
      options = list(pageLength = 10, searching = TRUE)
    ) %>%
      formatStyle(
        'value',
        backgroundColor = styleInterval(
          seq(-2, 2, length.out = 99),  # 100 intervals for a smoother gradient
          scales::col_numeric(palette = c("red", "black", "blue"), domain = c(-2, 2))(seq(-2, 2, length.out = 100))
        )
      )
  })
  output$patriotes_salaireretenu_table <- renderDT({
    datatable(
      patriotes_data %>% filter(player_status == "SalaireRetenu") %>% 
        select(
          name,
          mshl_cap_hit_label
        ),
      options = list(pageLength = 10, searching = TRUE)
    )
  })
})
