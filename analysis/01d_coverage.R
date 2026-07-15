suppressPackageStartupMessages({
  library(here); library(dplyr); library(readr)
})
source(here("analysis", "utils.R"))

stopifnot("Basin municipalities not loaded" = !is.null(BASIN_MUNICIPALITIES))

read_if_exists <- function(filename, cols) {
  path <- file.path(DIR_PROC, filename)
  if (!file.exists(path)) {
    message("! Not found (run its script first): ", filename)
    return(NULL)
  }
  read_csv2(path, col_select = all_of(cols), show_col_types = FALSE)
}

permits    <- read_if_exists("water_permits_basin.csv",
                             c("ibge_code", "is_irrigation"))
land_cover <- read_if_exists("land_cover_series.csv", "ibge_code")
solar      <- read_if_exists("solar_dg_basin.csv", c("ibge_code", "is_rural"))

coverage_report <- BASIN_MUNICIPALITIES |>
  transmute(
    ibge_code, municipality,
    has_permits    = ibge_code %in% unique(permits$ibge_code),
    has_irrigation = ibge_code %in% unique(filter(permits, is_irrigation)$ibge_code),
    has_land_cover = ibge_code %in% unique(land_cover$ibge_code),
    has_solar_dg   = ibge_code %in% unique(solar$ibge_code),
    has_rural_solar = ibge_code %in% unique(filter(solar, is_rural)$ibge_code)
  )

message("Municipalities covered, by source (out of ", nrow(coverage_report), "):")
print(coverage_report |> summarise(across(starts_with("has_"), sum)))

message("\nMunicipalities with BOTH irrigation permits and rural solar DG:")
print(
  coverage_report |>
    filter(has_irrigation, has_rural_solar) |>
    select(municipality)
)

write_processed(coverage_report, "coverage_report.csv")
message("\n[done] 01d_coverage.R")
