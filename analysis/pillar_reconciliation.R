suppressPackageStartupMessages(library(boot))

in_csv <- here::here("outputs", "tables", "factorial_governance_efficiency_bass.csv")
outdir <- here::here("outputs", "tables")
R_BOOT <- 10000L
SEED   <- 42L
EPS    <- 0.0            
UTIL   <- 1.3
CLIM   <- c("historical", "ssp245", "ssp585")
ARMS   <- c("fragmented", "calibrated-cut", "solar-gating", "integrated")
COORD  <- c("calibrated-cut", "solar-gating", "integrated")
IX     <- c(water = "basin-water-index",
            food  = "basin-food-index",
            composite = "basin-wef-index")
clab   <- c(historical = "Historical", ssp245 = "SSP2-4.5", ssp585 = "SSP5-8.5")

set.seed(SEED)
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

raw <- readLines(in_csv, warn = FALSE)
hdr <- grep("\\[run number\\]", raw)[1]
if (is.na(hdr))
  stop("Not a BehaviorSpace export ('[run number]' not found): ", in_csv)
df <- read.csv(in_csv, skip = hdr - 1L, header = TRUE,
               check.names = FALSE, stringsAsFactors = FALSE)
names(df) <- trimws(names(df))

need <- c("[step]", "climate-scenario", "governance-mode", "efficiency-gain",
          "initial-utilisation", unname(IX))
miss <- setdiff(need, names(df))
if (length(miss))
  stop("Missing columns: ", paste(miss, collapse = ", "),
       "\nPresent: ", paste(utils::head(names(df), 8), collapse = ", "), " ...")

df <- df[df[["[step]"]] == max(df[["[step]"]], na.rm = TRUE) &
         df[["efficiency-gain"]] == EPS &
         df[["initial-utilisation"]] == UTIL, ]

getv <- function(clim, gov, col)
  df[df[["climate-scenario"]] == clim & df[["governance-mode"]] == gov, col]

t6 <- do.call(rbind, lapply(ARMS, function(gov)
  do.call(rbind, lapply(CLIM, function(clim) {
    wf <- getv(clim, gov, "basin-wef-index"); n <- length(wf)
    data.frame(climate = clab[[clim]], governance = gov,
               mean_wf = round(mean(wf), 4), sd = round(sd(wf), 4),
               mcse = round(sd(wf) / sqrt(n), 4),
               cv_pct = round(100 * sd(wf) / mean(wf), 2), n_rep = n)
  }))))
write.csv(t6, file.path(outdir, "table6_mc_precision.csv"), row.names = FALSE)

cohen_d <- function(a, b) {
  na <- length(a); nb <- length(b)
  sp <- sqrt(((na - 1) * var(a) + (nb - 1) * var(b)) / (na + nb - 2))
  (mean(a) - mean(b)) / sp
}
diff_stat <- function(d, i) {  # integrated - fragmented
  ds <- d[i, ]
  mean(ds$value[ds$g == "integrated"]) - mean(ds$value[ds$g == "fragmented"])
}
contrast <- function(clim, col) {
  a <- getv(clim, "integrated",  col)
  b <- getv(clim, "fragmented",  col)
  cell <- data.frame(value = c(a, b),
                     g = c(rep("integrated", length(a)), rep("fragmented", length(b))),
                     stringsAsFactors = FALSE)
  bt <- boot(cell, diff_stat, R = R_BOOT, strata = factor(cell$g))
  ci <- tryCatch(boot.ci(bt, type = "bca")$bca[4:5],
                 error = function(e) boot.ci(bt, type = "perc")$percent[4:5])
  c(delta = mean(a) - mean(b), lo = ci[1], hi = ci[2], d = cohen_d(a, b))
}
pillar <- do.call(rbind, lapply(CLIM, function(clim) {
  row <- data.frame(
    climate     = clab[[clim]],
    food_frag   = round(mean(getv(clim, "fragmented", "basin-food-index")), 4),
    food_integ  = round(mean(getv(clim, "integrated", "basin-food-index")), 4),
    water_frag  = round(mean(getv(clim, "fragmented", "basin-water-index")), 4),
    water_integ = round(mean(getv(clim, "integrated", "basin-water-index")), 4),
    stringsAsFactors = FALSE)
  for (ix in names(IX)) {
    r <- contrast(clim, IX[[ix]])
    row[[paste0("d_", ix)]]       <- round(r["delta"], 4)
    row[[paste0("d_", ix, "_lo")]] <- round(r["lo"], 4)
    row[[paste0("d_", ix, "_hi")]] <- round(r["hi"], 4)
    row[[paste0("cohen_", ix)]]    <- round(r["d"], 2)
  }
  row
}))
write.csv(pillar, file.path(outdir, "pillar_levels_contrasts.csv"), row.names = FALSE)

sdr <- do.call(rbind, lapply(CLIM, function(clim) {
  sf  <- sd(getv(clim, "fragmented", "basin-wef-index"))
  row <- data.frame(climate = clab[[clim]], sd_fragmented = round(sf, 4),
                    stringsAsFactors = FALSE)
  for (co in COORD)
    row[[paste0("ratio_vs_", gsub("-", "_", co))]] <-
      round(sf / sd(getv(clim, co, "basin-wef-index")), 1)
  row
}))
write.csv(sdr, file.path(outdir, "sd_ratios.csv"), row.names = FALSE)

cat("\n== Table 6 (MC precision, eps=0, u=1.3) ==\n"); print(t6, row.names = FALSE)
cat("\n== §3.2.2 pillar levels + contrasts ==\n");     print(pillar, row.names = FALSE)
cat("\n== §3.3 SD ratios (fragmented / coordinated) ==\n"); print(sdr, row.names = FALSE)
cat("\nWrote 3 CSVs to ", outdir, "\n", sep = "")