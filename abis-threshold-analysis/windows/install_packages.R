library_path <- normalizePath(commandArgs(trailingOnly = TRUE)[1], winslash = "/", mustWork = TRUE)
.libPaths(c(library_path, .Library), include.site = FALSE)
if (.Platform$OS.type != "windows" || R.version$arch != "x86_64") stop("Windows x64 required.")
packages <- c("shiny", "dplyr", "readr", "tidyr", "ggplot2", "DT")
options(repos = c(CRAN = "https://cloud.r-project.org"), timeout = 600)
# Install only Windows binaries and required dependencies; never compile on the runner.
install.packages(packages, lib = library_path, type = "binary", dependencies = NA)
for (package in packages) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Package installation failed: ", package)
}
installed <- installed.packages(lib.loc = library_path)
write.csv(installed[, c("Package", "Version", "License"), drop = FALSE],
  file.path(dirname(library_path), "packages.csv"), row.names = FALSE)
