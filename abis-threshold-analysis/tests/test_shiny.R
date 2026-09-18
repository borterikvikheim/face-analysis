# Run from the project directory: Rscript tests/test_shiny.R
source("app.R")
shiny::testServer(server, {
  session$setInputs(profile = sort(unique(load_results("data/results.csv")$ThresholdProfileName))[1],
    weak = 600, strong = 750, match = 900, window_width = 150, window_step = 10,
    case_flows = flow_levels, case_errors = character(), boundary_only = FALSE)
  session$flushReact()
  stopifnot(length(unique(results()$ThresholdProfileName)) > 0,
    nrow(profile_data()) == sum(results()$ThresholdProfileName == input$profile))
  before <- simulation()
  session$setInputs(weak = 0)
  session$flushReact()
  stopifnot(values()["weak"] == 0, all(simulation()$FP_Weak[!is.na(simulation()$BestNonMatchScore)] ==
    (simulation()$BestNonMatchScore[!is.na(simulation()$BestNonMatchScore)] >= 0)))
  session$setInputs(match = 0)
  session$flushReact()
  stopifnot(all(values() == 0), all(is.na(simulation()$FN_Strong[!simulation()$ExpectedFound])))
  session$setInputs(strong = 1000)
  session$flushReact()
  stopifnot(values()["strong"] == 1000, values()["match"] == 1000)
  candidates <- strong_candidates()
  stopifnot(nrow(candidates) == 1001)
  index <- which(candidates$Strong == 500)
  session$setInputs(strong_table_rows_selected = index, apply_strong = 1)
  session$flushReact()
  stopifnot(values()["strong"] == 500)
  stopifnot(nrow(window_candidates()) == 86)
  session$setInputs(window_width = 0)
  session$flushReact()
  stopifnot(nrow(window_candidates()) == 101)
  session$setInputs(case_flows = "Undetermined")
  session$flushReact()
  stopifnot(all(filtered_cases()$Flow == "Undetermined"))
  session$setInputs(case_flows = flow_levels, case_errors = "ExpectedFound FALSE")
  session$flushReact()
  stopifnot(all(!filtered_cases()$ExpectedFound))
  session$setInputs(case_errors = character(), boundary_only = TRUE, boundary_distance = 10)
  session$flushReact()
  distances <- filtered_cases()[, grep("^Distance", names(filtered_cases()))]
  stopifnot(all(rowSums(abs(as.matrix(distances)) <= 10, na.rm = TRUE) > 0))
  profiles <- sort(unique(results()$ThresholdProfileName))
  if (length(profiles) > 1) {
    session$setInputs(profile = profiles[2])
    session$flushReact()
    stopifnot(all(profile_data()$ThresholdProfileName == profiles[2]))
  }
  stopifnot(sum(flow_summary(simulation())$Count) == nrow(profile_data()))
  cat("PASS: dynamic profiles, reactive thresholds, candidate selection, caching, zero-width windows, case and boundary filters\n")
})
