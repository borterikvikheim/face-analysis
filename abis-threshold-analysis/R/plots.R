flow_colors <- c(Archive = "#287d5a", Verification = "#3478b8", IdentityClaim = "#b94747", Undetermined = "#777777")

plot_flow <- function(data) {
  summary <- flow_summary(data)
  ggplot2::ggplot(summary, ggplot2::aes(x = factor(Flow, levels = rev(flow_levels)), y = Count, fill = Flow)) +
    ggplot2::geom_col(width = .65) + ggplot2::geom_text(ggplot2::aes(label = sprintf("%s (%.1f%%)", Count, Percent)), hjust = -.1) +
    ggplot2::coord_flip(clip = "off") + ggplot2::scale_fill_manual(values = flow_colors) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, .3))) +
    ggplot2::labs(x = NULL, y = "Antall saker") + ggplot2::theme_minimal() + ggplot2::theme(legend.position = "none")
}

plot_scores <- function(data, weak, strong, match) {
  values <- data.frame(ExpectedScore = genuine_scores(data), BestNonMatchScore = data$BestNonMatchScore)
  values <- tidyr::pivot_longer(values, everything(), names_to = "Score", values_to = "Value")
  lines <- data.frame(Band = factor(c("Weak", "Strong", "Match"), levels = c("Weak", "Strong", "Match")), Value = c(weak, strong, match))
  ggplot2::ggplot(values, ggplot2::aes(Value, fill = Score)) +
    ggplot2::geom_histogram(bins = 50, position = "identity", alpha = .5, na.rm = TRUE) +
    ggplot2::geom_vline(data = lines, ggplot2::aes(xintercept = Value, linetype = Band), linewidth = .8) +
    ggplot2::scale_fill_manual(values = c(ExpectedScore = "#287d5a", BestNonMatchScore = "#b94747")) +
    ggplot2::labs(x = "Score", y = "Antall", fill = NULL, linetype = "Terskel") + ggplot2::theme_minimal()
}

plot_scatter <- function(data, weak, match) {
  data$SP <- genuine_scores(data)
  ggplot2::ggplot(data, ggplot2::aes(BestNonMatchScore, SP, color = Flow)) +
    ggplot2::geom_point(alpha = .25, size = 1, na.rm = TRUE) +
    ggplot2::geom_vline(xintercept = c(weak, match), linetype = c("dashed", "solid")) +
    ggplot2::geom_hline(yintercept = c(weak, match), linetype = c("dashed", "solid")) +
    ggplot2::scale_color_manual(values = flow_colors, drop = FALSE) +
    ggplot2::labs(x = "Beste ikke-treff (SN)", y = "Forventet treff (SP)") + ggplot2::theme_minimal()
}

plot_strong <- function(table, strong) {
  values <- tidyr::pivot_longer(table, c(FalsePositive, FalseNegative, TotalErrors), names_to = "Metric", values_to = "Count")
  ggplot2::ggplot(values, ggplot2::aes(Strong, Count, color = Metric)) +
    ggplot2::geom_line() + ggplot2::geom_vline(xintercept = strong, linetype = "dashed") +
    ggplot2::scale_color_manual(values = c(FalsePositive = "#b94747", FalseNegative = "#3478b8", TotalErrors = "#287d5a")) +
    ggplot2::labs(x = "Strong", y = "Antall feilindikatorer", color = NULL) + ggplot2::theme_minimal()
}
