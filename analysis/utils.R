# utils.R
# Shared constants and helper functions.
# Source with: source(here::here("analysis", "utils.R"))
#
# NOTE ON LANGUAGE: code, identifiers and comments are in English.
# Data *values* remain in Portuguese (e.g. "Captação", "Irrigação",
# municipality names) because they come from the source datasets and must
# not be altered.

library(here)
suppressPackageStartupMessages({
  library(dplyr)
  library(sf)
  library(stringr)
})

# ── Directories ─────────────────────────────────────────────────────────────
DIR_RAW  <- here("data", "raw")
DIR_PROC <- here("data", "processed")
DIR_FIG  <- here("outputs", "figures")
DIR_TAB  <- here("outputs", "tables")

# ── Municipality name normalisation ─────────────────────────────────────────
# Used in EVERY name-based join (ANA, MapBiomas). Source datasets spell the
# same municipality inconsistently, e.g. "Biritiba-Mirim" (shapefile) vs
# "Biritiba Mirim" (MapBiomas) vs both spellings within ANA itself.
# Strategy: hyphens -> spaces, strip accents, collapse whitespace, uppercase.
normalize_municipality <- function(x) {
  x |>
    as.character() |>
    stringr::str_replace_all("-", " ") |>
    stringr::str_squish() |>
    abjutils::rm_accent() |>
    stringr::str_to_upper()
}

# ── Source of truth: municipalities of the Alto Tietê basin (UGRHI 6) ──────
# Derived from the official Alto Tietê Basin Committee shapefile.
# Filter CBHAT == 1 selects municipalities belonging to the basin committee.
# Returns a data frame with IBGE code, official names, and a join key.
load_basin_municipalities <- function() {
  shp <- here(DIR_RAW, "ANA", "municipalities_ugrhi6", "Municipios UGRHI 6.shp")
  if (!file.exists(shp)) {
    stop("Municipality shapefile not found: ", shp,
         "\nExtract 'Municipios UGRHI 6' from the Comitê AT archive into that folder.")
  }
  sf::read_sf(shp) |>
    sf::st_drop_geometry() |>
    dplyr::filter(CBHAT == 1) |>
    dplyr::transmute(
      ibge_code     = as.character(COD_IBGE),
      municipality  = NM_MUNI_UC,   # official uppercase name
      join_key      = normalize_municipality(NM_MUNI_UC)
    ) |>
    dplyr::arrange(municipality)
}

# Loaded once on source(). Does not abort the script if the shapefile is
# missing — downstream scripts check for NULL and fail with a clear message.
BASIN_MUNICIPALITIES <- tryCatch(
  load_basin_municipalities(),
  error = function(e) {
    message("! BASIN_MUNICIPALITIES not loaded: ", conditionMessage(e))
    NULL
  }
)

if (!is.null(BASIN_MUNICIPALITIES)) {
  BASIN_IBGE_CODES <- BASIN_MUNICIPALITIES$ibge_code
  BASIN_JOIN_KEYS  <- BASIN_MUNICIPALITIES$join_key
  message("[ok] ", nrow(BASIN_MUNICIPALITIES),
          " UGRHI 6 municipalities loaded from shapefile.")
}

# ── Name reconciliation: source datasets -> official shapefile names ────────
# Keys and values are already normalised. Extend if the match report flags
# unmatched municipalities.
NAME_CORRECTIONS <- c(
  "EMBU" = "EMBU DAS ARTES"   # legacy IBGE name still used by some sources
)

# ── Standardised writer for processed data ──────────────────────────────────
# Project convention: UTF-8, semicolon separator.
write_processed <- function(df, filename) {
  if (!dir.exists(DIR_PROC)) dir.create(DIR_PROC, recursive = TRUE)
  path <- file.path(DIR_PROC, filename)
  readr::write_csv2(df, path, na = "NA")
  message("[ok] Saved: ", basename(path),
          " (", nrow(df), " rows, ", ncol(df), " cols)")
  invisible(path)
}

# ── Ensure project directories exist ────────────────────────────────────────
create_project_dirs <- function() {
  dirs <- c(DIR_RAW, DIR_PROC, DIR_FIG, DIR_TAB,
            file.path(DIR_RAW, c("ANA", "ANEEL", "MapBiomas")))
  purrr::walk(dirs, \(d) if (!dir.exists(d)) dir.create(d, recursive = TRUE))
  invisible(TRUE)
}

# ── Provenance logging ──────────────────────────────────────────────────────
log_download <- function(dataset, url, access_date = Sys.Date(), notes = "") {
  entry <- sprintf("[%s] %s\n  URL: %s\n  Notes: %s\n\n",
                   access_date, dataset, url, notes)
  cat(entry, file = here("data", "download_log.txt"), append = TRUE)
  invisible(TRUE)
}