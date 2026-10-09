# Duke Faculty Survey

This STA 322 project uses a probability sample to study faculty represented in 17 departments in Duke University's Trinity College of Arts & Sciences. We constructed a frame from department-filtered Duke Scholars results and selected 230 faculty through proportionate stratified simple random sampling without replacement.

## Research questions

1. What proportion of faculty are women?
2. What proportion have at least one grant ongoing in 2026?
3. Among Ph.D. holders, what is the average number of years since receiving the degree?
4. What proportion of Ph.D. holders received their degree from Duke University?

## Results

All estimates account for department strata, inverse inclusion-probability weights, and finite population corrections.

| Question | Estimate | 95% confidence interval |
| --- | ---: | ---: |
| Faculty who are women | 41.5% | 36.3% to 46.6% |
| Ongoing grant in 2026 | 31.9% | 27.2% to 36.7% |
| Mean years since Ph.D. | 27.8 years | 25.8 to 29.8 years |
| Ph.D. received from Duke | 10.7% | 7.4% to 15.2% |

[Read the final report](report/WrittenReport.pdf).

## Repository structure

- `R/`: project configuration
- `scripts/`: numbered data-collection, coding, export, and analysis scripts
- `report/`: Quarto source and rendered final report
- `docs/`: supporting sampling-frame documentation
- `data/`: local raw and processed data locations plus a data dictionary
- `cache/`: locally cached Scholars pages
- `output/`: optional generated output

Detailed faculty data and cached pages are excluded from the public repository. The cleaned analysis CSV accompanies the Canvas submission.

## Reproducing the workflow

Open `duke-faculty-survey.Rproj` and run the scripts from the project root:

```r
source("scripts/01_build_sampling_frame.R")
source("scripts/02_draw_sample.R")
source("scripts/03_collect_sample_profiles.R")
source("scripts/04_code_gender_from_pronouns.R")
source("scripts/05_code_gender_from_names.R")
source("scripts/06_manual_gender_review.R")
source("scripts/07_export_submission_data.R")
source("scripts/08_analyze.R")
```

The manual-review step records classifications for profiles that could not be resolved automatically. The export script validates the final 230-person dataset, preserves a full audit copy locally, and produces the 18-column analysis CSV used by `08_analyze.R`.

Render the report after verifying the analysis results:

```bash
quarto render report/WrittenReport.qmd
```

## R packages

Install the CRAN packages used by the workflow:

```r
install.packages(c(
  "chromote", "dplyr", "gender", "httr2", "jsonlite", "purrr",
  "readr", "rvest", "stringr", "survey", "tibble", "tidyverse"
))
```

The name-coding step also uses the historical Social Security name data in `genderdata`:

```r
install.packages("remotes")
remotes::install_github("lmullen/genderdata")
```

## Data collection

The scripts separate frame construction from detailed profile collection so that detailed variables are collected only for sampled faculty. Requests are cached locally, and detailed data are excluded from GitHub because they include manually coded attributes. See [the data dictionary](data/README.md) for the submitted variables and coding rules.

## Authors

- Sophie Schwartz
- Claire Li
