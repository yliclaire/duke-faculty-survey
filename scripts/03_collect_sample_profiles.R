# Collect detailed variables only for faculty selected in 02_draw_sample.R.
# Cache each profile locally and pause between requests.

library(readr)

sample_path <- "data/raw/sampled_faculty.csv"
if (!file.exists(sample_path)) {
  stop("Run scripts/02_draw_sample.R first.")
}

sampled_faculty <- read_csv(sample_path, show_col_types = FALSE)

message(
  "Ready to collect ", nrow(sampled_faculty),
  " sampled profiles. Add selectors after inspecting a few profiles manually."
)

