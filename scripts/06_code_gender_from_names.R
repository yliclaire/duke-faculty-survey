library(dplyr)
library(gender)
library(readr)
library(stringr)

faculty_path <- "data/processed/faculty_profiles.csv"
if (!file.exists(faculty_path)) {
  stop("Run scripts/05_code_gender_from_pronouns.R first.")
}

faculty <- read_csv(faculty_path, show_col_types = FALSE)
required_columns <- c("faculty_id", "name", "gender_code")
missing_columns <- setdiff(required_columns, names(faculty))
if (length(missing_columns) > 0) {
  stop("Missing columns: ", paste(missing_columns, collapse = ", "))
}

# Extract the first displayed name. Initials, blank names, and names absent from
# the historical data remain unresolved.
faculty <- faculty |>
  mutate(
    first_name = str_extract(name, "^[[:alpha:]À-ÖØ-öø-ÿ'’-]+"),
    first_name = str_replace_all(first_name, "[’'].*$", "")
  )

unresolved_names <- faculty |>
  filter(gender_code == "unknown", !is.na(first_name)) |>
  pull(first_name) |>
  unique()

# The SSA method returns historical binary proportions. A strict threshold is
# used so ambiguous and gender-neutral names remain unknown.
name_predictions <- gender(
  unresolved_names,
  years = c(1930, 2005),
  method = "ssa"
) |>
  transmute(
    first_name = name,
    name_proportion_male = proportion_male,
    name_proportion_female = proportion_female,
    gender_code_name = case_when(
      proportion_female >= 0.95 ~ "woman",
      proportion_male >= 0.95 ~ "man",
      TRUE ~ NA_character_
    )
  )

faculty_coded <- faculty |>
  select(
    -any_of(c(
      "name_proportion_male", "name_proportion_female", "gender_code_name",
      "gender_method", "name_gender_evidence"
    ))
  ) |>
  left_join(name_predictions, by = "first_name") |>
  mutate(
    gender_method = case_when(
      gender_code %in% c("woman", "man") ~ "profile_pronouns",
      gender_code == "unknown" & !is.na(gender_code_name) ~ "first_name_ssa_95pct",
      TRUE ~ "unresolved"
    ),
    name_gender_evidence = case_when(
      gender_method == "first_name_ssa_95pct" ~ paste0(
        "first_name=", first_name,
        "; proportion_female=", round(name_proportion_female, 4),
        "; proportion_male=", round(name_proportion_male, 4)
      ),
      TRUE ~ NA_character_
    ),
    gender_code = case_when(
      gender_code == "unknown" & !is.na(gender_code_name) ~ gender_code_name,
      TRUE ~ gender_code
    ),
    woman = case_when(
      gender_code == "woman" ~ 1L,
      gender_code == "man" ~ 0L,
      TRUE ~ NA_integer_
    ),
    sex_review = case_when(
      gender_method == "profile_pronouns" ~ "auto_pronoun_needs_audit",
      gender_method == "first_name_ssa_95pct" ~ "auto_name_needs_audit",
      TRUE ~ "manual_review_required"
    )
  )

write_csv(faculty_coded, faculty_path)

faculty_coded |>
  count(gender_code, gender_method, sex_review, name = "profiles") |>
  arrange(desc(profiles)) |>
  print(n = Inf)
