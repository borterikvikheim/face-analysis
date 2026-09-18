# Run from the project directory: Rscript tests/run_tests.R
for (file in c("load_data", "metrics", "flow", "optimization", "plots")) source(file.path("R", paste0(file, ".R")))
check <- function(condition, label) {
  if (!isTRUE(condition)) stop("FAILED: ", label)
  cat("PASS:", label, "\n")
}
throws <- function(expression) inherits(tryCatch(force(expression), error = identity), "error")
fixture <- function(sp, sn, found = !is.na(sp)) {
  data.frame(RowId = as.character(seq_along(sp)), ThresholdProfileName = "Test",
    ExpectedFound = found, ExpectedRank = ifelse(found, 1, NA), ExpectedScore = sp,
    BestNonMatchRank = 2, BestNonMatchScore = sn, ScoreDrop = sp - sn, CandidateCount = 15)
}
data <- fixture(c(901, 599, 901, 599, 750, NA, 600, 750, 900),
  c(599, 599, 901, 901, 700, 599, 600, 750, 900))
sim <- simulate_flow(data, 600, 750, 900)
check(identical(as.character(sim$Flow), c("Archive", "IdentityClaim", "IdentityClaim", "IdentityClaim",
  "Verification", "Undetermined", "IdentityClaim", "Verification", "IdentityClaim")), "flow rules and exact Weak/Strong/Match")
check(as.character(classify_flow(900, 600, 600, 900)) == "Archive", "Archive inclusive boundaries")
check(as.character(classify_flow(600, 900, 600, 900)) == "IdentityClaim", "IdentityClaim inclusive mixed boundaries")
check(as.character(classify_flow(600, 600, 600, 600)) == "Archive", "Archive precedence when Weak equals Match")
check(as.character(classify_flow(NA, 700, 600, 900)) == "Verification", "partial unknown but determinable Verification")
check(as.character(classify_flow(750, NA, 600, 900)) == "Verification", "intermediate SP determinable despite missing SN")
check(as.character(classify_flow(NA, 950, 600, 900)) == "Undetermined", "outside cannot invent SP")
check(throws(simulate_flow(data, 800, 750, 900)), "threshold order enforced")
metrics_data <- fixture(c(599, 600, 749, 750, NA), c(749, 750, 751, NA, 600))
metrics <- calculate_biometric_metrics(metrics_data, 600, 750)
check(identical(metrics$Count, c(1L, 1L, 4L, 3L, 2L)), "FN Weak / FN Strong / FP Strong equality and NA")
check(all(metrics$Available == c(5, 4, 4, 4, 4)), "error denominators exclude unavailable scores")
anomalous <- fixture(800, 500, FALSE)
check(is.na(simulate_flow(anomalous, 600, 750, 900)$FN_Strong), "not-found supplied score excluded from genuine metrics")
strong <- calculate_strong_table(metrics_data, c(590, 800))
brute <- vapply(strong$Strong, function(t) sum(metrics_data$BestNonMatchScore >= t, na.rm = TRUE), integer(1))
check(all(strong$FalsePositive == brute), "sorted-score FP agrees with direct counts")
brute <- vapply(strong$Strong, function(t) sum(genuine_scores(metrics_data) < t, na.rm = TRUE), integer(1))
check(all(strong$FalseNegative == brute), "sorted-score FN agrees with direct counts")
check(all(order(strong$TotalErrors, strong$FP_FN_Difference, strong$Strong) == seq_len(nrow(strong))), "Strong ranking and deterministic ties")
check(nrow(calculate_strong_table(fixture(NA_real_, NA_real_, FALSE))) == 1001, "all-NA Strong data supported")
windows <- calculate_match_weak_table(data)
check(nrow(windows) == 86 && windows$Weak[1] == 0 && tail(windows$Match, 1) == 1000 &&
  all(windows$Match - windows$Weak == 150), "window generation")
for (i in seq_len(nrow(windows))) {
  direct <- flow_summary(simulate_flow(data, windows$Weak[i], windows$Weak[i], windows$Match[i]))
  check_counts <- as.numeric(windows[i, paste0(flow_levels, "Count")])
  stopifnot(all(check_counts == direct$Count), sum(check_counts) == nrow(data))
}
check(TRUE, "window counts agree with simulator and partition every case")
check(nrow(calculate_match_weak_table(data, width = 1001)) == 0, "oversized window returns no scenarios")
check(throws(calculate_match_weak_table(data, step = 0)), "invalid window step rejected")
check(sim$DistanceExpectedToWeak[7] == 0 && is.na(sim$DistanceExpectedToMatch[6]), "boundary distances preserve NA")

path <- tempfile(fileext = ".csv")
readr::write_delim(metrics_data, path, delim = ";", na = "")
loaded <- load_results(path)
check(is.na(loaded$ExpectedScore[5]) && !loaded$ExpectedFound[5] && is.character(loaded$RowId), "loader preserves RowId and missing score")
bad <- metrics_data; bad$ExpectedFound <- "unknown"
readr::write_delim(bad, path, delim = ";")
check(throws(load_results(path)), "invalid ExpectedFound rejected")
bad <- metrics_data; bad$ExpectedScore <- "not numeric"
readr::write_delim(bad, path, delim = ";")
check(throws(load_results(path)), "invalid score rejected")
readr::write_delim(metrics_data[, -1], path, delim = ";")
check(throws(load_results(path)), "missing required column rejected")
readr::write_delim(anomalous, path, delim = ";")
check(length(attr(load_results(path), "validation_issues")) > 0, "suspicious supplied score reported")
unlink(path)
cat("All business-logic tests passed.\n")
