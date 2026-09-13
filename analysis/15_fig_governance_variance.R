library(dplyr)
library(tidyr)
library(ggplot2)
library(here)
if (!requireNamespace("diptest", quietly = TRUE)) install.packages("diptest")
library(diptest)


in_csv  <- here::here("outputs", "tables", "factorial_governance_efficiency_bass.csv")
out_png <- here::here("outputs", "figures", "fig_variance_governance.png")
dir.create(dirname(out_png), recursive = TRUE, showWarnings = FALSE)

raw <- read.csv(in_csv, skip = 6, check.names = FALSE, stringsAsFactors = FALSE)

df <- raw %>%
  transmute(
    climate    = `climate-scenario`,
    governance = `governance-mode`,
    eff        = as.numeric(`efficiency-gain`),
    util       = as.numeric(`initial-utilisation`),
    wf         = as.numeric(`basin-wef-index`)
  ) %>%
  filter(eff == 0, util == 1.3)          # coordination-only, production u = 1.3

stopifnot(nrow(df) > 0)

clim_levels <- c("historical", "ssp245", "ssp585")
clim_labels <- c("Historical", "SSP2-4.5", "SSP5-8.5")
gov_levels  <- c("fragmented", "calibrated-cut", "solar-gating", "integrated")
gov_labels  <- c("Fragmented", "Calibrated-cut", "Solar-gating", "Integrated")
gov_cols    <- c("Fragmented"     = "#E45756",
                 "Calibrated-cut" = "#54A24B",
                 "Solar-gating"   = "#F58518",
                 "Integrated"     = "#4C78A8")

df <- df %>%
  mutate(
    climate    = factor(climate,    levels = clim_levels, labels = clim_labels),
    governance = factor(governance, levels = gov_levels,  labels = gov_labels)
  )

sd_tab <- df %>%
  group_by(climate, governance) %>%
  summarise(sd_wf = sd(wf), n = n(), .groups = "drop")

ratio_tab <- sd_tab %>%
  select(climate, governance, sd_wf) %>%
  pivot_wider(names_from = governance, values_from = sd_wf) %>%
  mutate(`Fragmented / Calibrated-cut` = round(Fragmented / `Calibrated-cut`, 2))

cat("\n== Between-replicate SD of the WF composite (2065) ==\n")
print(as.data.frame(sd_tab), row.names = FALSE)
cat("\n== SD ratio, Fragmented / Calibrated-cut (expect 3.4 / 7.7 / 7.2) ==\n")
print(as.data.frame(ratio_tab[, c("climate", "Fragmented / Calibrated-cut")]),
      row.names = FALSE)

dip_tab <- df %>%
  group_by(climate, governance) %>%
  summarise(dip_p = round(diptest::dip.test(wf)$p.value, 3), .groups = "drop")

cat("\n== Hartigan dip test p-values (higher = not bimodal) ==\n")
cat("   expect fragmented ~0.22-0.63; solar-gating / SSP2-4.5 ~0.003\n")
print(as.data.frame(dip_tab), row.names = FALSE)

p <- ggplot(df, aes(x = wf, colour = governance, fill = governance)) +
  geom_density(alpha = 0.20, linewidth = 0.7) +
  facet_wrap(~ climate, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = gov_cols, name = "Governance") +
  scale_fill_manual(values = gov_cols,  name = "Governance") +
  labs(
    title    = "Predictability is an outcome of governance",
    subtitle = paste0("Fragmented governance widens the between-replicate spread and the ",
                      "low-performance tail;\ncoordinated regimes collapse it"),
    x = "Composite Water\u2013Food index (2065)",
    y = "Density"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position  = "top",
    plot.title       = element_text(face = "bold"),
    strip.text       = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

ggsave(out_png, p, width = 7, height = 8, dpi = 300, bg = "white")
cat("\nSaved:", out_png, "\n")

out_pdf <- here::here("outputs", "figures", "fig_variance_governance.pdf")
ggsave(out_pdf, p, width = 7, height = 8, device = cairo_pdf, bg = "white")
cat("Saved:", out_pdf, "\n")