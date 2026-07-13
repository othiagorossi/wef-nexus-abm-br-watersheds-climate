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
