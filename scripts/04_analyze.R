# Estimate the requested quantities and 95% confidence intervals here.
# Use the survey package if the final design includes strata or unequal weights.

library(dplyr)
library(readr)
library(survey)

faculty <- read_csv(
  "data/processed/faculty_final.csv",
  show_col_types = FALSE
)

faculty_design <- svydesign(
  ids = ~1,
  strata = ~sampling_department,
  weights = ~survey_weight,
  fpc = ~N_h,
  data = faculty
)

# Question 1
women_estimate <- svymean(
  ~woman_final,
  design = faculty_design
)

women_estimate
confint(women_estimate)

# Question 2
grant_estimate <- svymean(
  ~has_ongoing_grant_2026,
  design = faculty_design,
  na.rm = TRUE
)

grant_estimate
confint(grant_estimate)

# Question 3
phd_design <- subset(
  faculty_design,
  has_phd == 1
)

phd_years_estimate <- svymean(
  ~years_since_phd,
  design = phd_design,
  na.rm = TRUE
)

phd_years_estimate
confint(phd_years_estimate)