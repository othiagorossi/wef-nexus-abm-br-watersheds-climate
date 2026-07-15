# 01c_solar.R
# ANEEL distributed generation -> data/processed/solar_dg_*.csv
#
# Run as a SEPARATE process (Rscript).
#
# The national registry holds millions of records and does not fit in memory,
# so it is read in CHUNKS and filtered on the fly: only solar PV installations
# inside the basin survive each chunk. Column selection happens INSIDE the
# chunk callback (read_delim_chunked does not accept col_select).
#
# The registry carries cod_municipio_ibge, so the spatial join uses the IBGE
# code directly — immune to spelling inconsistencies.
#
# KEY VARIABLE: dsc_classe_consumo. Rural-class installations are the
# agricultural prosumers through which the solar pumping rebound operates.

suppressPackageStartupMessages({
  library(here); library(dplyr); library(readr); library(stringr)
  library(janitor); library(lubridate)
})
source(here("analysis", "utils.R"))
create_project_dirs()

stopifnot("Basin municipalities not loaded" = !is.null(BASIN_MUNICIPALITIES))

aneel_path <- file.path(DIR_RAW, "ANEEL", "aneel_distributed_generation.csv")
if (!file.exists(aneel_path)) {
  stop("ANEEL file not found. Run analysis/00_download.R first.")
}

# Columns kept from each chunk (after clean_names()).
KEEP_COLS <- c(
  "sig_uf", "cod_municipio_ibge", "nom_municipio",
  "dsc_fonte_geracao", "dsc_classe_consumo", "sig_modalidade_empreendimento",
  "dsc_porte", "mda_potencia_instalada_kw", "dth_atualiza_cadastral_empreend"
)

# Applied to every chunk: clean names, filter to basin solar, keep few columns.
keep_basin_solar <- function(chunk, pos) {
  chunk |>
    clean_names() |>
    filter(
      sig_uf == "SP",
      as.character(cod_municipio_ibge) %in% BASIN_IBGE_CODES,
      str_detect(str_to_upper(dsc_fonte_geracao), "SOLAR|FOTOVOLT|RADIA")
    ) |>
    select(any_of(KEEP_COLS))
}

message("Reading ANEEL registry in chunks (a few minutes)...")

solar <- read_delim_chunked(
  aneel_path,
  callback   = DataFrameCallback$new(keep_basin_solar),
  chunk_size = 50000,
  delim      = ";",
  locale     = locale(encoding = "latin1", decimal_mark = ","),
  col_types  = cols(.default = col_character()),
  progress   = FALSE
)
gc(verbose = FALSE)

message("Solar PV installations in basin: ", nrow(solar))
if (nrow(solar) == 0) stop("No records matched. Check column names/filters.")

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

# --- Diagnostics ------------------------------------------------------------
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

message("\nInstalled capacity (kW):")
print(summary(solar$capacity_kw))

write_processed(solar, "solar_dg_basin.csv")

# --- Annual adoption curve (ABM calibration target) -------------------------
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

# --- By municipality (ABM initialisation) -----------------------------------
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

message("\n[done] 01c_solar.R")