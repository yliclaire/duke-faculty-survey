library(dplyr)
library(readr)
library(tibble)
library(tidyverse)

faculty <- read_csv(
  "data/processed/faculty_profiles.csv",
  show_col_types = FALSE
)

manual_review <- faculty |>
  filter(gender_code %in% c("unknown", "review_conflict")) |>
  select(
    faculty_id,
    name,
    profile_url,
    gender_code,
    gender_evidence,
    overview_text
  )

manual_codes <- c(
  0,1,1,1,1,0,1,1,1,
  0,0,1,1,1,0,1,0,0,
  1,0,1,1,0,1,0,0,0
)

stopifnot(length(manual_codes) == nrow(manual_review))

manual_gender <- manual_review |>
  select(
    faculty_id,
    name,
    profile_url
  ) |>
  mutate(
    manual_woman = manual_codes
  )

faculty_final <- faculty |>
  left_join(
    manual_gender |>
      select(faculty_id, manual_woman),
    by = "faculty_id"
  ) |>
  mutate(
    woman_final = case_when(
      faculty_id %in% c("wah", "jenny.tung") ~ 1L,
      !is.na(manual_woman) ~ manual_woman,
      TRUE ~ woman
    ),
    gender_method = case_when(
      faculty_id %in% c("wah", "jenny.tung") ~ "manual_review",
      !is.na(manual_woman) ~ "manual_review",
      she_pronoun_count > 0 | he_pronoun_count > 0 ~ "profile_pronouns",
      TRUE ~ "first_name_ssa_95pct"
    )
  )

faculty_final |>
  count(woman_final)

stopifnot(nrow(faculty_final) == 230)
stopifnot(sum(is.na(faculty_final$woman_final)) == 0)

write_csv(
  faculty_final,
  "data/processed/faculty_final.csv"
)

