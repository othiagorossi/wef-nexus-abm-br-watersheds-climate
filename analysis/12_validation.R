suppressPackageStartupMessages({
  library(here); library(dplyr); library(tidyr); library(readr); library(stringr)
  library(ggplot2)
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
pick <- function(df, pat) { h <- grep(pat, names(df), value = TRUE); h[1] }

CALIB_END <- 2004   # calibration window 1985-2004; validation 2005-2024

sim <- read_bs(here("outputs", "tables", "validation_timeseries.csv"))
sim <- sim |>
  rename(
    year      = "current-year",
    urban     = !!pick(sim, "area-urban"),
    farming   = !!pick(sim, "area-farming"),
    n_solar   = !!pick(sim, "count farmers with \\[has-solar")
  ) |>
  filter(year <= 2024) |>
  group_by(year) |>
  summarise(urban_sim   = mean(urban),
            farming_sim = mean(farming),
            urban_lo = quantile(urban, 0.025), urban_hi = quantile(urban, 0.975),
            farm_lo  = quantile(farming, 0.025), farm_hi = quantile(farming, 0.975),
            solar_sim = mean(n_solar), .groups = "drop")

obs_lc <- read_csv(here("data", "model_inputs", "validation_land_cover.csv"),
                   show_col_types = FALSE) |>
  select(year, urban_obs = urban, farming_obs = farming) |>
  filter(year <= 2024)

lc <- inner_join(sim, obs_lc, by = "year") |>
  mutate(window = if_else(year <= CALIB_END, "calibration", "validation"))

fit_stats <- function(df, sim_col, obs_col) {
  df |>
    group_by(window) |>
    summarise(rmse = sqrt(mean((.data[[sim_col]] - .data[[obs_col]])^2)),
              mae  = mean(abs(.data[[sim_col]] - .data[[obs_col]])),
              bias = mean(.data[[sim_col]] - .data[[obs_col]]),
              .groups = "drop") |>
    mutate(series = sim_col)
}
lc_fit <- bind_rows(
  fit_stats(lc, "urban_sim",   "urban_obs"),
  fit_stats(lc, "farming_sim", "farming_obs")
)
lc_fit_all <- bind_rows(
  lc |> summarise(window="1985-2024",
                  rmse=sqrt(mean((urban_sim-urban_obs)^2)),
                  mae=mean(abs(urban_sim-urban_obs)),
                  bias=mean(urban_sim-urban_obs)) |> mutate(series="urban_sim"),
  lc |> summarise(window="1985-2024",
                  rmse=sqrt(mean((farming_sim-farming_obs)^2)),
                  mae=mean(abs(farming_sim-farming_obs)),
                  bias=mean(farming_sim-farming_obs)) |> mutate(series="farming_sim")
)
lc_fit <- bind_rows(lc_fit, lc_fit_all)
write_csv(lc_fit, here("outputs", "tables", "validation_landcover_fit.csv"))
message("== Land-cover fit (percentage points) ==")
print(lc_fit |> mutate(across(where(is.numeric), ~round(.x, 3))), n = Inf)

obs_solar <- read_csv(here("data", "model_inputs", "validation_solar_adoption.csv"),
                      show_col_types = FALSE)
obs_solar <- obs_solar |>
  arrange(year) |>
  mutate(cum_rural = cumsum(n_rural)) |>
  select(year, cum_rural)

solar <- inner_join(sim |> select(year, solar_sim), obs_solar, by = "year")
solar_fit <- solar |>
  summarise(rmse = sqrt(mean((solar_sim - cum_rural)^2)),
            mae  = mean(abs(solar_sim - cum_rural)),
            final_sim = solar_sim[which.max(year)],
            final_obs = cum_rural[which.max(year)])
write_csv(solar_fit, here("outputs", "tables", "validation_solar_fit.csv"))
message("\n== Rural solar adoption fit (installations) ==")
print(solar_fit |> mutate(across(where(is.numeric), ~round(.x, 1))))

lc_long <- lc |>
  select(year, urban_sim, urban_obs, farming_sim, farming_obs) |>
  pivot_longer(-year,
               names_to = c("class", ".value"),
               names_pattern = "(urban|farming)_(sim|obs)") |>
  mutate(class = factor(class, c("urban","farming"),
                        c("Urban","Farming")))
band <- lc |> select(year, urban_lo, urban_hi, farm_lo, farm_hi) |>
  pivot_longer(-year, names_to = c("class",".value"),
               names_pattern = "(urban|farm)_(lo|hi)") |>
  mutate(class = factor(class, c("urban","farm"), c("Urban","Farming")))

p_lc <- ggplot(lc_long, aes(year)) +
  geom_ribbon(data = band, aes(ymin = lo, ymax = hi), fill = "grey80", alpha = 0.5) +
  geom_line(aes(y = sim, colour = "Simulated"), linewidth = 0.7) +
  geom_point(aes(y = obs, colour = "Observed"), size = 1) +
  geom_vline(xintercept = CALIB_END + 0.5, linetype = "dashed", colour = "grey50") +
  facet_wrap(~ class, scales = "free_y") +
  scale_colour_manual(values = c("Simulated" = "#1f78b4", "Observed" = "#333333"),
                      name = NULL) +
  labs(x = NULL, y = "% of basin area",
       title = "Observed vs simulated land cover, 1985\u20132024",
       subtitle = "Dashed line: calibration (\u22642004) / validation (\u22652005) split; band = 95% of replicates") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        panel.border = element_rect(colour = "grey80", fill = NA),
        plot.subtitle = element_text(size = 8.5))
save_plot(p_lc, "12_validation_landcover.pdf", width = 22, height = 12)

p_solar <- ggplot(solar, aes(year)) +
  geom_line(aes(y = solar_sim, colour = "Simulated"), linewidth = 0.7) +
  geom_point(aes(y = cum_rural, colour = "Observed (ANEEL rural)"), size = 1.4) +
  scale_colour_manual(values = c("Simulated" = "#1f78b4",
                                 "Observed (ANEEL rural)" = "#333333"), name = NULL) +
  labs(x = NULL, y = "Cumulative rural solar adopters",
       title = "Simulated solar-pump diffusion vs observed rural PV adoption",
       subtitle = "Validation target is ANEEL rural-class installations, not all distributed generation (cf. Fig. 2B)") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        panel.border = element_rect(colour = "grey80", fill = NA),
        plot.subtitle = element_text(size = 8.5))
save_plot(p_solar, "12_validation_solar.pdf", width = 20, height = 11)
save_plot(p_solar, "12_validation_solar.png", width = 20, height = 11, dpi = 300)

message("\n[done] 12_validation.R")