suppressPackageStartupMessages({
  library(here); library(dplyr); library(tidyr); library(readr); library(stringr)
})
source(here("analysis", "utils.R"))

DIR_MODEL <- here("data", "model_inputs")
if (!dir.exists(DIR_MODEL)) dir.create(DIR_MODEL, recursive = TRUE)

# Standard-CSV writer for NetLogo (comma sep, dot decimal, no quotes on numbers)
write_model <- function(df, filename) {
  path <- file.path(DIR_MODEL, filename)
  readr::write_csv(df, path, na = "0")   # NetLogo reads empty as trouble; use 0
  message("[ok] Saved: ", file.path("data/model_inputs", filename),
          " (", nrow(df), " rows)")
  invisible(path)
}

BASE_YEAR <- 1985

land <- read_csv2(here("data", "processed", "land_cover_series.csv"),
                  show_col_types = FALSE)

# All macro-classes the model expects, in fixed order. Classes absent in the
# base year (e.g. photovoltaic, which appears only from ~2015) must still yield
# a zero column.
MACRO_CLASSES <- c("native_vegetation", "farming", "urban",
                   "water", "photovoltaic", "non_vegetated_other", "other")

initial_land <- land |>
  filter(year == BASE_YEAR) |>
  mutate(macro_class = factor(macro_class, levels = MACRO_CLASSES)) |>
  select(ibge_code, municipality, macro_class, area_ha) |>
  complete(nesting(ibge_code, municipality), macro_class,
           fill = list(area_ha = 0)) |>
  pivot_wider(names_from = macro_class, values_from = area_ha,
              values_fill = 0, names_prefix = "area_",
              names_expand = TRUE)

permits <- read_csv2(
  here("data", "processed", "water_permits_by_municipality_purpose.csv"),
  show_col_types = FALSE)

irrigation <- permits |>
  filter(use_purpose == "Irrigação") |>
  group_by(ibge_code) |>
  summarise(
    irrigation_permits = sum(n_quantified, na.rm = TRUE),
    irrigation_flow    = sum(total_flow,   na.rm = TRUE),
    .groups = "drop"
  )

initial_conditions <- initial_land |>
  left_join(irrigation, by = "ibge_code") |>
  mutate(across(where(is.numeric), \(x) replace_na(x, 0))) |>
  transmute(
    ibge_code, municipality,
    area_native  = area_native_vegetation,
    area_farming = area_farming,
    area_urban   = area_urban,
    area_water   = area_water,
    area_pv      = area_photovoltaic,
    area_other   = area_non_vegetated_other + area_other,
    irrigation_permits,
    irrigation_flow
  ) |>
  arrange(ibge_code)

write_model(initial_conditions, "municipality_initial_conditions.csv")

validation_land <- land |>
  group_by(year, macro_class) |>
  summarise(area_ha = sum(area_ha, na.rm = TRUE), .groups = "drop_last") |>
  mutate(share_pct = round(100 * area_ha / sum(area_ha), 4)) |>
  ungroup() |>
  select(year, macro_class, share_pct) |>
  pivot_wider(names_from = macro_class, values_from = share_pct, values_fill = 0) |>
  arrange(year)
 
write_model(validation_land, "validation_land_cover.csv")

solar_path <- here("data", "processed", "solar_dg_annual.csv")
if (file.exists(solar_path)) {
  solar <- read_csv2(solar_path, show_col_types = FALSE) |>
    select(year, n_installations, n_rural,
           cum_installations, cum_capacity_kw) |>
    arrange(year)
  write_model(solar, "validation_solar_adoption.csv")
} else {
  message("! solar_dg_annual.csv not found — skipping solar validation target.")
}

message("\n[done] 01e_model_inputs.R")
message("Model inputs written to data/model_inputs/ (standard CSV for NetLogo).")
