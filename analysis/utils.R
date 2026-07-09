# utils.R
# Funções utilitárias e constantes compartilhadas por todos os scripts.
# Carregar com: source(here::here("analysis", "utils.R"))

library(here)

# ── Diretórios ──────────────────────────────────────────────────────────────
DIR_RAW   <- here("data", "raw")
DIR_PROC  <- here("data", "processed")
DIR_FIG   <- here("outputs", "figures")
DIR_TAB   <- here("outputs", "tables")

# ── 34 municípios da UGRHI 6 — Alto Tietê ──────────────────────────────────
# Fonte: Relatório de Situação UGRHI 6 / SIGRH-SP
MUNICIPIOS_AT <- c(
  "Arujá", "Barueri", "Biritiba-Mirim", "Caieiras", "Cajamar",
  "Carapicuíba", "Cotia", "Diadema", "Embu das Artes", "Embu-Guaçu",
  "Ferraz de Vasconcelos", "Francisco Morato", "Franco da Rocha",
  "Guararema", "Guarulhos", "Itapecerica da Serra", "Itapevi",
  "Itaquaquecetuba", "Jandira", "Juquitiba", "Mairiporã",
  "Mauá", "Mogi das Cruzes", "Osasco", "Pirapora do Bom Jesus",
  "Poá", "Ribeirão Pires", "Rio Grande da Serra", "Salesópolis",
  "Santa Isabel", "Santana de Parnaíba", "Santo André",
  "São Bernardo do Campo", "São Caetano do Sul", "São Paulo",
  "Suzano", "Taboão da Serra"
)
# Nota: lista oficial pode variar entre 34-37 municípios dependendo da fonte.
# Verificar contra shapefile da ANA após download (item 3).

# Códigos IBGE dos municípios (para join com dados ANEEL/IBGE)
# Fonte: IBGE Malha Municipal SP
CODIGOS_IBGE_AT <- c(
  3503604, 3505708, 3506359, 3508801, 3509007,
  3510104, 3512803, 3513801, 3515004, 3515103,
  3515509, 3516903, 3516853, 3517800, 3518800,
  3522505, 3523107, 3523404, 3524105, 3525102,
  3528502, 3529401, 3530607, 3534401, 3537107,
  3539006, 3543303, 3544103, 3545209, 3546405,
  3547304, 3548203, 3548708, 3548807, 3550308,
  3552502, 3555105
)

# ── Padrão de escrita de CSVs processados ──────────────────────────────────
# Convenção do projeto: UTF-8, separador ponto-e-vírgula, sem BOM
write_proc <- function(df, nome_arquivo) {
  caminho <- file.path(DIR_PROC, nome_arquivo)
  readr::write_csv2(df, caminho, na = "NA")
  message("✔ Salvo: ", caminho, " (", nrow(df), " linhas, ", ncol(df), " colunas)")
  invisible(caminho)
}

# ── Helper: criar diretórios se não existirem ───────────────────────────────
criar_dirs <- function() {
  dirs <- c(DIR_RAW, DIR_PROC, DIR_FIG, DIR_TAB,
            file.path(DIR_RAW, "ANA"),
            file.path(DIR_RAW, "ANEEL"),
            file.path(DIR_RAW, "MapBiomas"))
  purrr::walk(dirs, \(d) if (!dir.exists(d)) dir.create(d, recursive = TRUE))
  message("✔ Estrutura de diretórios verificada.")
}

# ── Helper: log de proveniência ─────────────────────────────────────────────
log_download <- function(dataset, url, data_acesso = Sys.Date(), notas = "") {
  entrada <- glue::glue(
    "[{data_acesso}] {dataset}\n  URL: {url}\n  Notas: {notas}\n"
  )
  log_path <- here("data", "download_log.txt")
  cat(entrada, file = log_path, append = TRUE)
  message("✔ Log de proveniência atualizado.")
}
