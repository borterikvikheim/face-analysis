required_columns <- c("RowId", "ThresholdProfileName", "ExpectedFound", "ExpectedRank",
  "ExpectedScore", "BestNonMatchRank", "BestNonMatchScore", "ScoreDrop", "CandidateCount")

load_results <- function(path) {
  data <- readr::read_delim(path, delim = ";", col_types = readr::cols(.default = "c"),
    na = c("", "NA"), trim_ws = TRUE, show_col_types = FALSE)
  if (nrow(readr::problems(data))) stop("CSV parsing errors: check field counts.")
  missing <- setdiff(required_columns, names(data))
  if (length(missing)) stop("Missing columns: ", paste(missing, collapse = ", "))
  data <- data[, required_columns]
  if (!nrow(data)) stop("The file contains no cases.")
  for (column in c("RowId", "ThresholdProfileName")) {
    if (any(is.na(data[[column]]) | data[[column]] == "")) stop(column, " is missing in some rows.")
  }
  logical_text <- tolower(data$ExpectedFound)
  if (any(is.na(logical_text) | !logical_text %in% c("true", "false", "1", "0"))) {
    stop("ExpectedFound must contain TRUE/FALSE or 1/0.")
  }
  data$ExpectedFound <- logical_text %in% c("true", "1")
  for (column in setdiff(required_columns, c("RowId", "ThresholdProfileName", "ExpectedFound"))) {
    value <- suppressWarnings(as.numeric(data[[column]]))
    if (any(!is.na(data[[column]]) & (is.na(value) | !is.finite(value)))) {
      stop(column, " contains invalid numeric values.")
    }
    data[[column]] <- value
  }
  issues <- character()
  flag <- function(condition, message) {
    n <- sum(condition, na.rm = TRUE)
    if (n) issues <<- c(issues, paste(n, message))
  }
  flag(duplicated(data[c("ThresholdProfileName", "RowId")]), "duplicate profile/RowId pairs; inspect source data.")
  flag(!data$ExpectedFound & !is.na(data$ExpectedScore), "not-found cases have ExpectedScore; excluded from genuine analysis and SP flow rules.")
  flag(data$ExpectedFound & is.na(data$ExpectedScore), "found cases have missing ExpectedScore.")
  flag(is.na(data$BestNonMatchScore), "cases have missing BestNonMatchScore.")
  flag(is.na(data$CandidateCount) | data$CandidateCount < 0 |
    data$CandidateCount != floor(data$CandidateCount), "cases have missing or invalid CandidateCount.")
  flag(data$ExpectedFound & (is.na(data$ExpectedRank) | data$ExpectedRank < 1 |
    data$ExpectedRank != floor(data$ExpectedRank) | data$ExpectedRank > data$CandidateCount),
    "found cases have missing or inconsistent rank.")
  attr(data, "validation_issues") <- issues
  data
}

load_thresholds <- function(path = "data/thresholds.csv") {
  if (!file.exists(path)) return(NULL)
  data <- readr::read_delim(path, delim = ";", show_col_types = FALSE,
    col_types = readr::cols(.default = "c"))
  if (!all(c("ThresholdName", "Weak", "Strong", "Match") %in% names(data))) {
    stop("Threshold configuration needs ThresholdName;Weak;Strong;Match.")
  }
  if (anyNA(data$ThresholdName) || anyDuplicated(data$ThresholdName)) stop("Invalid or duplicate threshold names.")
  for (column in c("Weak", "Strong", "Match")) {
    data[[column]] <- suppressWarnings(as.numeric(data[[column]]))
    if (anyNA(data[[column]]) || any(!is.finite(data[[column]]) |
      data[[column]] != floor(data[[column]]))) stop("Invalid threshold configuration.")
  }
  if (any(data$Weak > data$Strong | data$Strong > data$Match)) stop("Configured thresholds must be ordered.")
  data
}

filter_profile <- function(data, profile) data[data$ThresholdProfileName == profile, , drop = FALSE]

# Preserve original input scores; use NA for unavailable genuine scores in calculations.
genuine_scores <- function(data) ifelse(data$ExpectedFound, data$ExpectedScore, NA_real_)
