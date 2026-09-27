library(dplyr)
library(readr)

source("R/config.R")

frame_path <- "data/raw/faculty_sampling_frame.csv"
if (!file.exists(frame_path)) {
  stop("Create data/raw/faculty_sampling_frame.csv before drawing the sample.")
}

frame <- read_csv(frame_path, show_col_types = FALSE)

required_columns <- c(
  "faculty_id", "name", "profile_url", "sampling_department"
)
missing_columns <- setdiff(required_columns, names(frame))
if (length(missing_columns) > 0) {
  stop("Missing columns: ", paste(missing_columns, collapse = ", "))
}

set.seed(random_seed)

# Proportionate stratified simple random sampling without replacement.
# Largest-remainder allocation keeps the total at round(20% of the frame).
allocation <- frame |>
  count(sampling_department, name = "N_h") |>
  mutate(
    quota = sampling_fraction * N_h,
    n_h = floor(quota),
    remainder = quota - n_h
  ) |>
  arrange(desc(remainder), sampling_department)

remaining <- round(sampling_fraction * nrow(frame)) - sum(allocation$n_h)
allocation <- allocation |>
  mutate(n_h = n_h + as.integer(row_number() <= remaining)) |>
  select(sampling_department, N_h, n_h)

sampled_faculty <- frame |>
  left_join(allocation, by = "sampling_department") |>
  group_by(sampling_department) |>
  group_modify(~ slice_sample(.x, n = first(.x$n_h))) |>
  ungroup() |>
  mutate(
    selection_probability = n_h / N_h,
    survey_weight = 1 / selection_probability
  )

write_csv(sampled_faculty, "data/raw/sampled_faculty.csv")
write_csv(allocation, "data/raw/sample_allocation.csv")
