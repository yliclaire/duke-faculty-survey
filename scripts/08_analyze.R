library(dplyr)
library(readr)
library(stringr)
library(survey)

options(survey.lonely.psu = "adjust")  # safeguard for any stratum with n_h = 1

# 1. Load data and create Q4 variable

faculty <- read_csv(
  "data/processed/faculty_final.csv",
  show_col_types = FALSE
) |>
  mutate(
    phd_duke = case_when(
      has_phd != 1 ~ NA_real_,
      is.na(phd_institution) ~ NA_real_,
      str_detect(phd_institution, regex("Duke", ignore_case = TRUE)) ~ 1,
      TRUE ~ 0
    )
  )

# 2. Data checks 

nrow(faculty)                                      
faculty |> count(sampling_department, N_h)          
faculty |> count(has_phd)                           
faculty |> count(missing_grant = is.na(has_ongoing_grant_2026))
faculty |> filter(has_phd == 1) |> count(phd_duke)

# 3. Survey design 

faculty_design <- svydesign(
  ids = ~1,
  strata = ~sampling_department,
  weights = ~survey_weight,
  fpc = ~N_h,
  data = faculty
)

phd_design <- subset(faculty_design, has_phd == 1)

# 4. Estimates

# Question 1: Fraction of faculty who are women
q1 <- svymean(~woman_final, design = faculty_design)
q1
confint(q1)

# Question 2: Fraction with at least one grant ongoing in 2026
q2 <- svymean(~has_ongoing_grant_2026, design = faculty_design, na.rm = TRUE)
q2
confint(q2)

# Question 3: Average years since PhD, among PhD holders
q3 <- svymean(~years_since_phd, design = phd_design, na.rm = TRUE)
q3
confint(q3)

# Question 4: Fraction of PhD holders whose PhD is from Duke
# Logit interval keeps the CI between 0 and 1 for a small proportion.
q4 <- svyciprop(~phd_duke, design = phd_design, method = "logit", na.rm = TRUE)
q4
confint(q4)

# 5. Summary table

results <- tibble(
  question = c(
    "Q1: Fraction women",
    "Q2: Ongoing grant in 2026",
    "Q3: Mean years since PhD (PhD holders)",
    "Q4: PhD from Duke (PhD holders)"
  ),
  estimate = c(coef(q1), coef(q2), coef(q3), coef(q4)),
  lower_95 = c(confint(q1)[1], confint(q2)[1], confint(q3)[1], confint(q4)[1]),
  upper_95 = c(confint(q1)[2], confint(q2)[2], confint(q3)[2], confint(q4)[2])
) |>
  mutate(across(where(is.numeric), ~ round(.x, 3)))

results

