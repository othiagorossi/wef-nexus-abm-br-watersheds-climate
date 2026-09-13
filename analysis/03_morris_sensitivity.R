options(cli.default_handler = function(...) invisible(NULL))

suppressPackageStartupMessages({
  library(here); library(dplyr); library(tidyr); library(readr)
  library(ggplot2); library(sensitivity); library(logolink)
})
source(here("analysis", "utils.R"))

Sys.setlocale("LC_CTYPE", "en_US.UTF-8")

set.seed(20260716)
model_path <- here("model", "wef_nexus_watershed_alto_tiete.nlogox")
stopifnot("Model file not found" = file.exists(model_path))

TEST_MODE      <- FALSE
GOVERNANCE_SET <- c("fragmented", "integrated")
n_rep    <- 10
r_traj   <- 30
n_levels <- 6

fixed <- list(
  "hectares-per-farmer"        = 100,
  "solar-start-year"           = 2018,
  "solar-innovation-coef"      = 0.008,
  "no-pump-irrigation-frac"    = 0.55,
  "solar-pump-irrigation-frac" = 0.95,
  "urban-pressure-coef"        = 0.5,
  "water-stress-exit-coef"     = 0.3,
  "warming-ssp245"             = 1.4,
  "warming-ssp585"             = 2.1,
  "climate-onset-year"         = 2025,
  "initial-utilisation"        = 1.3
)
SCREEN_CLIMATE <- "ssp245"

params <- tibble::tribble(
  ~name,                    ~min,    ~max,
  "et-sensitivity",         0.02,    0.08,
  "efficiency-gain",        0.00,    0.45,
  "solar-imitation-coef",   0.5,    0.9,
  "max-solar-adoption",     0.10,    0.30,
  "base-conversion-rate",   0.0008,  0.0020,
  "stress-threshold",       0.60,    1.00,
  "restriction-strength",   0.30,    0.70,
  "rebound-share",          0.00,    1.00
)

stopifnot(length(intersect(params$name, names(fixed))) == 0)

design <- morris(
  model   = NULL,
  factors = params$name,
  r       = r_traj,
  design  = list(type = "oat", levels = n_levels, grid.jump = n_levels %/% 2),
  binf    = params$min,
  bsup    = params$max
)
plan_full <- as.data.frame(design$X)
message("Morris design: ", nrow(plan_full), " design points x ",
        length(params$name), " parameters.")

run_point <- function(par_row, point_id, governance) {
  const <- c(
    list("climate-scenario" = SCREEN_CLIMATE,
         "governance-mode"  = governance),
    fixed,
    as.list(par_row[params$name])
  )
  exp <- create_experiment(
    name = paste0("morris_", governance, "_", point_id),
    repetitions = n_rep,
    run_metrics_every_step = FALSE,
    setup = "setup", go = "go", time_limit = 90,
    metrics = c("basin-wef-index",
                "basin-water-index",
                "basin-food-index",
                "mean [water-stress] of municipalities",
                "mean [water-stress-realised] of irrigating-municipalities",
                "precision 4 stress-threshold"),          # echo: verifies constants were honoured
    constants = const
  )
  tb <- run_experiment(model_path, setup_file = exp)$table

  stopifnot("logolink did not honour `repetitions` (expected n_rep rows)" =
              nrow(tb) == n_rep)
  
  echo_col <- grep("stress.?threshold", names(tb), value = TRUE)
  echo_col <- echo_col[!grepl("realised|realized", echo_col)]   # not the stress metric
  stopifnot("echo column for stress-threshold not found" = length(echo_col) >= 1)
  echo_val <- unique(tb[[echo_col[1]]])
  if (!isTRUE(all.equal(echo_val, par_row[["stress-threshold"]], tolerance = 1e-8)))
    stop("Constant not honoured at point ", point_id,
         ": model reports stress-threshold = ", echo_val,
         " but design sent ", par_row[["stress-threshold"]],
         ". Check patch item 4a.")

  c(wef         = mean(tb$basin_wef_index),
    water       = mean(tb$basin_water_index),
    food        = mean(tb$basin_food_index),
    stress      = mean(tb$mean_water_stress_of_municipalities),
    stress_real = mean(tb$mean_water_stress_realised_of_irrigating_municipalities))
}

mustar_sigma <- function(design_obj, y, label) {
  m <- design_obj; tell(m, y)
  ee <- m$ee
  tibble(parameter = colnames(m$X),
         mu        = colMeans(ee),
         mu_star   = apply(ee, 2, function(x) mean(abs(x))),
         sigma     = apply(ee, 2, sd),
         response  = label)
}

plot_morris <- function(df, ttl, file) {
  p <- ggplot(df, aes(mu_star, sigma, label = parameter)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dotted", colour = "grey60") +
    geom_point(size = 3, colour = "steelblue") +
    ggrepel::geom_text_repel(size = 3) +
    labs(title = ttl, x = expression(mu * "*  (influence)"),
         y = expression(sigma * "  (interaction / non-linearity)")) +
    theme_minimal(base_size = 11)
  ggsave(here("outputs", "figures", file), p, width = 15, height = 12, units = "cm")
}

run_screening <- function(governance) {
  message("\n=== Morris screening: governance = ", governance, " ===")
  plan <- if (TEST_MODE) plan_full[1:2, , drop = FALSE] else plan_full

  write_csv(mutate(plan, point = row_number()),
            here("outputs", "tables", paste0("morris_design_", governance, ".csv")))

  Y <- matrix(NA_real_, nrow = nrow(plan), ncol = 5,
              dimnames = list(NULL, c("wef","water","food","stress","stress_real")))
  ckpt <- here("outputs", "tables", paste0("morris_progress_", governance, ".rds"))
  start_i <- 1
  if (!TEST_MODE && file.exists(ckpt)) {
    prev <- readRDS(ckpt); Y <- prev$Y; start_i <- prev$i + 1
    message("Resuming ", governance, " from point ", start_i)
  }
  for (i in seq(start_i, nrow(plan))) {
    Y[i, ] <- run_point(plan[i, ], i, governance)
    if (i %% 10 == 0) message("  ...", i, "/", nrow(plan))
    if (!TEST_MODE && (i %% 20 == 0 || i == nrow(plan)))
      saveRDS(list(Y = Y, i = i), ckpt)
  }

  if (TEST_MODE) {
    message("[TEST] Both guards passed for ", governance,
            ". Responses of the 2 points (rows should differ):")
    print(round(Y, 4))
    return(invisible(NULL))
  }

  write_csv(as_tibble(Y) |> mutate(point = row_number()),
            here("outputs", "tables", paste0("morris_responses_", governance, ".csv")))

  res_tbl <- bind_rows(
    mustar_sigma(design, Y[, "wef"],         "WF index"),
    mustar_sigma(design, Y[, "water"],       "water pillar"),
    mustar_sigma(design, Y[, "food"],        "food pillar"),
    mustar_sigma(design, Y[, "stress"],      "water stress (pre-restriction)"),
    mustar_sigma(design, Y[, "stress_real"], "water stress (realised)")
  ) |> mutate(governance = governance) |> arrange(response, desc(mu_star))

  message("\n== MORRIS (", governance, "): mu* = influence, sigma = interaction ==")
  print(res_tbl, n = Inf)
  write_csv(res_tbl,
            here("outputs", "tables", paste0("morris_mu_sigma_", governance, ".csv")))

  if (requireNamespace("ggrepel", quietly = TRUE)) {
    plot_morris(filter(res_tbl, response == "WF index"),
                paste0("Morris - WF composite index (", governance, ")"),
                paste0("morris_wef_", governance, ".pdf"))
    plot_morris(filter(res_tbl, response == "water stress (realised)"),
                paste0("Morris - realised water stress (", governance, ")"),
                paste0("morris_stress_", governance, ".pdf"))
  }
  file.remove(ckpt)   # completed cleanly; drop checkpoint so a later run restarts fresh
  res_tbl
}

all_res <- lapply(GOVERNANCE_SET, run_screening)

if (!TEST_MODE) {
  combined <- bind_rows(all_res)
  write_csv(combined, here("outputs", "tables", "morris_mu_sigma_both.csv"))
  message("\n[done] 03_morris_sensitivity.R - screened: ",
          paste(GOVERNANCE_SET, collapse = ", "))
}