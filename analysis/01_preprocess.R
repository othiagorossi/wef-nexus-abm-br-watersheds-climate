# 01_preprocess.R
# Pipeline: raw data → processed CSVs for ABM parameterization
# Run once before any other analysis script.
# All outputs go to data/processed/

library(tidyverse)
library(terra)
library(sf)

# ── Paths ──────────────────────────────────────────────────────────────────
DIR_RAW  <- here::here("data", "raw")
DIR_PROC <- here::here("data", "processed")

# ── TODO: Define study basin bounding box ──────────────────────────────────
# BASIN_NAME <- "..."
# BASIN_BBOX <- c(xmin = , ymin = , xmax = , ymax = )   # WGS84

# ── 1. MapBiomas ───────────────────────────────────────────────────────────
# TODO: Download via Google Earth Engine Python API or MapBiomas platform
# Expected files: data/raw/MapBiomas/collection9_YYYY.tif (1985–2024)
# Reclassification key:
#   3,4,5,49  → "native_vegetation"
#   15        → "pasture"
#   39,20,40,62,41 → "agriculture"
#   24        → "urban"
#   33        → "water"
#   others    → "other"

# process_mapbiomas <- function(year) { ... }
# lulc <- map_dfr(1985:2024, process_mapbiomas)
# write_csv(lulc, file.path(DIR_PROC, "lulc_basin_1985_2024.csv"))

# ── 2. ANA water withdrawals ───────────────────────────────────────────────
# TODO: Load outorgas CSV, filter for study basin, aggregate by sector/month

# ana_raw <- read_csv(file.path(DIR_RAW, "ANA", "outorgas.csv"))
# water_withdrawals <- ana_raw |>
#   filter(bacia_codigo == BASIN_CODE) |>
#   group_by(year, month, setor) |>
#   summarise(withdrawal_m3 = sum(vazao_m3s * 60 * 60 * 24 * 30), .groups = "drop")
# write_csv(water_withdrawals, file.path(DIR_PROC, "water_withdrawals_monthly.csv"))

# ── 3. ANEEL distributed solar ─────────────────────────────────────────────
# TODO: Load SIGEL CSV, filter municipalities in basin, cumulative adoption

# aneel_raw <- read_csv(file.path(DIR_RAW, "ANEEL", "gd_solar.csv"))
# solar_adoption <- aneel_raw |>
#   filter(municipio_codigo %in% BASIN_MUNICIPALITIES) |>
#   arrange(data_conexao) |>
#   group_by(municipio_codigo) |>
#   mutate(cumulative_kwp = cumsum(potencia_instalada_kw)) |>
#   ungroup()
# write_csv(solar_adoption, file.path(DIR_PROC, "solar_adoption_municipal.csv"))

# ── 4. IPCC AR6 climate scenarios ──────────────────────────────────────────
# TODO: Load NetCDF, crop to basin bbox, extract monthly time series

# library(ncdf4)
# process_ipcc <- function(scenario, variable) { ... }
# for (scen in c("ssp245", "ssp585")) {
#   climate <- process_ipcc(scen, c("pr", "tas"))
#   write_csv(climate, file.path(DIR_PROC, paste0("climate_monthly_", scen, ".csv")))
# }

message("01_preprocess.R: all sections are TODOs — implement after data download.")
message("See data/README_data.md for download instructions.")
