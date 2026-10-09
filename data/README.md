# Data dictionary

The unit of observation in the submitted analysis file is one sampled faculty member. The cleaned `faculty_final.csv` contains 230 rows and 18 variables. It accompanies the Canvas submission and is excluded from this public repository because it includes a manually coded attribute.

| Variable | Description |
| --- | --- |
| `sampling_department` | Department used as the sampling stratum |
| `faculty_id` | Duke Scholars faculty identifier |
| `profile_url` | Duke Scholars profile URL |
| `name` | Faculty name shown on Duke Scholars |
| `N_h` | Number of faculty in the department's sampling frame |
| `n_h` | Number sampled from the department |
| `selection_probability` | Inclusion probability, calculated as `n_h / N_h` |
| `survey_weight` | Inverse inclusion probability, calculated as `N_h / n_h` |
| `woman_final` | Final indicator for whether the faculty member was classified as a woman: 1 for yes and 0 for no |
| `gender_method` | Method used for the final classification: profile pronouns, first-name classification, or manual review |
| `has_phd` | Indicator for an explicitly listed Ph.D. or D.Phil.: 1 for yes and 0 for no |
| `phd_year` | Year of the listed Ph.D. or D.Phil.; missing for faculty without an identified degree |
| `phd_institution` | Institution granting the listed Ph.D. or D.Phil.; missing for faculty without an identified degree |
| `years_since_phd` | `2026 - phd_year`; missing for faculty without an identified degree |
| `phd_from_duke` | Indicator that the listed Ph.D. or D.Phil. is from Duke: 1 for yes, 0 for no, and missing for faculty without an identified degree |
| `has_ongoing_grant_2026` | Indicator for at least one listed grant with dates including 2026: 1 for yes and 0 for no |
| `profile_access_date` | Date on which the Scholars profile was collected |
| `scrape_status` | Status of the profile-collection request |

## Local data files

- `data/raw/` contains the frame, department memberships, allocation, and sampled faculty.
- `data/processed/faculty_final_full.csv` is the local 39-column audit file.
- `data/processed/faculty_final.csv` is the cleaned 18-column analysis file used by `scripts/08_analyze.R`.

Raw, processed, and cached data are intentionally ignored by Git. Empty `.gitkeep` files preserve the directory structure.
