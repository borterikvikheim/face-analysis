calculate_biometric_metrics <- function(data, weak, strong) {
  sp <- genuine_scores(data)
  sn <- data$BestNonMatchScore
  data.frame(Indicator = c("ExpectedFound FALSE", "FN @ Weak", "FP @ Weak", "FN @ Strong", "FP @ Strong"),
    Count = c(sum(!data$ExpectedFound), sum(sp < weak, na.rm = TRUE),
      sum(sn >= weak, na.rm = TRUE), sum(sp < strong, na.rm = TRUE), sum(sn >= strong, na.rm = TRUE)),
    Available = c(nrow(data), sum(!is.na(sp)), sum(!is.na(sn)), sum(!is.na(sp)), sum(!is.na(sn))))
}

calculate_boundary_cases <- function(data, weak, strong, match) {
  for (band in c("Weak", "Strong", "Match")) {
    threshold <- switch(band, Weak = weak, Strong = strong, Match = match)
    data[[paste0("DistanceExpectedTo", band)]] <- genuine_scores(data) - threshold
    data[[paste0("DistanceNonMatchTo", band)]] <- data$BestNonMatchScore - threshold
  }
  data
}
