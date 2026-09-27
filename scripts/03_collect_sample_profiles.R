library(dplyr)
library(httr2)
library(purrr)
library(readr)
library(rvest)
library(stringr)
library(tibble)

sample_path <- "data/raw/sampled_faculty.csv"
if (!file.exists(sample_path)) {
  stop("Run scripts/02_draw_sample.R first.")
}

sampled_faculty <- read_csv(sample_path, show_col_types = FALSE)

max_profiles <- suppressWarnings(as.integer(Sys.getenv("MAX_PROFILES", "0")))
if (!is.na(max_profiles) && max_profiles > 0) {
  sampled_faculty <- slice_head(sampled_faculty, n = max_profiles)
}

dir.create("cache/profiles", recursive = TRUE, showWarnings = FALSE)
dir.create("cache/research", recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

user_agent <- paste(
  "STA322-course-project/1.0",
  "(student research; contact: yumeng.li@duke.edu)"
)

clean_text <- function(x) {
  x |>
    str_replace_all("\\s+", " ") |>
    str_trim()
}

download_cached_html <- function(url, path) {
  if (!file.exists(path)) {
    response <- request(url) |>
      req_user_agent(user_agent) |>
      req_timeout(30) |>
      req_retry(max_tries = 3) |>
      req_perform()
    writeBin(resp_body_raw(response), path)
    Sys.sleep(1)
  }
  read_html(path)
}

parse_education <- function(doc, faculty_id) {
  heading <- html_element(doc, "h2#education")
  if (inherits(heading, "xml_missing")) {
    return(tibble(
      faculty_id = character(), degree = character(), institution = character(),
      degree_year = integer()
    ))
  }

  section <- html_element(heading, xpath = "..")
  rows <- html_elements(section, xpath = "./div")

  map_dfr(rows, function(row) {
    institution <- row |>
      html_element(".t") |>
      html_text2() |>
      clean_text() |>
      str_remove("\\s*[·•]\\s*$")
    year_text <- row |> html_element(".y") |> html_text2() |> clean_text()
    degree <- row |>
      html_element(xpath = "./span[last()]") |>
      html_text2() |>
      clean_text()

    tibble(
      faculty_id = faculty_id,
      degree = degree,
      institution = institution,
      degree_year = parse_integer(str_extract(year_text, "[0-9]{4}"))
    )
  }) |>
    filter(nzchar(degree))
}

parse_grants <- function(doc, faculty_id) {
  links <- html_elements(doc, "a[href^='/grant/']")
  if (length(links) == 0) {
    return(tibble(
      faculty_id = character(), grant_id = character(), grant_title = character(),
      grant_url = character(), grant_text = character(), start_year = integer(),
      end_year = integer(), ongoing_in_2026 = logical(), date_quality = character()
    ))
  }

  map_dfr(links, function(link) {
    card <- html_element(link, xpath = "ancestor::div[1]")
    href <- html_attr(link, "href")
    card_text <- card |> html_text2() |> clean_text()
    date_text <- card |> html_element(".y") |> html_text2() |> clean_text()
    years <- str_extract_all(date_text, "[0-9]{4}")[[1]] |> as.integer()
    has_present <- str_detect(str_to_lower(date_text), "present")

    start_year <- if (length(years) >= 1) years[1] else NA_integer_
    end_year <- if (has_present) 9999L else if (length(years) >= 2) years[2] else NA_integer_
    ongoing <- if (!is.na(start_year) && !is.na(end_year)) {
      start_year <= 2026L && end_year >= 2026L
    } else {
      NA
    }

    tibble(
      faculty_id = faculty_id,
      grant_id = str_remove(href, ".*/grant/"),
      grant_title = html_text2(link) |> clean_text(),
      grant_url = paste0("https://scholars.duke.edu", href),
      grant_text = card_text,
      start_year = start_year,
      end_year = if (has_present) NA_integer_ else end_year,
      ongoing_in_2026 = ongoing,
      date_quality = case_when(
        has_present && !is.na(start_year) ~ "start_and_present",
        length(years) >= 2 ~ "start_and_end_year",
        length(years) == 1 ~ "one_year_only",
        TRUE ~ "dates_missing"
      )
    )
  }) |>
    distinct(faculty_id, grant_id, .keep_all = TRUE)
}

parse_profile <- function(person) {
  faculty_id <- person$faculty_id[[1]]
  profile_url <- person$profile_url[[1]]
  message("Collecting ", faculty_id)

  profile_doc <- download_cached_html(
    profile_url,
    file.path("cache/profiles", paste0(faculty_id, ".html"))
  )
  research_doc <- download_cached_html(
    paste0(profile_url, "/research"),
    file.path("cache/research", paste0(faculty_id, ".html"))
  )

  profile_name <- profile_doc |> html_element("h1") |> html_text2() |> clean_text()
  overview_node <- html_element(profile_doc, ".section-overview .excerpt")
  overview <- if (inherits(overview_node, "xml_missing")) {
    NA_character_
  } else {
    overview_node |> html_text2() |> clean_text()
  }

  education <- parse_education(profile_doc, faculty_id)
  grants <- parse_grants(research_doc, faculty_id)
  phd_rows <- education |>
    filter(str_detect(str_to_lower(degree), "ph\\.?d|d\\.?phil")) |>
    arrange(degree_year)

  has_phd <- nrow(phd_rows) > 0
  phd_year <- if (has_phd) phd_rows$degree_year[[1]] else NA_integer_
  phd_institution <- if (has_phd) phd_rows$institution[[1]] else NA_character_
  phd_from_duke <- if (has_phd) {
    str_detect(str_to_lower(phd_institution), "duke university")
  } else {
    NA
  }

  ongoing_grant <- case_when(
    any(grants$ongoing_in_2026 %in% TRUE) ~ 1L,
    nrow(grants) == 0 ~ 0L,
    any(is.na(grants$ongoing_in_2026)) ~ NA_integer_,
    TRUE ~ 0L
  )

  faculty <- person |>
    mutate(
      name = profile_name,
      overview_text = overview,
      woman = NA_integer_,
      sex_evidence = NA_character_,
      sex_review = "manual_review_required",
      has_phd = as.integer(has_phd),
      phd_year = phd_year,
      phd_institution = phd_institution,
      years_since_phd = if_else(has_phd && !is.na(phd_year), 2026L - phd_year, NA_integer_),
      phd_from_duke = as.integer(phd_from_duke),
      has_ongoing_grant_2026 = ongoing_grant,
      grant_status_unclear = any(is.na(grants$ongoing_in_2026)),
      profile_access_date = Sys.Date(),
      scrape_status = "success"
    )

  list(faculty = faculty, education = education, grants = grants)
}

results <- vector("list", nrow(sampled_faculty))

for (index in seq_len(nrow(sampled_faculty))) {
  results[[index]] <- tryCatch(
    parse_profile(sampled_faculty[index, ]),
    error = function(error) {
      person <- sampled_faculty[index, ] |>
        mutate(
          overview_text = NA_character_, woman = NA_integer_,
          sex_evidence = NA_character_, sex_review = "not_reviewed",
          has_phd = NA_integer_, phd_year = NA_integer_,
          phd_institution = NA_character_, years_since_phd = NA_integer_,
          phd_from_duke = NA_integer_, has_ongoing_grant_2026 = NA_integer_,
          grant_status_unclear = TRUE, profile_access_date = Sys.Date(),
          scrape_status = paste0("error: ", conditionMessage(error))
        )
      list(faculty = person, education = tibble(), grants = tibble())
    }
  )

  faculty_checkpoint <- map_dfr(results[seq_len(index)], "faculty")
  education_checkpoint <- map_dfr(results[seq_len(index)], "education")
  grants_checkpoint <- map_dfr(results[seq_len(index)], "grants")

  write_csv(faculty_checkpoint, "data/processed/faculty_profiles.csv")
  write_csv(education_checkpoint, "data/processed/education.csv")
  write_csv(grants_checkpoint, "data/processed/grants.csv")
}

message(
  "Saved ", nrow(sampled_faculty), " faculty profiles, ",
  nrow(map_dfr(results, "education")), " education records, and ",
  nrow(map_dfr(results, "grants")), " grant records."
)
