flow_levels <- c("Archive", "Verification", "IdentityClaim", "Undetermined")

validate_threshold_values <- function(weak, strong, match, enforce_order = TRUE) {
  values <- c(weak, strong, match)
  if (length(values) != 3 || anyNA(values) || any(!is.finite(values)) ||
      any(values != floor(values))) stop("Thresholds must be finite integers.")
  if (enforce_order && (weak > strong || strong > match)) stop("Require Weak <= Strong <= Match.")
}

# Literal inclusive boundaries are centralized here. Archive wins overlapping rules.
classify_flow <- function(sp, sn, weak, match) {
  archive <- sp >= match & sn <= weak
  claim <- (sp <= weak & sn <= weak) | (sp >= match & sn >= match) |
    (sp <= weak & sn >= match)
  result <- rep("Undetermined", length(sp))
  result[which(!archive & !claim)] <- "Verification"
  result[which(claim & !is.na(archive))] <- "IdentityClaim"
  result[which(archive)] <- "Archive"
  factor(result, levels = flow_levels)
}

simulate_flow <- function(data, weak, strong, match, enforce_order = TRUE) {
  validate_threshold_values(weak, strong, match, enforce_order)
  sp <- genuine_scores(data)
  sn <- data$BestNonMatchScore
  data$Flow <- classify_flow(sp, sn, weak, match)
  data$FN_Weak <- sp < weak
  data$FP_Weak <- sn >= weak
  data$FN_Strong <- sp < strong
  data$FP_Strong <- sn >= strong
  calculate_boundary_cases(data, weak, strong, match)
}

flow_summary <- function(data) {
  counts <- as.integer(table(factor(data$Flow, levels = flow_levels)))
  data.frame(Flow = flow_levels, Count = counts,
    Percent = if (nrow(data)) 100 * counts / nrow(data) else 0)
}
