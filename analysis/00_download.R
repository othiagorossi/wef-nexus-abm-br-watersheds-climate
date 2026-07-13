suppressPackageStartupMessages({
  library(here); library(httr2); library(fs)
})
source(here("analysis", "utils.R"))
create_project_dirs()

download_if_absent <- function(url, dest, label, timeout_s = 900) {
  if (file.exists(dest)) {
    message("[skip] ", label, " already present.")
    return(invisible(dest))
  }
  message("[..] Downloading ", label, " ...")
  resp <- tryCatch(
    request(url) |>
      req_timeout(timeout_s) |>
      req_retry(max_tries = 3, backoff = \(i) 10 * i) |>
      req_perform(),
    error = function(e) {
      message("[!!] Download failed for ", label, ": ", conditionMessage(e))
      NULL
    }
  )
  if (!is.null(resp)) {
    writeBin(resp_body_raw(resp), dest)
    message("[ok] Saved: ", basename(dest),
            " (", round(file.size(dest) / 1024^2, 1), " MB)")
    log_download(label, url)
  }
  invisible(dest)
}

ANEEL_DG_URL <- paste0(
  "https://dadosabertos.aneel.gov.br/dataset/",
  "5e0fafd2-21b9-4d5b-b622-40438d40aba2/resource/",
  "b1bd71e7-d0ad-4214-9053-cbd58e9564a7/download/",
  "empreendimento-geracao-distribuida.csv"
)
aneel_dest <- file.path(DIR_RAW, "ANEEL", "aneel_distributed_generation.csv")

download_if_absent(ANEEL_DG_URL, aneel_dest, "ANEEL distributed generation")

# ════════════════════════════════════════════════════════════════════════════
# 2. ANA — Water use permits (outorgas) — MANUAL
# ════════════════════════════════════════════════════════════════════════════
# Source: https://dadosabertos.ana.gov.br/datasets/

ana_surface     <- file.path(DIR_RAW, "ANA", "outorgas_estaduais_superficiais.csv")
ana_groundwater <- file.path(DIR_RAW, "ANA", "outorgas_estaduais_subterraneas.csv")

# ════════════════════════════════════════════════════════════════════════════
# 3. UGRHI 6 boundaries — MANUAL
# ════════════════════════════════════════════════════════════════════════════
# Source: Alto Tietê Basin Committee — https://comiteat.sp.gov.br (A BACIA >

basin_municipalities_shp <- file.path(
  DIR_RAW, "ANA", "municipios_ugrhi6", "Municipios UGRHI 6.shp")
basin_outline_shp <- file.path(
  DIR_RAW, "ANA", "delimitacao_ugrhi6", "06_Bacia_Alto_Tiete.shp")

# ════════════════════════════════════════════════════════════════════════════
# 4. MapBiomas — Land cover statistics, Collection 10.1 — MANUAL
# ════════════════════════════════════════════════════════════════════════════
# Source: https://plataforma.brasil.mapbiomas.org > Statistics >

mapbiomas_xlsx <- file.path(
  DIR_RAW, "MapBiomas",
  "MAPBIOMAS_BRAZIL-COVERAGE_STATISTICS-COL.10.1-MUNICIPALITIES_STATES_BIOMES.xlsx"
)

# ════════════════════════════════════════════════════════════════════════════
# 5. Status report
# ════════════════════════════════════════════════════════════════════════════
required_files <- c(
  "ANEEL distributed generation"   = aneel_dest,
  "ANA permits (surface)"          = ana_surface,
  "ANA permits (groundwater)"      = ana_groundwater,
  "UGRHI 6 municipalities (shp)"   = basin_municipalities_shp,
  "UGRHI 6 outline (shp)"          = basin_outline_shp,
  "MapBiomas Collection 10.1"      = mapbiomas_xlsx
)

cat("\n== DATA ACQUISITION STATUS ============================\n")
for (label in names(required_files)) {
  path <- required_files[[label]]
  if (file.exists(path)) {
    cat(sprintf("  [ok]      %-30s %6.1f MB\n",
                label, file.size(path) / 1024^2))
  } else {
    cat(sprintf("  [MISSING] %-30s\n", label))
  }
}
cat("=======================================================\n")

missing <- required_files[!file.exists(unlist(required_files))]
if (length(missing) > 0) {
  cat("\nSome datasets require manual download.\n",
      "See the numbered sections above for portal URLs and target paths.\n\n")
} else {
  cat("\nAll datasets present. Next: analysis/01_preprocess.R\n\n")
}