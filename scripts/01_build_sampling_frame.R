library(chromote)
library(dplyr)
library(jsonlite)
library(purrr)
library(readr)
library(stringr)
library(tibble)

source("R/config.R")

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
dir.create("cache/frame", recursive = TRUE, showWarnings = FALSE)

encode_query_value <- function(x) utils::URLencode(x, reserved = TRUE)

department_search_url <- function(department, page = 1L) {
  paste0(
    search_base_url,
    "?q=%2A&tab=people&pplptf%5B%5D=Faculty",
    "&suf%5B%5D=", encode_query_value(school_unit),
    "&df%5B%5D=", encode_query_value(department),
    "&ppls=Person+a-z&pplsp=", page
  )
}

evaluate_value <- function(browser, expression) {
  browser$Runtime$evaluate(
    expression = expression,
    returnByValue = TRUE,
    awaitPromise = TRUE
  )$result$value
}

wait_for_people <- function(browser, timeout_seconds = 30) {
  started <- Sys.time()
  repeat {
    count <- evaluate_value(
      browser,
      "document.querySelectorAll('#people a[href*=\"/person/\"]').length"
    )
    if (!is.null(count) && count > 0) return(invisible(TRUE))
    if (difftime(Sys.time(), started, units = "secs") > timeout_seconds) {
      stop("Timed out waiting for faculty results.")
    }
    Sys.sleep(0.25)
  }
}

read_result_page <- function(browser, department, page) {
  browser$Page$navigate(department_search_url(department, page))
  wait_for_people(browser)

  json <- evaluate_value(
    browser,
    paste0(
      "JSON.stringify(Array.from(",
      "document.querySelectorAll('#people a[href*=\"/person/\"]')",
      ").map(a => ({",
      "profile_url: new URL(a.getAttribute('href'), location.origin).href,",
      "link_text: (a.textContent || '').trim()",
      "})))"
    )
  )

  fromJSON(json) |>
    as_tibble() |>
    filter(str_detect(profile_url, "^https://scholars\\.duke\\.edu/person/")) |>
    mutate(
      faculty_id = str_remove(profile_url, ".*/person/"),
      department = department,
      page = page
    ) |>
    filter(nzchar(link_text)) |>
    group_by(faculty_id, profile_url, department, page) |>
    summarise(name = link_text[which.min(nchar(link_text))], .groups = "drop")
}

read_department_frame <- function(browser, department) {
  browser$Page$navigate(department_search_url(department, 1L))
  wait_for_people(browser)

  total_text <- evaluate_value(
    browser,
    "document.querySelector('#people')?.innerText.match(/Showing 1\\s*-\\s*20 of [0-9,]+/)?.[0] || ''"
  )
  total <- parse_number(str_extract(total_text, "[0-9,]+$"))
  if (is.na(total)) stop("Could not determine result count for ", department)

  pages <- seq_len(ceiling(total / 20))
  message(department, ": ", total, " results across ", length(pages), " pages")

  map_dfr(pages, function(page) {
    if (page > 1L) Sys.sleep(0.75)
    read_result_page(browser, department, page)
  }) |>
    distinct(faculty_id, department, .keep_all = TRUE)
}

browser <- ChromoteSession$new()
on.exit(browser$close(), add = TRUE)

department_memberships <- map_dfr(
  included_departments,
  ~ read_department_frame(browser, .x)
)

write_csv(
  department_memberships,
  "data/raw/faculty_department_memberships.csv"
)

faculty_frame <- department_memberships |>
  arrange(faculty_id, department) |>
  group_by(faculty_id, profile_url) |>
  summarise(
    name = name[which.min(nchar(name))],
    departments = paste(sort(unique(department)), collapse = " | "),
    department_count = n_distinct(department),
    sampling_department = sort(unique(department))[1],
    .groups = "drop"
  ) |>
  arrange(sampling_department, name, faculty_id)

stopifnot(!anyDuplicated(faculty_frame$faculty_id))
stopifnot(all(faculty_frame$sampling_department %in% included_departments))
stopifnot(!any(map_lgl(
  faculty_frame$departments,
  ~ any(str_detect(.x, fixed(excluded_departments)))
)))

write_csv(faculty_frame, "data/raw/faculty_sampling_frame.csv")

message(
  "Saved ", nrow(faculty_frame),
  " unique faculty to data/raw/faculty_sampling_frame.csv"
)
