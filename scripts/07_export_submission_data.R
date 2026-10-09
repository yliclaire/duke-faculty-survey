library(dplyr)
library(readr)

source_path <- "faculty_final.csv"
audit_path <- "data/processed/faculty_final_full.csv"
submission_path <- "data/processed/faculty_final.csv"

if (!file.exists(source_path)) {
  stop(
    "Could not find ", source_path, ". ",
    "Place the complete faculty_final.csv in the project root first."
  )
}

faculty_full <- read_csv(source_path, show_col_types = FALSE)

required_columns <- c(
  "sampling_department",
  "faculty_id",
  "profile_url",
  "name",
  "N_h",
  "n_h",
  "selection_probability",
  "survey_weight",
  "woman_final",
  "gender_method",
  "has_phd",
  "phd_year",
  "phd_institution",
  "years_since_phd",
  "phd_from_duke",
  "has_ongoing_grant_2026",
  "profile_access_date",
  "scrape_status"
)

missing_columns <- setdiff(required_columns, names(faculty_full))
if (length(missing_columns) > 0) {
  stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
}

if (nrow(faculty_full) != 230) {
  stop("Expected 230 faculty rows; found ", nrow(faculty_full), ".")
}

if (anyDuplicated(faculty_full$faculty_id)) {
  stop("faculty_id must be unique.")
}

check_binary_complete <- function(data, variable) {
  values <- data[[variable]]
  if (anyNA(values) || any(!values %in% c(0, 1))) {
    stop(variable, " must contain only nonmissing 0/1 values.")
  }
}

check_binary_complete(faculty_full, "woman_final")
check_binary_complete(faculty_full, "has_phd")
check_binary_complete(faculty_full, "has_ongoing_grant_2026")

if (any(abs(
  faculty_full$selection_probability - faculty_full$n_h / faculty_full$N_h
) > 1e-10)) {
  stop("At least one selection probability does not equal n_h / N_h.")
}

if (any(abs(
  faculty_full$survey_weight - faculty_full$N_h / faculty_full$n_h
) > 1e-10)) {
  stop("At least one survey weight does not equal N_h / n_h.")
}

observed_allocation <- faculty_full |>
  count(sampling_department, n_h, name = "observed_n")

if (any(observed_allocation$observed_n != observed_allocation$n_h)) {
  stop("At least one department's observed sample size does not match n_h.")
}

faculty_submission <- faculty_full |>
  select(all_of(required_columns))

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

write_csv(faculty_full, audit_path)
write_csv(faculty_submission, submission_path)

message(
  "Saved the full 39-column audit file to ", audit_path, 
  " and the ", ncol(faculty_submission), "-column submission file to ",
  submission_path, "."
)
