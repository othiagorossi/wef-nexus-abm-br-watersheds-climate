suppressPackageStartupMessages({
  library(here); library(dplyr); library(tidyr); library(readr)
  library(stringr); library(ggplot2)
})
source(here("analysis", "utils.R"))

bs_path <- here("outputs", "tables", "behaviorspace_scenarios.csv")
stopifnot("BehaviorSpace CSV not found" = file.exists(bs_path))

raw <- read_csv(bs_path, skip = 6, show_col_types = FALSE,
                name_repair = "minimal")

dat <- raw
names(dat)[1:12] <- c(
  "run", "climate", "governance", "hectares_per_farmer", "step",
  "water_stress", "irrigation", "solar_pumps",
  "urban_pct", "farming_pct", "n_farmers", "year"
)
dat <- dat |>
  mutate(across(c(water_stress, irrigation, solar_pumps,
                  urban_pct, farming_pct, n_farmers, year),
                as.numeric))

dat <- dat |>
  mutate(
    scenario = case_when(
      climate == "historical" & governance == "fragmented" ~ "S0 hist/frag",
      climate == "ssp245"     & governance == "fragmented" ~ "S1 ssp245/frag",
      climate == "ssp585"     & governance == "fragmented" ~ "S2 ssp585/frag",
      climate == "historical" & governance == "integrated" ~ "S3 hist/integ",
      climate == "ssp245"     & governance == "integrated" ~ "S4 ssp245/integ",
      climate == "ssp585"     & governance == "integrated" ~ "S5 ssp585/integ",
      TRUE ~ paste(climate, governance)
    )
  )

message("Runs loaded: ", nrow(dat),
        " (", n_distinct(dat$scenario), " scenarios)")
message("Replicates per scenario:")
print(count(dat, scenario))

ci95 <- function(x) 1.96 * sd(x) / sqrt(length(x))

summ <- dat |>
  group_by(scenario, climate, governance) |>
  summarise(
    n            = n(),
    stress_mean  = mean(water_stress),
    stress_ci    = ci95(water_stress),
    irrig_mean   = mean(irrigation),
    irrig_ci     = ci95(irrigation),
    solar_mean   = mean(solar_pumps),
    urban_mean   = mean(urban_pct),
    farming_mean = mean(farming_pct),
    .groups = "drop"
  ) |>
  arrange(scenario)

message("\n== SCENARIO SUMMARY (mean +/- 95% CI) ==")
summ |>
  transmute(
    scenario,
    water_stress = sprintf("%.2f ± %.2f", stress_mean, stress_ci),
    irrigation   = sprintf("%.0f ± %.0f", irrig_mean, irrig_ci),
    solar_pumps  = sprintf("%.0f", solar_mean),
    urban_pct    = sprintf("%.1f", urban_mean),
    farming_pct  = sprintf("%.1f", farming_mean)
  ) |>
  print(width = Inf)

write_csv(summ, here("outputs", "tables", "scenario_summary.csv"))

message("\n== H1: climate effect on water stress (fragmented) ==")
frag <- filter(dat, governance == "fragmented")
print(
  pairwise.t.test(frag$water_stress, frag$climate,
                  p.adjust.method = "holm")
)

message("\n== H2: governance effect on water stress (per climate) ==")
for (cl in unique(dat$climate)) {
  sub <- filter(dat, climate == cl)
  tt <- t.test(water_stress ~ governance, data = sub)
  message(sprintf("  %-10s frag=%.2f integ=%.2f  diff=%.2f  p=%.4g",
                  cl,
                  mean(sub$water_stress[sub$governance == "fragmented"]),
                  mean(sub$water_stress[sub$governance == "integrated"]),
                  diff(rev(tapply(sub$water_stress, sub$governance, mean))),
                  tt$p.value))
}

p <- ggplot(summ, aes(x = reorder(scenario, stress_mean), y = stress_mean,
                      fill = governance)) +
  geom_col(width = 0.7) +
  geom_errorbar(aes(ymin = stress_mean - stress_ci,
                    ymax = stress_mean + stress_ci), width = 0.2) +
  coord_flip() +
  labs(title = "Water stress by scenario (50 replicates each)",
       subtitle = "Mean ± 95% CI",
       x = NULL, y = "Mean water stress", fill = "Governance") +
  theme_minimal(base_size = 11)

ggsave(here("outputs", "figures", "scenario_water_stress.pdf"),
       p, width = 18, height = 10, units = "cm")
message("\n[ok] Figure: outputs/figures/scenario_water_stress.pdf")
message("[done] 02_scenario_analysis.R")
