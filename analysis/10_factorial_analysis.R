suppressPackageStartupMessages({
  library(here); library(dplyr); library(tidyr); library(readr); library(stringr)
  library(ggplot2); library(boot); library(purrr); library(diptest)
})
source(here("analysis", "utils.R"))

save_plot <- function(p, file, width, height) {
  ggsave(here("outputs", "figures", file), p,
         width = width, height = height, units = "cm")
}

bs_path <- here("outputs", "tables", "factorial_governance_efficiency.csv")
stopifnot("Factorial CSV not found" = file.exists(bs_path))

read_behaviorspace <- function(path) {
  raw <- read_csv(path, skip = 6, show_col_types = FALSE)
  names(raw) <- str_replace_all(names(raw), '"', "")
  raw
}
raw <- read_behaviorspace(bs_path)

rename_map <- c(
  run            = "[run number]",
  climate        = "climate-scenario",
  governance     = "governance-mode",
  eps            = "efficiency-gain",
  u              = "initial-utilisation",
  rho            = "rebound-share",
  wf             = "basin-wef-index",
  water          = "basin-water-index",
  food           = "basin-food-index",
  energy         = "basin-energy-index",
  stress_pre     = "mean [water-stress] of municipalities",
  stress_real    = "mean [water-stress-realised] of irrigating-municipalities",
  stress_max     = "max [water-stress] of irrigating-municipalities",
  n_restricted   = "count irrigating-municipalities with [restriction-level > 0]",
  n_over         = "count irrigating-municipalities with [water-stress > stress-threshold]",
  n_irrigating   = "count irrigating-municipalities",
  demanded       = "sum [irrigation-demanded] of farmers",
  applied        = "sum [irrigation-applied] of farmers",
  applied_mogi   = 'sum [irrigation-applied] of farmers with [[muni-name] of home-muni = "MOGI DAS CRUZES"]',
  n_solar        = "count farmers with [has-solar-pump?]",
  n_farmers      = "count farmers",
  urban_pct      = "100 * (sum [area-urban] of municipalities) / (sum [total-area] of municipalities)",
  farming_pct    = "100 * (sum [area-farming] of municipalities) / (sum [total-area] of municipalities)"
)
present <- rename_map[rename_map %in% names(raw)]
missing <- setdiff(c("climate","governance","eps","u","wf","water","food"),
                   names(present))
if (length(missing) > 0)
  stop("Required columns missing from CSV: ",
       paste(rename_map[missing], collapse = " | "),
       "\nDid you declare initial-utilisation / rebound-share in the experiment?")
df <- raw |> select(all_of(present))

df <- df |>
  mutate(
    climate = factor(climate, levels = c("historical", "ssp245", "ssp585"),
                     labels  = c("Historical", "SSP2-4.5", "SSP5-8.5")),
    governance = factor(governance,
                        levels = c("fragmented", "calibrated-cut", "solar-gating", "integrated"),
                        labels = c("Fragmented", "Calibrated cut", "Solar gating", "Integrated")),
    eps_lab = factor(paste0("\u03B5 = ", eps)),
    u_lab   = factor(paste0("u = ", u))
  )

n_rep <- df |> count(climate, governance, eps, u) |> pull(n)
message("[info] ", n_distinct(paste(df$climate, df$governance, df$eps, df$u)),
        " scenarios; replicates per scenario: ", paste(range(n_rep), collapse = "-"))

summ <- df |>
  group_by(climate, governance, eps, u) |>
  summarise(
    n            = n(),
    across(c(wf, water, food, stress_real, stress_max, n_restricted, n_solar, applied),
           list(mean = ~mean(.x), sd = ~sd(.x)), .names = "{.col}_{.fn}"),
    wf_mcse      = sd(wf) / sqrt(n()),
    wf_cv_pct    = 100 * wf_mcse / mean(wf),
    .groups = "drop"
  ) |>
  arrange(u, eps, climate, governance)
write_csv(summ, here("outputs", "tables", "factorial_summary.csv"))

boot_diff <- function(x, y, R = 10000, seed = 20260909) {
  set.seed(seed)
  dat <- data.frame(v = c(x, y), g = rep(c(1, 0), c(length(x), length(y))))
  b <- boot(dat, function(d, i) {
    s <- d[i, ]; mean(s$v[s$g == 1]) - mean(s$v[s$g == 0])
  }, R = R, strata = dat$g)
  ci <- tryCatch(boot.ci(b, type = "bca")$bca[4:5],
                 error = function(e) c(NA_real_, NA_real_))
  c(delta = mean(x) - mean(y), lo = ci[1], hi = ci[2])
}
cohen_d <- function(x, y) {
  sp <- sqrt(((length(x) - 1) * var(x) + (length(y) - 1) * var(y)) /
             (length(x) + length(y) - 2))
  if (sp == 0) return(NA_real_)
  (mean(x) - mean(y)) / sp
}

pillars <- c("wf", "water", "food", "stress_real", "n_restricted", "applied")

effects <- df |>
  group_by(climate, eps, u) |>
  group_modify(function(cell, key) {
    ref <- filter(cell, governance == "Fragmented")
    cell |>
      filter(governance != "Fragmented") |>
      group_by(governance) |>
      group_modify(function(alt, k2) {
        map_dfr(pillars, function(p) {
          x <- alt[[p]]; y <- ref[[p]]
          bd <- boot_diff(x, y)
          tt <- tryCatch(t.test(x, y)$p.value, error = function(e) NA_real_)
          tibble(pillar = p, delta = bd["delta"], ci_lo = bd["lo"], ci_hi = bd["hi"],
                 cohen_d = cohen_d(x, y), welch_p = tt,
                 pct = 100 * bd["delta"] / mean(y))
        })
      }) |> ungroup()
  }) |> ungroup() |>
  mutate(pillar = factor(pillar, levels = pillars)) |>
  arrange(u, eps, climate, governance, pillar)
write_csv(effects, here("outputs", "tables", "factorial_effects.csv"))

eff_effect <- df |>
  group_by(climate, governance, u) |>
  group_modify(function(cell, key) {
    x <- filter(cell, eps == max(eps)); y <- filter(cell, eps == min(eps))
    map_dfr(c("wf", "water", "food"), function(p) {
      bd <- boot_diff(x[[p]], y[[p]])
      tibble(pillar = p, delta = bd["delta"], ci_lo = bd["lo"], ci_hi = bd["hi"],
             cohen_d = cohen_d(x[[p]], y[[p]]))
    })
  }) |> ungroup()
write_csv(eff_effect, here("outputs", "tables", "factorial_efficiency_effect.csv"))

message("\n== Composite WF index by scenario (mean) ==")
summ |> select(u, eps, climate, governance, wf_mean, water_mean, food_mean,
               n_restricted_mean) |>
  mutate(across(where(is.numeric), ~round(.x, 3))) |>
  print(n = Inf)
message("\n== Governance effects on WF (regime - Fragmented) ==")
effects |> filter(pillar == "wf") |>
  select(u, eps, climate, governance, delta, ci_lo, ci_hi, cohen_d) |>
  mutate(across(where(is.numeric), ~round(.x, 4))) |>
  print(n = Inf)

if (!exists("save_plot")) {
  save_plot <- function(p, file, width, height)
    ggsave(here("outputs", "figures", file), p,
           width = width, height = height, units = "cm")
}

pal_gov <- c("Fragmented" = "#d95f02", "Calibrated cut" = "#7570b3",
             "Solar gating" = "#1b9e77", "Integrated" = "#1f78b4")

effects <- effects |>
  mutate(eps_lab = factor(paste0("\u03B5 = ", eps)),
         u_lab   = factor(paste0("u = ", u)))

df13  <- filter(df, u == 1.3)
eff13 <- filter(effects, u == 1.3)

pillar_long <- df13 |>
  select(climate, governance, eps_lab, water, food) |>
  pivot_longer(c(water, food), names_to = "pillar", values_to = "value") |>
  mutate(pillar = factor(pillar, levels = c("water", "food"),
                         labels = c("Water pillar", "Food pillar")))

p_pillars <- ggplot(pillar_long, aes(climate, value, fill = governance)) +
  geom_boxplot(outlier.size = 0.4, width = 0.7,
               position = position_dodge(0.8)) +
  facet_grid(pillar ~ eps_lab, scales = "free_y") +
  scale_fill_manual(values = pal_gov, name = "Governance") +
  labs(x = "Climate scenario", y = "Pillar index value",
       title = "Pillar decomposition by governance regime (u = 1.3)",
       subtitle = "Fragmented governance preserves the water pillar by sacrificing food; coordinated cuts do the reverse. \u03B5 = efficiency gain.") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        panel.border = element_rect(colour = "grey80", fill = NA),
        plot.subtitle = element_text(size = 8.5))
save_plot(p_pillars, "10_factorial_pillars.pdf", width = 22, height = 16)

p_wf <- ggplot(df13, aes(climate, wf, fill = governance)) +
  geom_boxplot(outlier.size = 0.5, width = 0.7,
               position = position_dodge(0.8)) +
  facet_wrap(~ eps_lab, nrow = 1) +
  scale_fill_manual(values = pal_gov, name = "Governance") +
  labs(x = "Climate scenario", y = "Composite Water\u2013Food index",
       title = "Composite WF index by governance regime (u = 1.3)",
       subtitle = "Regimes nearly coincide on the composite: the equally-weighted mean cancels the water\u2013food trade-off shown per pillar.") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        panel.border = element_rect(colour = "grey80", fill = NA),
        plot.subtitle = element_text(size = 8.5))
save_plot(p_wf, "10_factorial_wf.pdf", width = 20, height = 12)

sd_tbl <- df |>
  filter(u == 1.3) |>
  group_by(climate, governance, eps_lab) |>
  summarise(sd_wf = sd(wf), .groups = "drop")

p_sd <- ggplot(sd_tbl, aes(climate, sd_wf, fill = governance)) +
  geom_col(width = 0.7, position = position_dodge(0.8)) +
  facet_wrap(~ eps_lab, nrow = 1) +
  scale_fill_manual(values = pal_gov, name = "Governance") +
  labs(x = "Climate scenario",
       y = "SD of composite WF index across 50 replicates",
       title = "Replicate dispersion of the WF index (u = 1.3)",
       subtitle = "Coordinated cuts deliver a far more predictable outcome; fragmented dispersion grows with climate stress.") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        panel.border = element_rect(colour = "grey80", fill = NA),
        plot.subtitle = element_text(size = 8.5))
save_plot(p_sd, "10_factorial_sd.pdf", width = 20, height = 12)

p_eff <- eff13 |>
  filter(pillar == "wf") |>
  ggplot(aes(climate, delta, colour = governance)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey60") +
  geom_pointrange(aes(ymin = ci_lo, ymax = ci_hi),
                  position = position_dodge(0.5), size = 0.4) +
  facet_wrap(~ eps_lab, nrow = 1) +
  scale_colour_manual(values = pal_gov[-1], name = "Regime vs Fragmented") +
  labs(x = "Climate scenario",
       y = "\u0394 WF (regime \u2212 fragmented), BCa 95% CI",
       title = "Direct governance contrasts on the composite (u = 1.3)") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        panel.border = element_rect(colour = "grey80", fill = NA))
save_plot(p_eff, "10_factorial_effects.pdf", width = 20, height = 12)

p_eff_pillars <- eff13 |>
  filter(pillar %in% c("water", "food")) |>
  mutate(pillar = factor(pillar, levels = c("water", "food"),
                         labels = c("Water pillar", "Food pillar"))) |>
  ggplot(aes(climate, delta, colour = governance)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey60") +
  geom_pointrange(aes(ymin = ci_lo, ymax = ci_hi),
                  position = position_dodge(0.5), size = 0.4) +
  facet_grid(pillar ~ eps_lab, scales = "free_y") +
  scale_colour_manual(values = pal_gov[-1], name = "Regime vs Fragmented") +
  labs(x = "Climate scenario",
       y = "\u0394 pillar (regime \u2212 fragmented), BCa 95% CI",
       title = "Governance contrasts by pillar (u = 1.3)") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        panel.border = element_rect(colour = "grey80", fill = NA))
save_plot(p_eff_pillars, "10_factorial_effects_pillars.pdf", width = 22, height = 16)

message("[done] figures: pillars, wf, sd, effects, effects_pillars")