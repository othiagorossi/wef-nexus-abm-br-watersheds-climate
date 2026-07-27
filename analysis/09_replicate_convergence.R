suppressPackageStartupMessages({
  library(here); library(dplyr); library(tidyr); library(ggplot2)
  library(patchwork); library(readr)
})
source(here("analysis", "04_figures.R"))  # PALETTE, SCENARIO_LABELS, save_fig

N_SEQ <- seq(5, 50, by = 5)   # eixo X da curva de convergência

bs_path <- here("outputs", "tables", "behaviorspace_scenarios.csv")
if (!file.exists(bs_path)) stop("CSV do BehaviorSpace não encontrado: ", bs_path)

raw <- read_csv(bs_path, skip = 6, show_col_types = FALSE, name_repair = "minimal")
expected <- c("run", "climate", "governance", "hectares_per_farmer", "step",
              "water_stress", "irrigation", "solar_pumps", "urban_pct", "farming_pct",
              "n_farmers", "year", "wef_index", "water_index", "energy_index", "food_index")
names(raw)[seq_len(min(ncol(raw), length(expected)))] <-
  expected[seq_len(min(ncol(raw), length(expected)))]

num_cols <- setdiff(expected, c("run", "climate", "governance"))
dat <- raw |>
  mutate(across(all_of(num_cols), as.numeric),
         scenario = case_when(
           climate == "historical" & governance == "fragmented" ~ "S0",
           climate == "ssp245"     & governance == "fragmented" ~ "S1",
           climate == "ssp585"     & governance == "fragmented" ~ "S2",
           climate == "historical" & governance == "integrated" ~ "S3",
           climate == "ssp245"     & governance == "integrated" ~ "S4",
           climate == "ssp585"     & governance == "integrated" ~ "S5",
           TRUE ~ "Other")) |>
  filter(scenario != "Other")

if (nrow(dat) == 0) stop("Nenhuma linha após o mapeamento de cenários.")

ano_final <- max(dat$year, na.rm = TRUE)
ss <- dat |>
  filter(year == ano_final) |>
  mutate(wf = if (all(c("water_index", "food_index") %in% names(dat)))
                (water_index + food_index) / 2 else wef_index) |>
  select(scenario, run, wf) |>
  distinct(scenario, run, .keep_all = TRUE)

n_rep <- ss |> count(scenario) |> summarise(m = min(n)) |> pull(m)
message(sprintf("[info] Réplicas disponíveis por cenário (mín.): %d", n_rep))
N_SEQ <- N_SEQ[N_SEQ <= n_rep]

sd_cen <- ss |>
  group_by(scenario) |>
  summarise(s = sd(wf), media = mean(wf), .groups = "drop")

conv_media <- sd_cen |>
  crossing(N = N_SEQ) |>
  mutate(se = s / sqrt(N),
         cv_pct = 100 * se / abs(media)) |>
  select(scenario, N, se, media, cv_pct)

s_lk <- setNames(sd_cen$s,     sd_cen$scenario)
m_lk <- setNames(sd_cen$media, sd_cen$scenario)

pares <- tribble(
  ~contraste,    ~frag, ~integ,
  "Historical",  "S0",  "S3",
  "SSP2-4.5",    "S1",  "S4",
  "SSP5-8.5",    "S2",  "S5")

conv_delta <- pares |>
  filter(frag %in% names(s_lk), integ %in% names(s_lk)) |>
  crossing(N = N_SEQ) |>
  mutate(delta = m_lk[integ] - m_lk[frag],
         se    = sqrt(s_lk[frag]^2 / N + s_lk[integ]^2 / N)) |>
  select(contraste, N, se, delta)

p_cv <- ggplot(conv_media, aes(N, cv_pct, color = scenario)) +
  geom_line(linewidth = 0.9) + geom_point(size = 1.8) +
  scale_color_manual(values = PALETTE, labels = SCENARIO_LABELS) +
  scale_x_continuous(breaks = N_SEQ) +
  scale_y_continuous(limits = c(0, NA)) +
  labs(title = "Monte Carlo Error Convergence",
       subtitle = "CV of the composite index (water + food) mean vs. number of replicates",
       x = "Number of replicates (N)", y = "Coefficient of variation (%)",
       color = NULL) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

p_delta <- ggplot(conv_delta, aes(N, se, color = contraste)) +
  geom_line(linewidth = 0.9) + geom_point(size = 1.8) +
  scale_x_continuous(breaks = N_SEQ) +
  scale_y_continuous(limits = c(0, NA)) +
  labs(title = "Effect Stability",
       subtitle = "Standard error of the governance contrast vs. number of replicates",
       x = "Number of replicates (N)",
       y = expression("Standard error of " * Delta), color = NULL) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

p_conv <- p_cv + p_delta + plot_annotation(tag_levels = "A")
save_fig(p_conv, "09_replicas_convergencia.pdf", width = 26, height = 12)

write_csv(
  bind_rows(
    conv_media |> transmute(type = "mean",  group = scenario,  N, se, value = media, cv_pct),
    conv_delta |> transmute(type = "delta", group = contraste, N, se, value = delta, cv_pct = NA)),
  here("outputs", "tables", "replicas_convergencia.csv"))

cat("\n== ERRO DE MONTE CARLO EM N = 50 ==\n")
conv_media |> filter(N == max(N)) |>
  transmute(scenario, media = round(media, 4), se = round(se, 5),
            cv_pct = round(cv_pct, 3)) |> print(n = Inf)
cat("\n-- Delta (integrada - fragmentada) em N = 50 --\n")
conv_delta |> filter(N == max(N)) |>
  transmute(contraste, delta = round(delta, 4), se = round(se, 5),
            ratio = round(abs(delta) / se, 1)) |> print(n = Inf)
cat("\n[ok] Figura 09 e tabela de convergência geradas.\n\n")