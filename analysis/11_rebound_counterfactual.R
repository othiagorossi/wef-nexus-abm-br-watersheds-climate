suppressPackageStartupMessages({
  library(here); library(dplyr); library(tidyr); library(readr); library(stringr)
  library(ggplot2); library(boot); library(purrr)
})
source(here("analysis", "utils.R"))
if (!exists("save_plot"))
  save_plot <- function(p, file, width, height)
    ggsave(here("outputs", "figures", file), p, width = width, height = height, units = "cm")

read_bs <- function(path) {
  raw <- read_csv(path, skip = 6, show_col_types = FALSE)
  names(raw) <- str_replace_all(names(raw), '"', "")
  raw
}
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
clab <- function(x) factor(x, levels = c("historical","ssp245","ssp585"),
                           labels = c("Historical","SSP2-4.5","SSP5-8.5"))

c4 <- read_bs(here("outputs", "tables", "solar_counterfactual.csv"))
pick <- function(df, pat) { h <- grep(pat, names(df), value = TRUE); h[1] }
c4 <- c4 |>
  rename(
    climate    = "climate-scenario",
    governance = "governance-mode",
    max_solar  = "max-solar-adoption",
    wf   = "basin-wef-index",
    water= "basin-water-index",
    food = "basin-food-index"
  ) |>
  rename(
    stress_real = !!pick(c4, "^mean \\[water-stress-realised\\] of irrig"),
    d_solar     = !!pick(c4, "^demand-per-ha-solar"),
    d_nosolar   = !!pick(c4, "^demand-per-ha-nosolar"),
    n_gb_solar  = !!pick(c4, "^count green-belt")
  ) |>
  mutate(solar = if_else(max_solar > 0, "Solar on", "Solar off"),
         climate = clab(climate))

c4_eff <- c4 |>
  group_by(climate, governance) |>
  group_modify(function(cell, key) {
    on  <- filter(cell, solar == "Solar on")
    off <- filter(cell, solar == "Solar off")
    map_dfr(c("wf","water","food","stress_real"), function(p) {
      bd <- boot_diff(on[[p]], off[[p]])
      tibble(pillar = p, delta = bd["delta"], ci_lo = bd["lo"], ci_hi = bd["hi"],
             mean_off = mean(off[[p]]), mean_on = mean(on[[p]]))
    })
  }) |> ungroup()
write_csv(c4_eff, here("outputs", "tables", "rebound_counterfactual.csv"))

gb <- c4 |>
  filter(solar == "Solar on") |>
  group_by(climate, governance) |>
  summarise(d_solar   = mean(d_solar),
            d_nosolar = mean(d_nosolar),
            rebound_ratio = mean(d_solar) / mean(d_nosolar),
            n_gb_solar = mean(n_gb_solar), .groups = "drop")
write_csv(gb, here("outputs", "tables", "rebound_greenbelt.csv"))

message("== Rebound ratio (green-belt demand/ha, solar vs no-solar) ==")
print(gb |> mutate(across(where(is.numeric), ~round(.x, 3))), n = Inf)
message("\n== Solar on-off effect on WF and water pillar ==")
print(c4_eff |> filter(pillar %in% c("wf","water")) |>
        mutate(across(where(is.numeric), ~round(.x, 4))), n = Inf)

c3 <- read_bs(here("outputs", "tables", "efficiency_rebound.csv")) |>
  rename(
    climate    = "climate-scenario",
    governance = "governance-mode",
    rho        = "rebound-share",
    wf   = "basin-wef-index",
    water= "basin-water-index",
    food = "basin-food-index"
  ) |>
  mutate(climate = clab(climate))

c3_summ <- c3 |>
  group_by(climate, governance, rho) |>
  summarise(across(c(wf, water, food),
                   list(mean = mean, sd = sd), .names = "{.col}_{.fn}"),
            .groups = "drop")
write_csv(c3_summ, here("outputs", "tables", "efficiency_reabsorption.csv"))

message("\n== Efficiency reabsorption: WF by rebound-share ==")
print(c3_summ |> select(climate, governance, rho, wf_mean, food_mean) |>
        mutate(across(where(is.numeric), ~round(.x, 3))), n = Inf)

pal_gov <- c("fragmented" = "#d95f02", "integrated" = "#1f78b4")

p_cf <- c4 |>
  select(climate, governance, solar, water, food) |>
  pivot_longer(c(water, food), names_to = "pillar", values_to = "value") |>
  mutate(pillar = factor(pillar, c("water","food"),
                         c("Water pillar","Food pillar"))) |>
  ggplot(aes(climate, value, fill = interaction(governance, solar, sep = " / "))) +
  geom_boxplot(outlier.size = 0.3, width = 0.75, position = position_dodge(0.85)) +
  facet_wrap(~ pillar, scales = "free_y") +
  scale_fill_brewer(palette = "Paired", name = NULL) +
  labs(x = "Climate scenario", y = "Pillar index",
       title = "Solar counterfactual: enabling PV pumping shifts the water pillar",
       subtitle = "max-solar-adoption 0 (off) vs 0.2 (on); u = 1.3, \u03B5 = 0") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        panel.border = element_rect(colour = "grey80", fill = NA),
        plot.subtitle = element_text(size = 8.5))
save_plot(p_cf, "11_rebound_counterfactual.pdf", width = 22, height = 13)

p_re <- c3_summ |>
  ggplot(aes(rho, wf_mean, colour = governance)) +
  geom_line(linewidth = 0.7) + geom_point(size = 2) +
  facet_wrap(~ climate) +
  scale_colour_manual(values = pal_gov, name = "Governance") +
  labs(x = "Rebound share \u03C1 (fraction of efficiency saving reabsorbed)",
       y = "Composite WF index",
       title = "Efficiency gain only avoids the trade-off if not reabsorbed",
       subtitle = "\u03B5 = 0.3, u = 1.3; \u03C1 = 0 full saving, \u03C1 = 1 Jevons-complete rebound") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        panel.border = element_rect(colour = "grey80", fill = NA),
        plot.subtitle = element_text(size = 8.5))
save_plot(p_re, "11_efficiency_reabsorption.pdf", width = 20, height = 10)

message("\n[done] 11_rebound_counterfactual.R")