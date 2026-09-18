# Install once if needed; no automatic installation:
# install.packages(c("shiny", "dplyr", "readr", "tidyr", "ggplot2", "DT"))
library(shiny)
library(dplyr)
library(ggplot2)
library(DT)
for (file in c("load_data", "metrics", "flow", "optimization", "plots")) {
  source(file.path("R", paste0(file, ".R")))
}

score_range <- getOption("abis.score_range", c(0, 1000))
enforce_order <- getOption("abis.enforce_order", TRUE)
stopifnot(length(score_range) == 2, all(is.finite(score_range)),
  all(score_range == floor(score_range)), score_range[1] < score_range[2])
default_values <- round(score_range[1] + diff(score_range) * c(.65, .7, .75))
names(default_values) <- c("weak", "strong", "match")

ui <- fluidPage(
  tags$head(tags$style(HTML("body {background:#fafafa;} .container-fluid {max-width:1600px;}
    .summary-grid {display:grid;grid-template-columns:repeat(auto-fit,minmax(155px,1fr));gap:12px;margin:16px 0;}
    .summary-item {background:white;border:1px solid #ddd;border-radius:4px;padding:12px;}
    .summary-item strong {display:block;font-size:24px;} .summary-item small {color:#555;}
    .well {background:#f1f3f4;} .shiny-input-container {max-width:100%;}
    .notice {color:#805320;} .tab-content {padding-top:16px;}"))),
  titlePanel("ABIS terskelsimulering"),
  sidebarLayout(
    sidebarPanel(width = 3,
      fileInput("result_file", "Last inn resultat-CSV", accept = ".csv"),
      selectInput("profile", "Terskelprofil", choices = character()),
      textOutput("default_source"),
      sliderInput("weak", "Weak", min = score_range[1], max = score_range[2], value = default_values["weak"], step = 1),
      sliderInput("strong", "Strong", min = score_range[1], max = score_range[2], value = default_values["strong"], step = 1),
      sliderInput("match", "Match", min = score_range[1], max = score_range[2], value = default_values["match"], step = 1),
      actionButton("reset", "Tilbakestill profilverdier"),
      tags$hr(),
      tags$p("FP: beste ikke-treff-score ≥ terskel. FN: forventet score < terskel, bare med tilgjengelig score."),
      tags$p("ExpectedFound FALSE vises separat. Scorer er ikke sannsynligheter."),
      uiOutput("validation_messages")
    ),
    mainPanel(width = 9,
      tabsetPanel(
        tabPanel("Oversikt",
          uiOutput("summary"),
          DTOutput("biometrics"),
          tags$p("Tilgjengelig viser antall saker med gyldig grunnlag for indikatoren. Manglende scorer teller ikke som null."),
          plotOutput("flow_plot", height = 280),
          h4("Scorefordeling"), plotOutput("scores_plot", height = 350),
          h4("Forventet treff mot beste ikke-treff"), plotOutput("scatter_plot", height = 430),
          tags$p("Weak: stiplet linje. Match: heltrukken linje. Saker uten tilgjengelig SP vises ikke som null i plottet.")
        ),
        tabPanel("Strong analysis",
          textOutput("strong_candidate"),
          tags$p("Rangering: lavest TotalErrors, deretter lavest FP_FN_Difference. Begge feilindikatorer kan forekomme i samme sak. ExpectedFound FALSE inngår ikke som en syntetisk FN."),
          plotOutput("strong_plot", height = 340),
          actionButton("apply_strong", "Bruk valgt Strong-kandidat"),
          downloadButton("download_strong", "Last ned komplett tabell"),
          DTOutput("strong_table")
        ),
        tabPanel("Match / Weak analysis",
          fluidRow(column(4, numericInput("window_width", "Vindusbredde", value = min(150, diff(score_range)), min = 0, step = 1)),
            column(4, numericInput("window_step", "Steg", value = 10, min = 1, step = 1))),
          tags$p("Utforsk caseflyt for faste Weak/Match-vinduer. Strong endrer ikke flyten i denne regelmodellen. Ingen rad velges automatisk som riktig terskel."),
          actionButton("apply_window", "Bruk valgt Weak/Match-vindu"),
          downloadButton("download_windows", "Last ned komplett tabell"),
          DTOutput("window_table")
        ),
        tabPanel("Cases",
          fluidRow(
            column(4, selectInput("case_flows", "Caseflyt", choices = flow_levels, selected = flow_levels, multiple = TRUE)),
            column(4, selectInput("case_errors", "Minst én valgt feilindikator", choices = c("ExpectedFound FALSE", "FN_Weak", "FP_Weak", "FN_Strong", "FP_Strong"), multiple = TRUE)),
            column(4, checkboxInput("boundary_only", "Bare nær terskler", FALSE),
              numericInput("boundary_distance", "Maksimal avstand", value = 10, min = 0, step = 1))
          ),
          tags$p("Avstandene er signerte: score minus terskel. Nær terskel betyr absolutt avstand innen valgt grense til minst én terskel."),
          downloadButton("download_cases", "Last ned filtrerte saker"),
          DTOutput("cases_table")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  # Read each source once per file change, not once per threshold change.
  results <- reactive({
    path <- if (is.null(input$result_file)) "data/results.csv" else input$result_file$datapath
    tryCatch(load_results(path), error = function(e) list(error = conditionMessage(e)))
  })
  config <- tryCatch(load_thresholds(), error = function(e) list(error = conditionMessage(e)))
  values <- reactiveVal(default_values)
  default_source <- reactiveVal("Generiske startverdier; ikke lastet fra konfigurasjon.")

  set_values <- function(x) {
    x <- setNames(as.numeric(x), c("weak", "strong", "match"))
    x <- setNames(pmax(score_range[1], pmin(score_range[2], round(x))), c("weak", "strong", "match"))
    if (enforce_order) x <- setNames(sort(x), names(x))
    if (identical(values(), x)) return(invisible(NULL))
    values(x)
    for (name in names(x)) {
      if (!identical(as.numeric(input[[name]]), as.numeric(x[[name]]))) {
        updateSliderInput(session, name, value = x[[name]])
      }
    }
  }
  reset_profile <- function() {
    x <- default_values
    message <- "Generiske startverdier; ikke lastet fra konfigurasjon."
    if (is.data.frame(config)) {
      row <- config[config$ThresholdName == input$profile, ]
      if (nrow(row)) {
        configured <- as.numeric(unlist(row[1, c("Weak", "Strong", "Match")]))
        if (all(configured >= score_range[1] & configured <= score_range[2])) {
          x <- configured
          message <- "Startverdier lastet fra data/thresholds.csv."
        } else message <- "Konfigurasjonen er utenfor scoreområdet; generiske startverdier brukes."
      }
    }
    set_values(x)
    default_source(message)
  }
  observeEvent(results(), {
    data <- results()
    if (is.data.frame(data)) {
      profiles <- sort(unique(data$ThresholdProfileName))
      updateSelectInput(session, "profile", choices = profiles, selected = profiles[1])
    } else updateSelectInput(session, "profile", choices = character())
  })
  observeEvent(input$profile, reset_profile())
  observeEvent(input$reset, reset_profile())
  # A single atomic threshold state prevents inconsistent calculations during UI updates.
  edit_value <- function(name, value) {
    req(value)
    x <- values()
    x[name] <- round(value)
    if (enforce_order) {
      if (name == "weak") { x["strong"] <- max(x["strong"], x["weak"]); x["match"] <- max(x["match"], x["strong"]) }
      if (name == "strong") { x["weak"] <- min(x["weak"], x["strong"]); x["match"] <- max(x["match"], x["strong"]) }
      if (name == "match") { x["strong"] <- min(x["strong"], x["match"]); x["weak"] <- min(x["weak"], x["strong"]) }
    }
    set_values(x)
  }
  observeEvent(list(input$weak, input$strong, input$match), {
    req(!is.null(input$weak), !is.null(input$strong), !is.null(input$match), cancelOutput = TRUE)
    incoming <- c(weak = input$weak, strong = input$strong, match = input$match)
    changed <- which(incoming != values())
    if (length(changed) == 1) {
      name <- names(incoming)[changed]
      edit_value(name, incoming[[name]])
    } else if (length(changed) > 1) set_values(incoming)
  }, ignoreInit = TRUE)
  output$default_source <- renderText(default_source())
  output$validation_messages <- renderUI({
    data <- results()
    if (!is.data.frame(data)) return(tags$p(class = "notice", data$error))
    issues <- attr(data, "validation_issues")
    if (is.list(config) && !is.data.frame(config)) issues <- c(issues, config$error)
    outside <- sum(data$ExpectedScore < score_range[1] | data$ExpectedScore > score_range[2], na.rm = TRUE) +
      sum(data$BestNonMatchScore < score_range[1] | data$BestNonMatchScore > score_range[2], na.rm = TRUE)
    if (outside) issues <- c(issues, paste(outside, "scores outside configured range; retained unchanged."))
    if (!length(issues)) return(tags$p("Datavalidering: ingen merknader."))
    tags$div(class = "notice", tags$strong("Valideringsmerknader"), tags$ul(lapply(issues, tags$li)))
  })

  profile_data <- reactive({
    data <- results()
    validate(need(is.data.frame(data), if (!is.data.frame(data) && is.list(data)) data$error else "Invalid input"))
    req(input$profile)
    selected <- filter_profile(data, input$profile)
    validate(need(nrow(selected) > 0, "Ingen saker i valgt profil."))
    selected
  })
  simulation <- reactive({
    x <- values()
    simulate_flow(profile_data(), x["weak"], x["strong"], x["match"], enforce_order)
  })
  strong_candidates <- bindCache(reactive(calculate_strong_table(profile_data(), score_range)),
    input$profile, input$result_file$datapath, score_range)
  window_candidates <- bindCache(reactive({
    req(!is.null(input$window_width), !is.null(input$window_step), cancelOutput = TRUE)
    validate(need(input$window_width >= 0 && input$window_width <= diff(score_range), "Vindusbredde utenfor scoreområdet."),
      need(input$window_step >= 1, "Steg må være minst 1."),
      need(input$window_width == floor(input$window_width) && input$window_step == floor(input$window_step), "Bruk heltall."))
    calculate_match_weak_table(profile_data(), score_range, input$window_width, input$window_step)
  }), input$profile, input$result_file$datapath, input$window_width, input$window_step, score_range)

  output$summary <- renderUI({
    summary <- flow_summary(simulation())
    card <- function(label, value, detail = NULL) tags$div(class = "summary-item", label, tags$strong(value), tags$small(detail))
    tags$div(class = "summary-grid", card("Antall saker", nrow(simulation())),
      lapply(seq_len(nrow(summary)), function(i) card(summary$Flow[i], summary$Count[i], sprintf("%.1f %%", summary$Percent[i]))))
  })
  output$biometrics <- renderDT({
    x <- values()
    datatable(calculate_biometric_metrics(profile_data(), x["weak"], x["strong"]),
      rownames = FALSE, options = list(dom = "t", paging = FALSE))
  })
  output$flow_plot <- renderPlot(plot_flow(simulation()))
  output$scores_plot <- renderPlot({ x <- values(); plot_scores(profile_data(), x["weak"], x["strong"], x["match"]) })
  output$scatter_plot <- renderPlot({ x <- values(); plot_scatter(simulation(), x["weak"], x["match"]) })
  output$strong_candidate <- renderText({
    table <- strong_candidates()
    sprintf("Best calculated candidate: Strong %d, TotalErrors %d, FP_FN_Difference %d. ExpectedFound FALSE: %d. Tilgjengelige genuine scorer: %d; ikke-treff-scorer: %d.",
      table$Strong[1], table$TotalErrors[1], table$FP_FN_Difference[1],
      sum(!profile_data()$ExpectedFound), sum(!is.na(genuine_scores(profile_data()))), sum(!is.na(profile_data()$BestNonMatchScore)))
  })
  output$strong_plot <- renderPlot(plot_strong(strong_candidates(), values()["strong"]))
  output$strong_table <- renderDT(datatable(strong_candidates(), rownames = FALSE,
    selection = "single", options = list(pageLength = 15, order = list(list(0, "asc")), scrollX = TRUE)))
  observeEvent(input$apply_strong, {
    selected <- input$strong_table_rows_selected
    if (!length(selected)) { showNotification("Velg en kandidat i tabellen."); return() }
    edit_value("strong", strong_candidates()$Strong[selected[1]])
  })
  output$window_table <- renderDT(datatable(window_candidates(), rownames = FALSE, selection = "single",
    options = list(pageLength = 15, scrollX = TRUE)))
  observeEvent(input$apply_window, {
    selected <- input$window_table_rows_selected
    if (!length(selected)) { showNotification("Velg et vindu i tabellen."); return() }
    row <- window_candidates()[selected[1], ]
    set_values(c(row$Weak, max(row$Weak, min(values()["strong"], row$Match)), row$Match))
  })
  filtered_cases <- reactive({
    data <- simulation()
    data <- data[data$Flow %in% input$case_flows, , drop = FALSE]
    if (length(input$case_errors)) {
      keep <- rep(FALSE, nrow(data))
      for (flag in input$case_errors) {
        indicator <- if (flag == "ExpectedFound FALSE") !data$ExpectedFound else data[[flag]]
        keep <- keep | (!is.na(indicator) & indicator)
      }
      data <- data[keep, , drop = FALSE]
    }
    if (isTRUE(input$boundary_only)) {
      req(!is.null(input$boundary_distance))
      validate(need(input$boundary_distance >= 0, "Avstand må være >= 0."))
      distances <- data[, grep("^Distance", names(data)), drop = FALSE]
      near <- rowSums(abs(as.matrix(distances)) <= input$boundary_distance, na.rm = TRUE) > 0
      data <- data[near, , drop = FALSE]
    }
    data
  })
  output$cases_table <- renderDT(datatable(filtered_cases(), filter = "top", rownames = FALSE,
    selection = "none", options = list(pageLength = 25, scrollX = TRUE)))
  output$download_strong <- downloadHandler(filename = function() "strong_analysis.csv",
    content = function(file) readr::write_delim(strong_candidates(), file, delim = ";", na = ""))
  output$download_windows <- downloadHandler(filename = function() "match_weak_analysis.csv",
    content = function(file) readr::write_delim(window_candidates(), file, delim = ";", na = ""))
  output$download_cases <- downloadHandler(filename = function() "filtered_cases.csv", content = function(file) {
    data <- filtered_cases()
    rows <- input$cases_table_rows_all
    if (!is.null(rows)) data <- data[rows, , drop = FALSE]
    readr::write_delim(data, file, delim = ";", na = "")
  })
}

shinyApp(ui, server)
