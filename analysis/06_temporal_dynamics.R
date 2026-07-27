suppressPackageStartupMessages({
  library(here); library(dplyr); library(tidyr); library(ggplot2)
  library(patchwork); library(readr); library(stringr); library(scales)
})
source(here("analysis", "utils.R"))
source(here("analysis", "04_figures.R"))  # save_fig (convenção 300 DPI)

land_raw <- read_csv2(here("data", "processed", "land_cover_shares.csv"),
                      show_col_types = FALSE)

multiplicidade <- land_raw |> count(year, macro_class) |> pull(n) |> max()
message(sprintf("[info] Linhas por (ano, classe): máx = %d", multiplicidade))

if (multiplicidade > 1) {
  # Preferir média ponderada por área municipal, se a coluna existir.
  peso_col <- intersect(c("area_ha", "area_km2", "municipio_area", "area"),
                        names(land_raw))[1]
  land <- land_raw |>
    group_by(year, macro_class) |>
    summarise(
      share_pct = if (!is.na(peso_col))
                    weighted.mean(share_pct, .data[[peso_col]], na.rm = TRUE)
                  else mean(share_pct, na.rm = TRUE),
      .groups = "drop")
  if (is.na(peso_col))
    warning("Sem coluna de área — usando média simples dos shares municipais.")
} else {
  land <- land_raw
}

soma_chk <- land |> group_by(year) |>
  summarise(tot = sum(share_pct, na.rm = TRUE), .groups = "drop") |> pull(tot)
message(sprintf("[info] Soma dos shares por ano: %.1f–%.1f%%",
                min(soma_chk), max(soma_chk)))

cores_uso <- c(
  native_vegetation = "#2E7D32", farming = "#E1A100",
  non_vegetated_other = "#A6761D", urban = "#E31A1C",
  water = "#1F78B4", fotovoltaica = "#984EA3")
rotulos_uso <- c(
  native_vegetation = "Native vegetation", farming = "Farming",
  non_vegetated_other = "Other non-vegetated", urban = "Urban",
  water = "Water", fotovoltaica = "Photovoltaic")
classes <- unique(land$macro_class)
faltam  <- setdiff(classes, names(cores_uso))
if (length(faltam) > 0) {
  cores_uso[faltam]   <- scales::hue_pal()(length(faltam))
  rotulos_uso[faltam] <- str_to_sentence(gsub("_", " ", faltam))
}

ordem <- land |> group_by(macro_class) |>
  summarise(m = mean(share_pct, na.rm = TRUE), .groups = "drop") |>
  arrange(desc(m)) |> pull(macro_class)
land$macro_class <- factor(land$macro_class, levels = ordem)

p_land <- ggplot(land, aes(year, share_pct, color = macro_class)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 1.1, alpha = 0.7) +
  scale_color_manual(values = cores_uso, labels = rotulos_uso[ordem],
                     breaks = ordem, name = NULL) +
  scale_x_continuous(breaks = seq(1985, 2025, 10)) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
  labs(title = "Land-Use Trajectories",
       subtitle = "Territorial coverage share by class (1985-2024)",
       x = "Year", y = "% of Basin") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank()) +
  guides(color = guide_legend(nrow = 2))

# ── 2. Adoção solar (ANEEL) — curva S acumulada, eixo único ──────────────────
solar_ann <- read_csv2(here("data", "processed", "solar_dg_annual.csv"),
                       show_col_types = FALSE)

p_solar <- ggplot(solar_ann, aes(year, cum_installations)) +
  geom_area(fill = "#F5CBA7", alpha = 0.55) +
  geom_line(color = "#B8500A", linewidth = 1.2) +
  geom_point(color = "#B8500A", size = 1.4) +
  scale_x_continuous(breaks = scales::breaks_pretty(n = 5)) +
  scale_y_continuous(labels = scales::label_comma(),
                     limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
  labs(title = "PV Adoption Curve",
       subtitle = "Cumulative distributed-generation systems in the basin",
       x = "Year", y = "Cumulative installations") +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank())

p_combo <- p_land + p_solar +
  plot_layout(ncol = 2, widths = c(1.1, 1)) +
  plot_annotation(tag_levels = "A")

save_fig(p_combo, "06_temporal_trajectories.pdf", width = 26, height = 11)
message("[ok] Dinâmicas temporais (lado a lado) geradas (06_temporal_trajectories.pdf).")