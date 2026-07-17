suppressPackageStartupMessages({
  library(here); library(dplyr); library(tidyr); library(readr)
  library(stringr); library(ggplot2)
})
source(here("analysis", "utils.R"))

bs_path <- here("outputs", "tables", "behaviorspace_scenarios.csv")
stopifnot("BehaviorSpace CSV not found" = file.exists(bs_path))

raw <- read_csv(bs_path, skip = 6, show_col_types = FALSE, name_repair = "minimal")

expected <- c(
  "run", "climate", "governance", "hectares_per_farmer", "step",
  "water_stress", "irrigation", "solar_pumps",
  "urban_pct", "farming_pct", "n_farmers", "year",
  "wef_index", "water_index", "energy_index", "food_index"
)
names(raw)[seq_len(min(ncol(raw), length(expected)))] <-
  expected[seq_len(min(ncol(raw), length(expected)))]

num_cols <- intersect(
  c("water_stress","irrigation","solar_pumps","urban_pct","farming_pct",
    "n_farmers","year","wef_index","water_index","energy_index","food_index"),
  names(raw))

dat <- raw |>
  mutate(across(all_of(num_cols), as.numeric)) |>
  mutate(scenario = case_when(
    climate=="historical" & governance=="fragmented" ~ "S0 hist/frag",
    climate=="ssp245"     & governance=="fragmented" ~ "S1 ssp245/frag",
    climate=="ssp585"     & governance=="fragmented" ~ "S2 ssp585/frag",
    climate=="historical" & governance=="integrated" ~ "S3 hist/integ",
    climate=="ssp245"     & governance=="integrated" ~ "S4 ssp245/integ",
    climate=="ssp585"     & governance=="integrated" ~ "S5 ssp585/integ",
    TRUE ~ paste(climate, governance)))

message("Runs loaded: ", nrow(dat), " (", n_distinct(dat$scenario), " scenarios)")
print(count(dat, scenario))

ci95 <- function(x) 1.96 * sd(x) / sqrt(length(x))
fmt  <- function(m, c) sprintf("%.3f ± %.3f", m, c)

summ <- dat |>
  group_by(scenario, climate, governance) |>
  summarise(
    n = n(),
    stress_m = mean(water_stress), stress_ci = ci95(water_stress),
    wef_m   = mean(wef_index),   wef_ci   = ci95(wef_index),
    water_m = mean(water_index), water_ci = ci95(water_index),
    food_m  = mean(food_index),  food_ci  = ci95(food_index),
    energy_m = mean(energy_index),
    solar_m  = mean(solar_pumps),
    .groups = "drop") |>
  arrange(scenario)

message("\n== SCENARIO SUMMARY (mean ± 95% CI) ==")
summ |>
  transmute(scenario,
            water_stress = fmt(stress_m, stress_ci),
            `WF index`   = fmt(wef_m, wef_ci),
            water        = fmt(water_m, water_ci),
            food         = fmt(food_m, food_ci),
            `solar (desc)` = sprintf("%.0f", solar_m)) |>
  print(width = Inf)

write_csv(summ, here("outputs","tables","scenario_summary.csv"))

message("\n== Governance effect on WF composite (per climate) ==")
for (cl in unique(dat$climate)) {
  sub <- filter(dat, climate == cl)
  tt <- t.test(wef_index ~ governance, data = sub)
  mf <- mean(sub$wef_index[sub$governance=="fragmented"])
  mi <- mean(sub$wef_index[sub$governance=="integrated"])
  message(sprintf("  %-10s frag=%.3f integ=%.3f diff=%+.3f p=%.4g",
                  cl, mf, mi, mi-mf, tt$p.value))
}

message("\n== Governance effect per pillar (historical) ==")
sub <- filter(dat, climate == "historical")
for (pil in c("water_index","food_index")) {
  mf <- mean(sub[[pil]][sub$governance=="fragmented"])
  mi <- mean(sub[[pil]][sub$governance=="integrated"])
  if (sd(sub[[pil]]) < 1e-9) {
    message(sprintf("  %-12s constant at %.3f (no test)", pil, mf))
  } else {
    tt <- t.test(sub[[pil]] ~ sub$governance)
    message(sprintf("  %-12s frag=%.3f integ=%.3f diff=%+.3f p=%.4g",
                    pil, mf, mi, mi-mf, tt$p.value))
  }
}

message("\n== Climate effect on WF composite (fragmented) ==")
frag <- filter(dat, governance == "fragmented")
print(pairwise.t.test(frag$wef_index, frag$climate, p.adjust.method = "holm"))

p1 <- ggplot(summ, aes(reorder(scenario, wef_m), wef_m, fill = governance)) +
  geom_col(width=.7) +
  geom_errorbar(aes(ymin=wef_m-wef_ci, ymax=wef_m+wef_ci), width=.2) +
  coord_flip() +
  labs(title="Water–Food nexus performance by scenario",
       subtitle="Mean ± 95% CI, 50 replicates. Energy adoption is the rebound driver (reported separately).",
       x=NULL, y="WF composite index [0–1]", fill="Governance") +
  theme_minimal(base_size=11)
ggsave(here("outputs","figures","scenario_composite.pdf"), p1,
       width=19, height=10, units="cm")

pill <- summ |>
  select(scenario, governance, water=water_m, food=food_m) |>
  pivot_longer(c(water,food), names_to="pillar", values_to="value")
p2 <- ggplot(pill, aes(scenario, value, fill=pillar)) +
  geom_col(position="dodge") + coord_flip() +
  labs(title="Water and food pillars by scenario",
       x=NULL, y="Index [0–1]", fill="Pillar") +
  theme_minimal(base_size=11)
ggsave(here("outputs","figures","scenario_pillars.pdf"), p2,
       width=19, height=11, units="cm")

message("\n[ok] Figures: scenario_composite.pdf, scenario_pillars.pdf")
message("[done] 02_scenario_analysis.R")