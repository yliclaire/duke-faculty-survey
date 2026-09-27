library(dplyr)
library(readr)

source("R/config.R")

frame_path <- "data/raw/faculty_sampling_frame.csv"
if (!file.exists(frame_path)) {
  stop("Create data/raw/faculty_sampling_frame.csv before drawing the sample.")
}

frame <- read_csv(frame_path, show_col_types = FALSE)

required_columns <- c("faculty_id", "name", "profile_url", "department")
missing_columns <- setdiff(required_columns, names(frame))
if (length(missing_columns) > 0) {
  stop("Missing columns: ", paste(missing_columns, collapse = ", "))
}

set.seed(random_seed)

# Starting design: proportional stratified simple random sampling by department.
# Review small departments before finalizing the allocation and inclusion weights.
sampled_faculty <- frame |>
  group_by(department) |>
  slice_sample(prop = min(1, target_sample_size / nrow(frame))) |>
  ungroup()

write_csv(sampled_faculty, "data/raw/sampled_faculty.csv")

