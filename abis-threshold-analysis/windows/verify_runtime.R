file_arg <- grep("^--file=", commandArgs(), value = TRUE)
bundle <- dirname(normalizePath(sub("^--file=", "", file_arg), winslash = "/"))
library_path <- normalizePath(file.path(bundle, "library"), winslash = "/")
.libPaths(c(library_path, .Library), include.site = FALSE)
stopifnot(.Platform$OS.type == "windows", R.version$arch == "x86_64",
  as.character(getRversion()) == readLines(file.path(bundle, "R-version.txt"), warn = FALSE)[1])
installed <- installed.packages(lib.loc = library_path)
for (package in installed[, "Package"]) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Cannot load bundled package: ", package)
  loaded_path <- normalizePath(find.package(package), winslash = "/")
  if (!startsWith(tolower(loaded_path), paste0(tolower(library_path), "/"))) {
    stop("Package loaded outside bundle: ", package)
  }
}
setwd(file.path(bundle, "app"))
source("R/load_data.R")
data <- load_results("data/results.csv")
cat("R:", as.character(getRversion()), "x64\n")
cat("Bundled packages:", nrow(installed), "\n")
cat("Cases:", nrow(data), "Profiles:", length(unique(data$ThresholdProfileName)), "\n")
cat("Runtime checks passed. No downloads or installations were performed.\n")
