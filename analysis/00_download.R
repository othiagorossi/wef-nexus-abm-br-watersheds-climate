# 00_download.R
# Download automatizado dos datasets prioritários para o Alto Tietê (UGRHI 6).
# Execute este script UMA VEZ antes de qualquer análise.
# Todos os arquivos baixados vão para data/raw/{fonte}/
#
# Itens cobertos:
#   Item 1 — ANA: Outorgas de uso da água
#   Item 3 — ANA: Shapefile de divisão hidrográfica (UGRHI 6)
#   Item 6 — ANEEL: Empreendimentos de micro/minigeração distribuída
#   Item 10 — MapBiomas: Estatísticas territoriais por município (CSV)
#
# ⚠ Item 10 (MapBiomas) NÃO tem download automático via URL direta.
#   Instruções manuais estão na seção 4 abaixo.

# ── Dependências ────────────────────────────────────────────────────────────
# install.packages("renv"); renv::restore()  # restaurar ambiente completo
library(here)
library(httr2)
library(readr)
library(fs)
source(here("analysis", "utils.R"))

criar_dirs()

# ════════════════════════════════════════════════════════════════════════════
# 1. ANA — Outorgas de direito de uso de recursos hídricos
# ════════════════════════════════════════════════════════════════════════════
# Fonte: Portal de Dados Abertos da ANA
# Contém: todos os pedidos ativos de captação por coordenada, vazão, finalidade
# Cobertura: Brasil (filtraremos SP / UGRHI 6 em 01_preprocess.R)

url_outorgas <- "https://dadosabertos.ana.gov.br/datasets/outorgas/download"
dest_outorgas <- file.path(DIR_RAW, "ANA", "outorgas_ana.csv")

baixar_se_ausente <- function(url, destino, nome) {
  if (file.exists(destino)) {
    message("⏭  ", nome, " já existe — pulando download.")
    return(invisible(destino))
  }
  message("⬇  Baixando ", nome, "...")
  resp <- tryCatch(
    httr2::request(url) |>
      httr2::req_timeout(300) |>
      httr2::req_retry(max_tries = 3, backoff = \(i) 10 * i) |>
      httr2::req_perform(),
    error = \(e) {
      message("✗ Falha no download de ", nome, ": ", conditionMessage(e))
      return(NULL)
    }
  )
  if (!is.null(resp)) {
    writeBin(httr2::resp_body_raw(resp), destino)
    message("✔ Salvo: ", destino,
            " (", round(file.size(destino) / 1024^2, 1), " MB)")
    log_download(nome, url)
  }
  invisible(destino)
}

# As URLs dos dados abertos da ANA às vezes exigem acesso pelo portal.
# Se o download automático falhar, instruções manuais estão abaixo.
baixar_se_ausente(
  url     = url_outorgas,
  destino = dest_outorgas,
  nome    = "ANA Outorgas"
)

# ── Download manual (fallback) ──────────────────────────────────────────────
# 1. Acesse: https://dadosabertos.ana.gov.br/datasets/
# 2. Pesquise "outorgas" ou "direito de uso"
# 3. Clique em "Download CSV"
# 4. Salve em: data/raw/ANA/outorgas_ana.csv


# ════════════════════════════════════════════════════════════════════════════
# 2. ANA — Shapefile da divisão hidrográfica (UGRHIs do estado de SP)
# ════════════════════════════════════════════════════════════════════════════
# Usaremos o shapefile oficial do SIGRH-SP (mais preciso para UGRHI 6)
# e o shapefile federal da ANA como alternativa.

# Opção A: SIGRH-SP (recomendado para UGRHI 6)
url_sigrh_zip <- paste0(
  "https://sigrh.sp.gov.br/public/uploads/documents/",
  "shapefile_ugrhi_sp.zip"
)
dest_sigrh_zip <- file.path(DIR_RAW, "ANA", "shp_ugrhi_sp.zip")

baixar_se_ausente(
  url     = url_sigrh_zip,
  destino = dest_sigrh_zip,
  nome    = "Shapefile UGRHI SP (SIGRH)"
)

# Opção B: ANA — Divisão Hidrográfica Nacional (fallback)
url_shp_ana <- paste0(
  "https://metadados.snirh.gov.br/geonetwork/srv/api/records/",
  "f19d7c48-2a45-4e72-a8c2-ef3a39c7c52e/attachments/",
  "OttoRegioesHidrograficas.zip"
)
dest_shp_ana <- file.path(DIR_RAW, "ANA", "shp_divisao_hidrografica_ana.zip")

baixar_se_ausente(
  url     = url_shp_ana,
  destino = dest_shp_ana,
  nome    = "ANA Shapefile Divisão Hidrográfica"
)

# ── Download manual (fallback) ──────────────────────────────────────────────
# SIGRH-SP:
#   1. Acesse: https://sigrh.sp.gov.br
#   2. Menu > Dados > Shapefiles > Unidades de Gerenciamento de RH
#   3. Salve o ZIP em: data/raw/ANA/shp_ugrhi_sp.zip
#
# ANA (alternativa):
#   1. Acesse: https://metadados.snirh.gov.br/geonetwork
#   2. Pesquise "Divisão Hidrográfica"
#   3. Baixe o shapefile e salve em: data/raw/ANA/shp_divisao_hidrografica_ana.zip


# ════════════════════════════════════════════════════════════════════════════
# 3. ANEEL — Empreendimentos de micro/minigeração distribuída
# ════════════════════════════════════════════════════════════════════════════
# Fonte: dadosabertos.aneel.gov.br — download direto via URL estável
# Contém: cada instalação GD com município, data conexão, fonte, potência (kW)

url_mmgd <- paste0(
  "https://dadosabertos.aneel.gov.br/dataset/",
  "5e0fafd2-21b9-4d5b-b622-40438d40aba2/resource/",
  "b1bd71e7-d0ad-4214-9053-cbd58e9564a7/download/",
  "empreendimento-geracao-distribuida.csv"
)
dest_mmgd <- file.path(DIR_RAW, "ANEEL", "mmgd_aneel.csv")

baixar_se_ausente(
  url     = url_mmgd,
  destino = dest_mmgd,
  nome    = "ANEEL MMGD"
)

# Arquivo complementar: informações técnicas fotovoltaicas
url_mmgd_fv <- paste0(
  "https://dadosabertos.aneel.gov.br/dataset/",
  "5e0fafd2-21b9-4d5b-b622-40438d40aba2/resource/",
  "49fa9ca0-f609-4ae3-a6f7-b97bd0945a3a/download/",
  "empreendimento-gd-informacoes-tecnicas-fotovoltaica.csv"
)
dest_mmgd_fv <- file.path(DIR_RAW, "ANEEL", "mmgd_tecnico_fv_aneel.csv")

baixar_se_ausente(
  url     = url_mmgd_fv,
  destino = dest_mmgd_fv,
  nome    = "ANEEL MMGD — dados técnicos fotovoltaica"
)

# ── Download manual (fallback) ──────────────────────────────────────────────
# 1. Acesse: https://dadosabertos.aneel.gov.br/dataset/relacao-de-empreendimentos-de-geracao-distribuida
# 2. Clique em "empreendimento-geracao-distribuida.csv" > Download
# 3. Salve em: data/raw/ANEEL/mmgd_aneel.csv


# ════════════════════════════════════════════════════════════════════════════
# 4. MapBiomas — Estatísticas territoriais por município (CSV)
# ════════════════════════════════════════════════════════════════════════════
# ⚠ Download MANUAL — a plataforma MapBiomas não oferece URL direta para
#   exportação por município. Siga as instruções abaixo.
#
# INSTRUÇÕES (5 passos, ~10 minutos):
#
#   1. Acesse: https://plataforma.brasil.mapbiomas.org
#   2. Menu lateral > "Estatísticas"
#   3. Em "Território", selecione:
#      - Tipo: "Município"
#      - Estado: "São Paulo"
#      - Selecione os 34+ municípios do Alto Tietê
#        (lista em MUNICIPIOS_AT no utils.R)
#   4. Selecione:
#      - Coleção: 9 (1985–2024)
#      - Todas as classes de cobertura
#      - Todos os anos disponíveis
#   5. Clique em "Exportar CSV" e salve em:
#        data/raw/MapBiomas/mapbiomas_col9_municipios_at.csv
#
# Alternativamente, via Google Earth Engine (mais preciso, requer conta GEE):
#   Ver script: analysis/00b_download_gee.js (a ser criado)

dest_mapbiomas <- file.path(DIR_RAW, "MapBiomas", "mapbiomas_col9_municipios_at.csv")

if (!file.exists(dest_mapbiomas)) {
  message(
    "\n⚠ MapBiomas (item 10) requer download manual.\n",
    "  Siga as instruções na seção 4 deste script.\n",
    "  Destino esperado: ", dest_mapbiomas, "\n"
  )
} else {
  message("✔ MapBiomas CSV já encontrado: ", dest_mapbiomas)
  log_download(
    "MapBiomas Coleção 9 — estatísticas municipais",
    "https://plataforma.brasil.mapbiomas.org (download manual)",
    notas = "Municípios do Alto Tietê (UGRHI 6)"
  )
}

# ════════════════════════════════════════════════════════════════════════════
# 5. Resumo do status dos downloads
# ════════════════════════════════════════════════════════════════════════════
arquivos_esperados <- list(
  "ANA Outorgas"             = dest_outorgas,
  "ANA Shapefile UGRHI"      = dest_sigrh_zip,
  "ANEEL MMGD"               = dest_mmgd,
  "ANEEL MMGD técnico FV"    = dest_mmgd_fv,
  "MapBiomas municípios CSV" = dest_mapbiomas
)

cat("\n══ STATUS DOS DOWNLOADS ═══════════════════════════════\n")
purrr::iwalk(arquivos_esperados, \(caminho, nome) {
  if (file.exists(caminho)) {
    tam <- round(file.size(caminho) / 1024^2, 2)
    cat(sprintf("  ✔ %-30s %.2f MB\n", nome, tam))
  } else {
    cat(sprintf("  ✗ %-30s AUSENTE\n", nome))
  }
})
cat("═══════════════════════════════════════════════════════\n")
cat("Próximo passo: execute analysis/01_preprocess.R\n\n")
