# Output: outputs/tables/morris_mu_sigma.csv
#         outputs/figures/morris_wef.pdf, morris_stress.pdf

suppressPackageStartupMessages({
  library(here); library(dplyr); library(tidyr); library(readr)
  library(ggplot2); library(sensitivity); library(logolink)
})
source(here("analysis", "utils.R"))

set.seed(20260716)
model_path <- here("model", "wef_nexus_watershed_alto_tiete.nlogox")
stopifnot("Model file not found" = file.exists(model_path))

params <- tibble::tribble(
  ~name,                          ~min,    ~max,
  "et-sensitivity",               0.02,    0.08,
  "integrated-efficiency-gain",   0.15,    0.45,
  "solar-imitation-coef",         0.15,    0.35,
  "max-solar-adoption",           0.10,    0.30,
  "base-conversion-rate",         0.0008,  0.0020,
  "stress-threshold",             0.60,    1.00,
  "restriction-strength",         0.30,    0.70
)

# ── Morris design ───────────────────────────────────────────────────────────
r_traj <- 30
n_levels <- 6
design <- morris(
  model = NULL,
  factors = params$name,
  r = r_traj,
  design = list(type = "oat", levels = n_levels, grid.jump = n_levels %/% 2),
  binf = params$min,
  bsup = params$max
)

plan <- as.data.frame(design$X)
message("Morris design: ", nrow(plan), " model runs to execute.")

# ── Run each design point through the model via logolink ────────────────────
# One logolink experiment per design point: the 7 Morris params as numeric
# constants, climate/governance fixed. Numeric constants need no quoting.
run_point <- function(par_row) {
  const <- list(
    "climate-scenario"           = "ssp245",
    "governance-mode"            = "fragmented",
    "hectares-per-farmer"        = 100,
    "et-sensitivity"             = par_row[["et-sensitivity"]],
    "integrated-efficiency-gain" = par_row[["integrated-efficiency-gain"]],
    "solar-imitation-coef"       = par_row[["solar-imitation-coef"]],
    "max-solar-adoption"         = par_row[["max-solar-adoption"]],
    "base-conversion-rate"       = par_row[["base-conversion-rate"]],
    "stress-threshold"           = par_row[["stress-threshold"]],
    "restriction-strength"       = par_row[["restriction-strength"]]
  )
  exp <- create_experiment(
    name = "morris_point", repetitions = 1,
    run_metrics_every_step = FALSE,
    setup = "setup", go = "go", time_limit = 90,
    metrics = c("basin-wef-index",
                "mean [water-stress] of municipalities"),
    constants = const
  )
  res <- run_experiment(model_path, setup_file = exp)
  tb <- res$table
  c(wef    = tb$basin_wef_index[nrow(tb)],
    stress = tb$mean_water_stress_of_municipalities[nrow(tb)])
}

# IMPORTANT: the model has stochasticity. A single run per design point is
# noisy. To keep Morris meaningful despite noise, average a few replicates
# per point. n_rep = 5 balances signal and runtime; raise if runtime allows.
n_rep <- 10
message("Running ", nrow(plan), " design points x ", n_rep,
        " replicates = ", nrow(plan) * n_rep, " model runs...")

Y_wef    <- numeric(nrow(plan))
Y_stress <- numeric(nrow(plan))
for (i in seq_len(nrow(plan))) {
  reps <- replicate(n_rep, run_point(plan[i, ]))
  Y_wef[i]    <- mean(reps["wef", ])
  Y_stress[i] <- mean(reps["stress", ])
  if (i %% 10 == 0) message("  ...", i, "/", nrow(plan), " points done")
  if (i %% 20 == 0) {
    saveRDS(list(Y_wef=Y_wef, Y_stress=Y_stress, i=i),
            here("outputs","tables","morris_progress.rds"))
  }
}

morris_wef <- design; tell(morris_wef, Y_wef)
morris_str <- design; tell(morris_str, Y_stress)

mustar_sigma <- function(m, label) {
  ee <- m$ee
  tibble(
    parameter = colnames(m$X),
    mu_star   = apply(ee, 2, function(x) mean(abs(x))),
    sigma     = apply(ee, 2, sd),
    response  = label
  )
}
res_tbl <- bind_rows(
  mustar_sigma(morris_wef, "WF index"),
  mustar_sigma(morris_str, "water stress")
) |> arrange(response, desc(mu_star))

message("\n== MORRIS SCREENING (mu* = influence, sigma = interaction) ==")
print(res_tbl, n = Inf)
write_csv(res_tbl, here("outputs","tables","morris_mu_sigma.csv"))

plot_morris <- function(df, ttl, file) {
  p <- ggplot(df, aes(mu_star, sigma, label = parameter)) +
    geom_point(size = 3, color = "steelblue") +
    ggrepel::geom_text_repel(size = 3) +
    labs(title = ttl, x = expression(mu * "*  (influence)"),
         y = expression(sigma * "  (interaction / non-linearity)")) +
    theme_minimal(base_size = 11)
  ggsave(here("outputs","figures", file), p, width = 15, height = 12, units = "cm")
}
if (requireNamespace("ggrepel", quietly = TRUE)) {
  plot_morris(filter(res_tbl, response=="WF index"),
              "Morris screening — WF composite index", "morris_wef.pdf")
  plot_morris(filter(res_tbl, response=="water stress"),
              "Morris screening — water stress", "morris_stress.pdf")
  message("[ok] Figures: morris_wef.pdf, morris_stress.pdf")
} else {
  message("! Install ggrepel for labelled Morris plots: renv::install('ggrepel')")
}

message("[done] 03_morris_sensitivity.R")