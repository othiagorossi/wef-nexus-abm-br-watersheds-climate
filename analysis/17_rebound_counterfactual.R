# Method: delta = mean(solar 0.2) - mean(no-solar 0) over the 50 replicates in
#         each cell; stratified (per-arm) BCa bootstrap 95% CIs (10,000
#         resamples) plus Cohen's d. Governance and climate held constant.

suppressPackageStartupMessages(library(boot))
 
in_csv   <- here::here("outputs", "tables", "solar_counterfactual.csv")
outdir   <- here::here("outputs", "tables")
R_BOOT   <- 10000L
SEED     <- 42L
CLIMATES <- c("historical", "ssp245", "ssp585")
REGIMES  <- c("fragmented", "integrated")
INDICES  <- c(water = "basin-water-index",
              food  = "basin-food-index",
              composite = "basin-wef-index")
 
set.seed(SEED)
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
 
raw <- readLines(in_csv, warn = FALSE)
hdr <- grep("\\[run number\\]", raw)[1]          # the BehaviorSpace header row
if (is.na(hdr)) {
  hint <- if (length(raw) && grepl("ibge_code|;", raw[1]))
    paste0("\nThe first line is: ", raw[1],
           "\nThis looks like a plain/semicolon CSV (e.g. basin_municipalities.csv),",
           "\nnot a BehaviorSpace export.") else ""
  stop("Not a BehaviorSpace export - header row '[run number]' not found in:\n  ",
       in_csv, hint,
       "\nPoint `in_csv` at the solar_counterfactual BehaviorSpace table (.csv).")
}
 
df <- read.csv(in_csv, skip = hdr - 1L, header = TRUE,
               check.names = FALSE, stringsAsFactors = FALSE)
names(df) <- trimws(names(df))                   # strip any stray spaces
 
need <- c("[step]", "climate-scenario", "governance-mode",
          "max-solar-adoption", unname(INDICES))
missing <- setdiff(need, names(df))
if (length(missing))
  stop("Columns not found after reading '", in_csv, "':\n  ",
       paste(missing, collapse = ", "),
       "\nColumns present (", ncol(df), "): ",
       paste(utils::head(names(df), 8), collapse = ", "), " ...")
 
df <- df[df[["[step]"]] == max(df[["[step]"]], na.rm = TRUE), ]
df$arm <- ifelse(df[["max-solar-adoption"]] == 0.2, "on", "off")
 
cohen_d <- function(a, b) {
  na <- length(a); nb <- length(b)
  sp <- sqrt(((na - 1) * var(a) + (nb - 1) * var(b)) / (na + nb - 2))
  (mean(a) - mean(b)) / sp
}
 
delta_stat <- function(d, i) {
  ds <- d[i, ]
  mean(ds$value[ds$arm == "on"]) - mean(ds$value[ds$arm == "off"])
}
 
bca_ci <- function(cell) {
  b <- boot(cell, delta_stat, R = R_BOOT, strata = factor(cell$arm))
  ci <- tryCatch(
    boot.ci(b, conf = 0.95, type = "bca")$bca[4:5],
    error = function(e) {
      warning("BCa failed for one cell; percentile CI used instead.")
      boot.ci(b, conf = 0.95, type = "perc")$percent[4:5]
    })
  as.numeric(ci)
}
 
rows <- list()
for (clim in CLIMATES) for (gov in REGIMES) for (ix in names(INDICES)) {
  col <- INDICES[[ix]]
  sub <- df[df[["climate-scenario"]] == clim & df[["governance-mode"]] == gov, ]
  on  <- sub[[col]][sub$arm == "on"]
  off <- sub[[col]][sub$arm == "off"]
  cell <- data.frame(value = c(on, off),
                     arm = c(rep("on", length(on)), rep("off", length(off))),
                     stringsAsFactors = FALSE)
  ci <- bca_ci(cell)
  rows[[length(rows) + 1L]] <- data.frame(
    climate = clim, governance = gov, index = ix,
    mean_nosolar = mean(off), mean_solar = mean(on),
    delta = mean(on) - mean(off),
    ci_lo = ci[1], ci_hi = ci[2],
    cohen_d = cohen_d(on, off), n_rep = length(on),
    stringsAsFactors = FALSE)
}
res <- do.call(rbind, rows)
num <- c("mean_nosolar", "mean_solar", "delta", "ci_lo", "ci_hi")
res[num]    <- round(res[num], 4)
res$cohen_d <- round(res$cohen_d, 2)
 
csv_path <- file.path(outdir, "rebound_counterfactual.csv")
write.csv(res, csv_path, row.names = FALSE)
cat("\nWrote: ", csv_path, "\n\n", sep = "")
print(res, row.names = FALSE)