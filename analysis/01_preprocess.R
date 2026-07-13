suppressPackageStartupMessages({
  library(here); library(dplyr); library(tidyr); library(readr)
  library(stringr); library(readxl); library(janitor); library(purrr)
})
source(here("analysis", "utils.R"))
create_project_dirs()

# ════════════════════════════════════════════════════════════════════════════
# 1. BASIN MUNICIPALITIES — source of truth
# ════════════════════════════════════════════════════════════════════════════
if (is.null(BASIN_MUNICIPALITIES)) {
  stop("BASIN_MUNICIPALITIES not loaded. Check data/raw/ANA/municipalities_ugrhi6/")
}
message("Basin municipalities: ", nrow(BASIN_MUNICIPALITIES))
write_processed(BASIN_MUNICIPALITIES, "basin_municipalities.csv")

# ════════════════════════════════════════════════════════════════════════════
# 2. ANA — WATER USE PERMITS (outorgas)
# ════════════════════════════════════════════════════════════════════════════

VALID_INTERFERENCE <- c("Captação", "Barragem")
VALID_STATUS       <- c("Outorgado", "Autorizado", "Uso Insignificante")

read_permits <- function(path, source_type) {
  if (!file.exists(path)) {
    message("! Missing: ", basename(path), " — skipping.")
    return(NULL)
  }
  read_delim(path, delim = ",",
             locale = locale(encoding = "UTF-8"),
             show_col_types = FALSE, progress = FALSE) |>
    clean_names() |>
    mutate(source_type = source_type)
}

permits_raw <- bind_rows(
  read_permits(file.path(DIR_RAW, "ANA", "outorgas_estaduais_superficiais.csv"),
               "surface"),
  read_permits(file.path(DIR_RAW, "ANA", "outorgas_estaduais_subterraneas.csv"),
               "groundwater")
)
if (nrow(permits_raw) == 0) stop("No permit records read.")
message("Permits, national: ", nrow(permits_raw))

permits_basin <- permits_raw |>
  mutate(join_key = normalize_municipality(ing_nm_municipio)) |>
  mutate(join_key = recode(join_key, !!!NAME_CORRECTIONS)) |>
  filter(join_key %in% BASIN_JOIN_KEYS) |>
  left_join(BASIN_MUNICIPALITIES, by = "join_key")

message("Permits within basin (before validity filters): ", nrow(permits_basin))

permits <- permits_basin |>
  filter(tin_ds %in% VALID_INTERFERENCE,
         tsp_ds %in% VALID_STATUS) |>
  mutate(
    across(any_of(c("int_qt_vazaomedia", "int_qt_volumeanual")),
           \(x) as.numeric(str_replace(as.character(x), ",", "."))),
    use_purpose       = tfn_ds,
    is_abstraction    = tin_ds == "Captação",
    is_impoundment    = tin_ds == "Barragem",
    is_irrigation     = tfn_ds == "Irrigação",
    is_water_supply   = tfn_ds %in% c("Consumo Humano", "Abastecimento Público"),
    is_industrial     = tfn_ds == "Indústria",
    is_insignificant  = tsp_ds == "Uso Insignificante",
    has_no_flow       = is.na(int_qt_vazaomedia) | int_qt_vazaomedia == 0,
    is_quantified     = is_abstraction & !has_no_flow
  )

message("Valid permits: ", nrow(permits))

message("\nInterference type x flow coverage:")
print(count(permits, tin_ds, has_no_flow))

message("\nBy use purpose:")
print(count(permits, use_purpose, sort = TRUE))

message("\nIrrigation permits by municipality (FOOD pillar):")
print(permits |> filter(is_irrigation) |> count(municipality, sort = TRUE) |> head(10))

message("\nQuantified demand coverage:")
print(
  permits |>
    summarise(
      n_total             = n(),
      n_abstraction       = sum(is_abstraction),
      n_impoundment       = sum(is_impoundment),
      n_quantified        = sum(is_quantified),
      pct_abstraction_no_flow = round(
        100 * sum(is_abstraction & has_no_flow) / sum(is_abstraction), 1)
    )
)

write_processed(permits, "water_permits_basin.csv")

permits_agg <- permits |>
  group_by(ibge_code, municipality, use_purpose, source_type) |>
  summarise(
    n_permits       = n(),
    n_abstraction   = sum(is_abstraction),
    n_impoundment   = sum(is_impoundment),
    n_quantified    = sum(is_quantified),
    total_flow      = sum(if_else(is_quantified, int_qt_vazaomedia, 0), na.rm = TRUE),
    total_volume    = sum(if_else(is_quantified, int_qt_volumeanual, 0), na.rm = TRUE),
    .groups = "drop"
  )
write_processed(permits_agg, "water_permits_by_municipality_purpose.csv")

# ════════════════════════════════════════════════════════════════════════════
# 3. MAPBIOMAS — LAND COVER, COLLECTION 10.1
# ════════════════════════════════════════════════════════════════════════════
mapbiomas_path <- here(
  DIR_RAW, "MapBiomas",
  "MAPBIOMAS_BRAZIL-COVERAGE_STATISTICS-COL.10.1-MUNICIPALITIES_STATES_BIOMES.xlsx"
)
if (!file.exists(mapbiomas_path)) {
  candidates <- list.files(here(DIR_RAW, "MapBiomas"),
                           pattern = "COVERAGE_STATISTICS.*10.1.*\\.xlsx$",
                           full.names = TRUE)
  if (length(candidates)) mapbiomas_path <- candidates[1]
}
if (!file.exists(mapbiomas_path)) stop("MapBiomas xlsx not found.")

mapbiomas_raw <- read_excel(mapbiomas_path, sheet = "COVERAGE_10.1") |> clean_names()
year_cols <- names(mapbiomas_raw)[str_detect(names(mapbiomas_raw), "^x?\\d{4}$")]

land_cover <- mapbiomas_raw |>
  filter(state_acronym == "SP") |>
  mutate(join_key = normalize_municipality(municipality)) |>
  mutate(join_key = recode(join_key, !!!NAME_CORRECTIONS)) |>
  filter(join_key %in% BASIN_JOIN_KEYS) |>
  select(-municipality) |>                       # drop source spelling
  left_join(BASIN_MUNICIPALITIES, by = "join_key") |>
  select(ibge_code, municipality, class_level_1, class_level_2,
         all_of(year_cols)) |>
  pivot_longer(all_of(year_cols), names_to = "year", values_to = "area_ha") |>
  mutate(
    year     = as.integer(str_remove(year, "^x")),
    area_ha  = as.numeric(area_ha),
    macro_class = case_when(
      str_detect(class_level_2, "Photovoltaic")                          ~ "photovoltaic",
      str_detect(class_level_1, "^1\\. Forest|^2\\. Non Forest Natural") ~ "native_vegetation",
      str_detect(class_level_1, "^3\\. Farming")                         ~ "farming",
      str_detect(class_level_2, "Urban Area")                            ~ "urban",
      str_detect(class_level_1, "^4\\. Non vegetated")                   ~ "non_vegetated_other",
      str_detect(class_level_1, "^5\\. Water")                           ~ "water",
      TRUE                                                                ~ "other"
    )
  )

land_cover_series <- land_cover |>
  group_by(ibge_code, municipality, year, macro_class) |>
  summarise(area_ha = sum(area_ha, na.rm = TRUE), .groups = "drop")

land_cover_shares <- land_cover_series |>
  group_by(ibge_code, year) |>
  mutate(total_area_ha = sum(area_ha, na.rm = TRUE),
         share_pct     = round(area_ha / total_area_ha * 100, 3)) |>
  ungroup()

write_processed(land_cover_series, "land_cover_series.csv")
write_processed(land_cover_shares, "land_cover_shares.csv")
message("MapBiomas: ", n_distinct(land_cover_series$ibge_code),
        " municipalities, ", n_distinct(land_cover_series$year), " years")

# ════════════════════════════════════════════════════════════════════════════
# 4. COVERAGE REPORT — which municipalities matched in each source
# ════════════════════════════════════════════════════════════════════════════
coverage_report <- BASIN_MUNICIPALITIES |>
  transmute(
    ibge_code, municipality,
    has_permits    = ibge_code %in% unique(permits$ibge_code),
    has_irrigation = ibge_code %in% unique(filter(permits, is_irrigation)$ibge_code),
    has_land_cover = ibge_code %in% unique(land_cover_series$ibge_code)
  )

unmatched <- filter(coverage_report, !has_land_cover)
if (nrow(unmatched) > 0) {
  message("! Unmatched in MapBiomas:")
  print(select(unmatched, ibge_code, municipality))
} else {
  message("[ok] All ", nrow(coverage_report),
          " municipalities matched in MapBiomas.")
}
write_processed(coverage_report, "coverage_report.csv")

cat("\n== PREPROCESSING COMPLETE =============================\n")
print(basename(list.files(DIR_PROC, pattern = "\\.csv$", full.names = TRUE)))
cat("Next: analysis/02_eda.R\n\n")