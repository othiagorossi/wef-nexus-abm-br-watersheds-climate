suppressPackageStartupMessages({
  library(here); library(dplyr); library(tidyr); library(ggplot2)
  library(sf); library(readr)
})
source(here("analysis", "utils.R"))
source(here("analysis", "04_figures.R"))  # PALETTE, save_fig (convenção 300 DPI)

bacia_shp <- st_read(file.path(DIR_RAW, "ANA", "limits_ugrhi6",
                               "06_Bacia_Alto_Tiete.shp"), quiet = TRUE)
mun_shp   <- st_read(file.path(DIR_RAW, "ANA", "municipalities_ugrhi6",
                               "Municipios UGRHI 6.shp"), quiet = TRUE)

if ("CBHAT" %in% names(mun_shp)) {
  mun_shp <- filter(mun_shp, CBHAT == 1)
  message(sprintf("[info] Municípios após filtro CBHAT==1: %d", nrow(mun_shp)))
}

if (is.na(st_crs(mun_shp)))   stop("mun_shp sem CRS definido.")
if (is.na(st_crs(bacia_shp))) st_crs(bacia_shp) <- st_crs(mun_shp)
bacia_shp <- st_transform(bacia_shp, st_crs(mun_shp))

solar   <- read_csv2(here("data", "processed", "solar_dg_by_municipality.csv"),
                     show_col_types = FALSE)
permits <- read_csv2(here("data", "processed",
                          "water_permits_by_municipality_purpose.csv"),
                     show_col_types = FALSE)

solar_ativo <- solar |> filter(total_capacity_kw > 0)

irrigacao <- permits |>
  filter(use_purpose == "Irrigação") |>
  group_by(ibge_code) |>
  summarise(vol_outorgado = sum(total_volume, na.rm = TRUE), .groups = "drop")

col_ibge <- names(mun_shp)[grepl("CD_MUN|IBGE|codigo", names(mun_shp),
                                 ignore.case = TRUE)][1]
if (is.na(col_ibge))
  stop("Coluna de código IBGE não encontrada no shapefile. Colunas: ",
       paste(names(mun_shp), collapse = ", "))

mun_shp <- mun_shp |> mutate(ibge_code = as.character(.data[[col_ibge]]))
solar_ativo <- mutate(solar_ativo, ibge_code = as.character(ibge_code))
irrigacao   <- mutate(irrigacao,   ibge_code = as.character(ibge_code))

n_solar <- sum(mun_shp$ibge_code %in% solar_ativo$ibge_code)
n_irrig <- sum(mun_shp$ibge_code %in% irrigacao$ibge_code)
message(sprintf("[info] Municípios casados — solar: %d/%d | irrigação: %d/%d",
                n_solar, nrow(mun_shp), n_irrig, nrow(mun_shp)))
if (n_solar == 0 && n_irrig == 0)
  stop("Nenhum município casou no join. Verifique a chave 'ibge_code' nos ",
       "arquivos processados vs. a coluna '", col_ibge, "' do shapefile.")

mun_data <- mun_shp |>
  left_join(solar_ativo, by = "ibge_code") |>
  left_join(irrigacao,   by = "ibge_code") |>
  mutate(total_capacity_kw = replace_na(total_capacity_kw, 0),
         vol_outorgado     = replace_na(vol_outorgado, 0))

p_map <- ggplot() +
  geom_sf(data = mun_data, aes(fill = total_capacity_kw),
          color = "white", linewidth = 0.2) +
  geom_sf(data = bacia_shp, fill = NA, color = "#2c3e50", linewidth = 0.8) +
  stat_sf_coordinates(
    data = filter(mun_data, vol_outorgado > 0),
    aes(size = vol_outorgado), color = "#e74c3c", alpha = 0.7) +
  scale_fill_viridis_c(option = "mako", direction = -1,
                       name = "Municipal Solar\nCapacity (kW)") +
  scale_size_continuous(name = "Granted Volume\n(Irrigation - m³/year)",
                        range = c(2, 8)) +
  theme_void(base_size = 12) +
  labs(title = "Water-Energy Nexus Topology: UGRHI 6",
       subtitle = "Intersection of solar infrastructure and agricultural water demand") +
  theme(legend.position = "right",
        plot.title = element_text(face = "bold", hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5, color = "grey40",
                                     margin = margin(b = 10)))

save_fig(p_map, "05_map_ugrhi6.pdf", width = 20, height = 14)
message("[ok] Mapa espacial gerado (05_map_ugrhi6.pdf).")