library(dplyr)
library(sf)
library(here)
if (!requireNamespace("geobr", quietly = TRUE)) install.packages("geobr")
library(geobr)

roster_csv <- here::here("data", "processed", "basin_municipalities.csv")
basin_shp  <- here::here("data", "raw", "ANA", "limits_ugrhi6", "06_Bacia_Alto_Tiete.shp")
out_csv    <- here::here("outputs", "tables", "table_basin_intersection.csv")
dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)

proj_crs <- 31983 

roster <- read.csv(roster_csv, sep = ";", stringsAsFactors = FALSE)
codes  <- as.character(roster$ibge_code)

mun <- geobr::read_municipality(code_muni = "SP", year = 2022) %>%
  mutate(code_muni = as.character(code_muni)) %>%
  filter(code_muni %in% codes) %>%
  st_transform(proj_crs)

basin <- st_read(basin_shp, quiet = TRUE) %>%
  st_transform(proj_crs) %>%
  st_union()                      # single basin polygon

stopifnot(nrow(mun) == length(codes))

mun$area_total <- as.numeric(st_area(mun))
inter <- st_intersection(mun, basin)
inter$area_in  <- as.numeric(st_area(inter))

area_in <- inter %>% st_drop_geometry() %>%
  group_by(code_muni) %>% summarise(area_in = sum(area_in), .groups = "drop")

s1 <- mun %>% st_drop_geometry() %>%
  select(code_muni, name_muni, area_total) %>%
  left_join(area_in, by = "code_muni") %>%
  mutate(
    area_in = ifelse(is.na(area_in), 0, area_in),
    pct_in  = round(100 * area_in / area_total, 1),
    basin_intersection = ifelse(pct_in >= 99.5, "Total", "Partial")
  ) %>%
  left_join(roster %>% mutate(ibge_code = as.character(ibge_code)),
            by = c("code_muni" = "ibge_code")) %>%
  transmute(
    ibge_code   = code_muni,
    municipality = municipality,
    `pct_municipal_area_in_basin` = pct_in,
    basin_intersection
  ) %>%
  arrange(municipality)

cat("\n== Table S1 (Total =", sum(s1$basin_intersection == "Total"),
    "| Partial =", sum(s1$basin_intersection == "Partial"), ") ==\n")
print(as.data.frame(s1), row.names = FALSE)

write.csv(s1, out_csv, row.names = FALSE)
cat("\nSaved:", out_csv, "\n")