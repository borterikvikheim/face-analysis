file_arg <- grep("^--file=", commandArgs(), value = TRUE)
if (length(file_arg) != 1) stop("Run this file with Rscript.")
bundle <- dirname(normalizePath(sub("^--file=", "", file_arg), winslash = "/"))
library_path <- file.path(bundle, "library")
.libPaths(c(library_path, .Library), include.site = FALSE)
expected_version <- readLines(file.path(bundle, "R-version.txt"), warn = FALSE)[1]
if (as.character(getRversion()) != expected_version) {
  stop("Use the included R runtime or installer (R ", expected_version, ").")
}
for (package in c("shiny", "dplyr", "readr", "tidyr", "ggplot2", "DT")) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Missing bundled package: ", package)
}
setwd(file.path(bundle, "app"))
options(shiny.maxRequestSize = 100 * 1024^2)
smoke <- "--smoke-test" %in% commandArgs(trailingOnly = TRUE)
cat("Starting ABIS locally. Keep this window open; press Ctrl+C to stop.\n")
shiny::runApp(host = "127.0.0.1", port = if (smoke) 3876L else NULL,
  launch.browser = !smoke)
