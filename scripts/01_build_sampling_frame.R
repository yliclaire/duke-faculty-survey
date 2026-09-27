# Build a frame containing only information needed to draw the sample.
# Add code here after confirming the site's pagination and HTML structure.

source("R/config.R")

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)

message("Sampling-frame URL: ", search_url)
message("Do not collect detailed profile variables in this script.")

