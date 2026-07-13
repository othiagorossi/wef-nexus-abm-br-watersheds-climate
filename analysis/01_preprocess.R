suppressPackageStartupMessages({
  library(here); library(dplyr); library(tidyr); library(readr)
  library(stringr); library(readxl); library(janitor); library(purrr)
  library(lubridate)
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

# Only these columns are read into memory (8 of ~140).
ANA_COLS <- c("org_uf", "ing_nm_municipio", "tin_ds", "tsp_ds", "tfn_ds",
              "tch_ds", "int_qt_vazaomedia", "int_qt_volumeanual")

read_permits <- function(path, source_type) {
  if (!file.exists(path)) {
    message("! Missing: ", basename(path), " — skipping.")
    return(NULL)
  }
  read_delim(
    path, delim = ",",
    locale = locale(encoding = "UTF-8"),
    col_select = any_of(ANA_COLS),      
    show_col_types = FALSE, progress = FALSE
  ) |>
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

permits <- permits_raw |>
  mutate(join_key = normalize_municipality(ing_nm_municipio)) |>
  mutate(join_key = recode(join_key, !!!NAME_CORRECTIONS)) |>
  filter(join_key %in% BASIN_JOIN_KEYS) |>
  left_join(BASIN_MUNICIPALITIES, by = "join_key")

rm(permits_raw); gc(verbose = FALSE)      # release the national table

message("Permits within basin (before validity filters): ", nrow(permits))

permits <- permits |>
  filter(tin_ds %in% VALID_INTERFERENCE,
         tsp_ds %in% VALID_STATUS) |>
  mutate(
    across(any_of(c("int_qt_vazaomedia", "int_qt_volumeanual")),
           \(x) as.numeric(str_replace(as.character(x), ",", "."))),
    use_purpose      = tfn_ds,
    is_abstraction   = tin_ds == "Captação",
    is_impoundment   = tin_ds == "Barragem",
    is_irrigation    = tfn_ds == "Irrigação",
    is_water_supply  = tfn_ds %in% c("Consumo Humano", "Abastecimento Público"),
    is_industrial    = tfn_ds == "Indústria",
    is_insignificant = tsp_ds == "Uso Insignificante",
    has_no_flow      = is.na(int_qt_vazaomedia) | int_qt_vazaomedia == 0,
    is_quantified    = is_abstraction & !has_no_flow
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
      n_total       = n(),
      n_abstraction = sum(is_abstraction),
      n_impoundment = sum(is_impoundment),
      n_quantified  = sum(is_quantified),
      pct_abstraction_no_flow = round(
        100 * sum(is_abstraction & has_no_flow) / sum(is_abstraction), 1)
    )
)

write_processed(permits, "water_permits_basin.csv")

permits_agg <- permits |>
  group_by(ibge_code, municipality, use_purpose, source_type) |>
  summarise(
    n_permits     = n(),
    n_abstraction = sum(is_abstraction),
    n_impoundment = sum(is_impoundment),
    n_quantified  = sum(is_quantified),
    total_flow    = sum(if_else(is_quantified, int_qt_vazaomedia, 0), na.rm = TRUE),
    total_volume  = sum(if_else(is_quantified, int_qt_volumeanual, 0), na.rm = TRUE),
    .groups = "drop"
  )
write_processed(permits_agg, "water_permits_by_municipality_purpose.csv")

rm(permits, permits_agg); gc(verbose = FALSE)

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
  select(-municipality) |>
  left_join(BASIN_MUNICIPALITIES, by = "join_key") |>
  select(ibge_code, municipality, class_level_1, class_level_2, all_of(year_cols)) |>
  pivot_longer(all_of(year_cols), names_to = "year", values_to = "area_ha") |>
  mutate(
    year    = as.integer(str_remove(year, "^x")),
    area_ha = as.numeric(area_ha),
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

rm(mapbiomas_raw); gc(verbose = FALSE)

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

lc_ibge_codes <- unique(land_cover_series$ibge_code)   # keep for coverage report
rm(land_cover, land_cover_series, land_cover_shares); gc(verbose = FALSE)

# ════════════════════════════════════════════════════════════════════════════
# 4. ANEEL — DISTRIBUTED SOLAR GENERATION
# ════════════════════════════════════════════════════════════════════════════

aneel_path <- file.path(DIR_RAW, "ANEEL", "aneel_distributed_generation.csv")

if (!file.exists(aneel_path)) {
  message("! ANEEL file not found — energy pillar skipped.")
  solar_ibge_codes <- character(0)
} else {

  ANEEL_COLS <- c(
    "SigUF", "CodMunicipioIbge", "NomMunicipio",
    "DscFonteGeracao", "DscClasseConsumo", "SigModalidadeEmpreendimento",
    "MdaPotenciaInstaladaKW", "DthAtualizaCadastralEmpreend", "DscPorte"
  )

  # Filter applied to each chunk; only matching rows are kept.
  keep_basin_solar <- function(chunk, pos) {
    chunk |>
      clean_names() |>
      filter(
        sig_uf == "SP",
        as.character(cod_municipio_ibge) %in% BASIN_IBGE_CODES,
        str_detect(str_to_upper(dsc_fonte_geracao), "SOLAR|FOTOVOLT|RADIA")
      )
  }

  message("Reading ANEEL registry in chunks (this takes a few minutes)...")

  solar <- read_delim_chunked(
    aneel_path,
    callback   = DataFrameCallback$new(keep_basin_solar),
    chunk_size = 100000,
    delim      = ";",
    locale     = locale(encoding = "latin1", decimal_mark = ","),
    col_select = any_of(ANEEL_COLS),
    col_types  = cols(.default = col_character()),
    progress   = FALSE
  )

  message("Solar PV installations in basin: ", nrow(solar))

  solar <- solar |>
    mutate(
      ibge_code   = as.character(cod_municipio_ibge),
      capacity_kw = as.numeric(str_replace(mda_potencia_instalada_kw, ",", ".")),
      connection_date = parse_date_time(
        dth_atualiza_cadastral_empreend,
        orders = c("ymd HMS", "dmy HMS", "ymd", "dmy"), quiet = TRUE),
      year              = year(connection_date),
      consumption_class = dsc_classe_consumo,
      is_rural          = str_detect(str_to_upper(dsc_classe_consumo), "RURAL")
    ) |>
    left_join(BASIN_MUNICIPALITIES |> select(ibge_code, municipality),
              by = "ibge_code")

  # --- Diagnostics ---------------------------------------------------------
  message("\nBy consumption class:")
  print(count(solar, consumption_class, sort = TRUE) |> head(10))

  message("\nRural-class installations (agricultural prosumers):")
  print(
    solar |> filter(is_rural) |>
      group_by(municipality) |>
      summarise(n = n(),
                capacity_kw = round(sum(capacity_kw, na.rm = TRUE), 1),
                .groups = "drop") |>
      arrange(desc(n)) |> head(10)
  )

  message("\nCapacity summary (kW):")
  print(summary(solar$capacity_kw))

  write_processed(solar, "solar_dg_basin.csv")

  # --- Annual adoption curve (ABM calibration target) -----------------------
  solar_annual <- solar |>
    filter(!is.na(year), year >= 2012, year <= year(Sys.Date())) |>
    group_by(year) |>
    summarise(
      n_installations = n(),
      n_rural         = sum(is_rural, na.rm = TRUE),
      capacity_kw     = round(sum(capacity_kw, na.rm = TRUE), 1),
      .groups = "drop"
    ) |>
    arrange(year) |>
    mutate(cum_installations = cumsum(n_installations),
           cum_capacity_kw   = cumsum(capacity_kw))

  write_processed(solar_annual, "solar_dg_annual.csv")
  message("\nAdoption curve:")
  print(solar_annual, n = Inf)

  # --- By municipality (ABM initialisation) ---------------------------------
  solar_by_muni <- solar |>
    group_by(ibge_code, municipality) |>
    summarise(
      n_installations   = n(),
      n_rural           = sum(is_rural, na.rm = TRUE),
      total_capacity_kw = round(sum(capacity_kw, na.rm = TRUE), 1),
      .groups = "drop"
    ) |>
    arrange(desc(total_capacity_kw))

  write_processed(solar_by_muni, "solar_dg_by_municipality.csv")

  solar_ibge_codes <- unique(solar$ibge_code)
  rm(solar, solar_annual, solar_by_muni); gc(verbose = FALSE)
}

# ════════════════════════════════════════════════════════════════════════════
# 5. COVERAGE REPORT
# ════════════════════════════════════════════════════════════════════════════
permits_check <- read_csv2(file.path(DIR_PROC, "water_permits_basin.csv"),
                           col_select = c(ibge_code, is_irrigation),
                           show_col_types = FALSE)

coverage_report <- BASIN_MUNICIPALITIES |>
  transmute(
    ibge_code, municipality,
    has_permits    = ibge_code %in% unique(permits_check$ibge_code),
    has_irrigation = ibge_code %in% unique(filter(permits_check, is_irrigation)$ibge_code),
    has_land_cover = ibge_code %in% lc_ibge_codes,
    has_solar_dg   = ibge_code %in% solar_ibge_codes
  )

message("\nCoverage by source:")
print(
  coverage_report |>
    summarise(across(starts_with("has_"), sum))
)
write_processed(coverage_report, "coverage_report.csv")

cat("\n== PREPROCESSING COMPLETE =============================\n")
print(basename(list.files(DIR_PROC, pattern = "\\.csv$", full.names = TRUE)))
cat("Next: analysis/02_eda.R\n\n")