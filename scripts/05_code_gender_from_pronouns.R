library(dplyr)
library(purrr)
library(readr)
library(rvest)
library(stringr)
library(tibble)

faculty_path <- "data/processed/faculty_profiles.csv"
if (!file.exists(faculty_path)) {
  stop("Run scripts/03_collect_sample_profiles.R first.")
}

faculty <- read_csv(faculty_path, show_col_types = FALSE)

she_pattern <- "\\b(she|her|hers|herself)\\b"
he_pattern <- "\\b(he|him|his|himself)\\b"
they_pattern <- "\\b(they|them|their|theirs|themself|themselves)\\b"
all_pronoun_pattern <- paste(she_pattern, he_pattern, they_pattern, sep = "|")

scan_profile_pronouns <- function(faculty_id) {
  path <- file.path("cache/profiles", paste0(faculty_id, ".html"))
  if (!file.exists(path)) {
    return(tibble(
      faculty_id = faculty_id,
      she_pronoun_count = NA_integer_,
      he_pronoun_count = NA_integer_,
      they_pronoun_count = NA_integer_,
      gender_code = "unknown",
      gender_evidence = NA_character_
    ))
  }

  doc <- read_html(path)
  main_node <- html_element(doc, "#main-content")
  main_text <- if (inherits(main_node, "xml_missing")) {
    ""
  } else {
    main_node |> html_text2() |> str_squish()
  }
  lower_text <- str_to_lower(main_text)

  she_count <- str_count(lower_text, she_pattern)
  he_count <- str_count(lower_text, he_pattern)
  they_count <- str_count(lower_text, they_pattern)

  gender_code <- case_when(
    she_count > 0 && he_count == 0 ~ "woman",
    he_count > 0 && she_count == 0 ~ "man",
    she_count > 0 && he_count > 0 ~ "review_conflict",
    TRUE ~ "unknown"
  )

  sentences <- str_split(main_text, "(?<=[.!?])\\s+")[[1]]
  evidence <- sentences[
    str_detect(str_to_lower(sentences), all_pronoun_pattern)
  ] |>
    head(3) |>
    paste(collapse = " || ")
  if (!nzchar(evidence)) evidence <- NA_character_

  tibble(
    faculty_id = faculty_id,
    she_pronoun_count = she_count,
    he_pronoun_count = he_count,
    they_pronoun_count = they_count,
    gender_code = gender_code,
    gender_evidence = evidence
  )
}

pronoun_codes <- map_dfr(faculty$faculty_id, scan_profile_pronouns)

faculty_coded <- faculty |>
  select(
    -any_of(c(
      "gender_code", "gender_evidence", "she_pronoun_count",
      "he_pronoun_count", "they_pronoun_count"
    ))
  ) |>
  left_join(pronoun_codes, by = "faculty_id") |>
  mutate(
    woman = case_when(
      gender_code == "woman" ~ 1L,
      gender_code == "man" ~ 0L,
      TRUE ~ NA_integer_
    ),
    sex_evidence = gender_evidence,
    sex_review = case_when(
      gender_code %in% c("woman", "man") ~ "auto_pronoun_needs_audit",
      TRUE ~ "manual_review_required"
    )
  )

write_csv(faculty_coded, faculty_path)

faculty_coded |>
  count(gender_code, sex_review, name = "profiles") |>
  arrange(desc(profiles)) |>
  print(n = Inf)
