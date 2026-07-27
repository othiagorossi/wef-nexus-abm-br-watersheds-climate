library(tidyverse)
library(patchwork)

DIR_OUT <- here::here("outputs", "figures")
SCENARIOS <- c("S0", "S1", "S2", "S3", "S4")
SCENARIO_LABELS <- c(
  S0 = "Historical · Fragmented",
  S1 = "SSP2-4.5 · Fragmented",
  S2 = "SSP5-8.5 · Fragmented",
  S3 = "Historical · Integrated",
  S4 = "SSP2-4.5 · Integrated",
  S5 = "SSP5-8.5 · Integrated"
)

PALETTE <- c(
  S0 = "#FDBE85",  # Historical  · Fragmented
  S1 = "#FD8D3C",  # SSP2-4.5    · Fragmented
  S2 = "#D94701",  # SSP5-8.5    · Fragmented
  S3 = "#BDD7E7",  # Historical  · Integrated
  S4 = "#6BAED6",  # SSP2-4.5    · Integrated
  S5 = "#2171B5"   # SSP5-8.5    · Integrated
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
