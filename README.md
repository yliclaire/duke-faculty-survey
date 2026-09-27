# Duke Faculty Survey

STA 322 Project 1: a probability sample of Duke faculty in Trinity College.

## Project workflow

1. Build a sampling frame containing faculty names, profile URLs, and departments.
2. Draw and save a reproducible probability sample.
3. Collect detailed variables only for sampled faculty profiles.
4. Manually review ambiguous values.
5. Estimate population quantities and 95% confidence intervals using the recorded inclusion probabilities or survey weights.

The assignment asks students not to scrape detailed information for the full faculty population. Scripts in this repository should therefore separate sampling-frame collection from detailed profile collection.

## Folders

- `R/`: reusable R functions
- `scripts/`: scripts run in numbered order
- `data/raw/`: local source data, excluded from Git
- `data/processed/`: local analysis data, excluded from Git
- `cache/`: cached HTML, excluded from Git
- `output/`: generated reports and figures, excluded from Git

## Setup

Open `duke-faculty-survey.Rproj`, then run:

```r
install.packages(c(
  "dplyr", "httr2", "janitor", "polite", "purrr", "readr",
  "rvest", "stringr", "survey", "tibble"
))
```

Before collecting pages, check the site's terms and `robots.txt`. Use a descriptive user agent, cache responses, and space requests apart.

