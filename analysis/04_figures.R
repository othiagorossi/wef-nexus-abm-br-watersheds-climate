# 04_figures.R
# Generates all manuscript figures — 300 DPI PDF, UTF-8
# Output: outputs/figures/

library(tidyverse)
library(patchwork)

DIR_OUT <- here::here("outputs", "figures")
SCENARIOS <- c("S0", "S1", "S2", "S3", "S4")
SCENARIO_LABELS <- c(
  S0 = "Baseline (Historical)",
  S1 = "SSP2-4.5 / Fragmented",
  S2 = "SSP5-8.5 / Fragmented",
  S3 = "SSP2-4.5 / Integrated",
  S4 = "SSP5-8.5 / Integrated"
)

PALETTE <- c(
  S0 = "#404040",
  S1 = "#2166AC",
  S2 = "#D73027",
  S3 = "#4DAC26",
  S4 = "#F1A340"
)

save_fig <- function(plot, filename, width = 18, height = 12) {
  ggsave(
    filename  = file.path(DIR_OUT, filename),
    plot      = plot,
    device    = "pdf",
    width     = width,
    height    = height,
    units     = "cm",
    dpi       = 300
  )
  message("Saved: ", filename)
}

# ── Fig 1: Study area map ──────────────────────────────────────────────────
# TODO: map of study basin (sf + ggplot2 + terra)
# fig1 <- ggplot() + ...
# save_fig(fig1, "fig1_study_area.pdf", width = 12, height = 14)

# ── Fig 2: WEF index temporal dynamics ────────────────────────────────────
# TODO: line plot of wef_index over time by scenario
# wef <- read_csv(here::here("outputs", "tables", "wef_index_monthly.csv"))
# fig2 <- ggplot(wef, aes(x = date, y = wef_index, color = scenario)) +
#   geom_line(linewidth = 0.8) +
#   scale_color_manual(values = PALETTE, labels = SCENARIO_LABELS) +
#   labs(title = "WEF Composite Index by Scenario",
#        x = NULL, y = "WEF Index [0–1]", color = NULL) +
#   theme_minimal(base_size = 10)
# save_fig(fig2, "fig2_wef_index.pdf")

# ── Fig 3: Solar rebound effect ────────────────────────────────────────────
# TODO: scatter/line of water withdrawal vs. solar adoption rate
# save_fig(fig3, "fig3_rebound_effect.pdf")

# ── Fig 4: Land use transition ─────────────────────────────────────────────
# TODO: stacked area chart of lulc shares over time by scenario
# save_fig(fig4, "fig4_land_use_transition.pdf")

# ── Fig 5: Sensitivity analysis ────────────────────────────────────────────
# TODO: heatmap or tornado chart of Sobol indices
# library(sensitivity)
# save_fig(fig5, "fig5_sensitivity.pdf")

message("04_figures.R: all figure sections are TODOs.")
message("Implement after model runs (Phase 4).")
