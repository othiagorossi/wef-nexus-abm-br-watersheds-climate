suppressPackageStartupMessages({
  library(here); library(dplyr); library(tidyr); library(readr)
  library(stringr); library(readxl); library(janitor)
})
source(here("analysis", "utils.R"))
create_project_dirs()

stopifnot("Basin municipalities not loaded" = !is.null(BASIN_MUNICIPALITIES))

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

land_cover <- read_excel(mapbiomas_path, sheet = "COVERAGE_10.1") |>
  clean_names() |>
  filter(state_acronym == "SP")
gc(verbose = FALSE)

year_cols <- names(land_cover)[str_detect(names(land_cover), "^x?\\d{4}$")]

land_cover <- land_cover |>
  mutate(join_key = normalize_municipality(municipality)) |>
  mutate(join_key = recode(join_key, !!!NAME_CORRECTIONS)) |>
  filter(join_key %in% BASIN_JOIN_KEYS) |>
  select(-municipality) |>
  left_join(BASIN_MUNICIPALITIES, by = "join_key") |>
  select(ibge_code, municipality, class_level_1, class_level_2,
         all_of(year_cols)) |>
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
gc(verbose = FALSE)

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

message("\nBasin-wide land cover, 1985 vs 2024 (% of basin area):")
print(
  land_cover_series |>
    filter(year %in% c(1985, 2024)) |>
    group_by(year, macro_class) |>
    summarise(area_ha = sum(area_ha, na.rm = TRUE), .groups = "drop_last") |>
    mutate(share_pct = round(100 * area_ha / sum(area_ha), 2)) |>
    select(year, macro_class, share_pct) |>
    pivot_wider(names_from = year, values_from = share_pct)
)

message("\n[done] 01b_land_cover.R")
