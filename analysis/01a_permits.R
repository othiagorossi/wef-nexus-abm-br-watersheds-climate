suppressPackageStartupMessages({
  library(here); library(dplyr); library(readr); library(stringr)
  library(janitor)
})
source(here("analysis", "utils.R"))
create_project_dirs()

stopifnot("Basin municipalities not loaded" = !is.null(BASIN_MUNICIPALITIES))
write_processed(BASIN_MUNICIPALITIES, "basin_municipalities.csv")

VALID_INTERFERENCE <- c("Captação", "Barragem")
VALID_STATUS       <- c("Outorgado", "Autorizado", "Uso Insignificante")

ANA_COLS <- c("org_uf", "ing_nm_municipio", "tin_ds", "tsp_ds", "tfn_ds",
              "tch_ds", "int_qt_vazaomedia", "int_qt_volumeanual")

read_permits <- function(path, source_type) {
  if (!file.exists(path)) {
    message("! Missing: ", basename(path))
    return(NULL)
  }
  read_delim(path, delim = ",",
             locale     = locale(encoding = "UTF-8"),
             col_select = any_of(ANA_COLS),
             show_col_types = FALSE, progress = FALSE) |>
    clean_names() |>
    mutate(join_key = normalize_municipality(ing_nm_municipio)) |>
    mutate(join_key = recode(join_key, !!!NAME_CORRECTIONS)) |>
    filter(join_key %in% BASIN_JOIN_KEYS) |>   # filter before binding
    mutate(source_type = source_type)
}

permits <- bind_rows(
  read_permits(file.path(DIR_RAW, "ANA", "outorgas_estaduais_superficiais.csv"),
               "surface"),
  read_permits(file.path(DIR_RAW, "ANA", "outorgas_estaduais_subterraneas.csv"),
               "groundwater")
)
if (nrow(permits) == 0) stop("No permit records read.")
gc(verbose = FALSE)

message("Permits within basin: ", nrow(permits))

permits <- permits |>
  left_join(BASIN_MUNICIPALITIES, by = "join_key") |>
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

message("\n[done] 01a_permits.R")
