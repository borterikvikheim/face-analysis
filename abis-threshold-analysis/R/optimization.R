calculate_strong_table <- function(data, score_range = c(0, 1000)) {
  thresholds <- seq.int(score_range[1], score_range[2])
  sp <- sort(genuine_scores(data), na.last = NA)
  sn <- sort(data$BestNonMatchScore, na.last = NA)
  # left.open counts strictly below T, retaining equality in FP >= T.
  fp <- length(sn) - findInterval(thresholds, sn, left.open = TRUE)
  fn <- findInterval(thresholds, sp, left.open = TRUE)
  table <- data.frame(Strong = thresholds, FalsePositive = fp, FalseNegative = fn,
    TotalErrors = fp + fn, FP_FN_Difference = abs(fp - fn))
  table <- table[order(table$TotalErrors, table$FP_FN_Difference, table$Strong), ]
  data.frame(Rank = seq_len(nrow(table)), table, row.names = NULL)
}

calculate_match_weak_table <- function(data, score_range = c(0, 1000), width = 150, step = 10) {
  if (width < 0 || step < 1 || width != floor(width) || step != floor(step)) {
    stop("Window width must be a nonnegative integer and step a positive integer.")
  }
  if (width > diff(score_range)) return(data.frame())
  weak_values <- seq.int(score_range[1], score_range[2] - width, by = step)
  sp <- genuine_scores(data)
  sn <- data$BestNonMatchScore
  rows <- lapply(weak_values, function(weak) {
    match <- weak + width
    summary <- flow_summary(data.frame(Flow = classify_flow(sp, sn, weak, match)))
    row <- data.frame(Weak = weak, Match = match)
    for (flow in flow_levels) {
      item <- summary[summary$Flow == flow, ]
      row[[paste0(flow, "Count")]] <- item$Count
      row[[paste0(flow, "Percent")]] <- item$Percent
    }
    row
  })
  dplyr::bind_rows(rows)
}
