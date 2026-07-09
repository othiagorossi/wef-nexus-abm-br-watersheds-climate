# 00_setup_renv.R
# Execute UMA VEZ para inicializar o ambiente R reprodutível com renv.
# Depois use renv::restore() em qualquer máquina nova.

# Instalar renv se necessário
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")

# Inicializar renv no projeto
renv::init()

# Instalar todos os pacotes necessários
pacotes <- c(
  # Núcleo tidyverse
  "tidyverse",    # dplyr, tidyr, readr, ggplot2, purrr, stringr, lubridate
  "here",         # caminhos relativos robustos
  # Dados espaciais
  "sf",           # vetores (shapefiles, geopackage)
  "terra",        # rasters (GeoTIFF — para MapBiomas via GEE)
  # Limpeza
  "janitor",      # clean_names, remove_empty, tabyl
  "abjutils",     # rm_accent para normalizar nomes de municípios
  # Download
  "httr2",        # requisições HTTP com retry
  # Análise estatística
  "broom",        # tidying de modelos (lm, aov)
  "rstatix",      # ANOVA e testes pós-hoc com pipe-friendly API
  "emmeans",      # médias marginais estimadas e comparações múltiplas
  "car",          # Levene test, VIF, Anova() tipo II/III
  "nortest",      # testes de normalidade (Anderson-Darling)
  # Utilitários
  "glue",         # interpolação de strings
  "scales",       # formatação de eixos em ggplot2
  "patchwork",    # composição de figuras
  "gt"            # tabelas de publicação
)

install.packages(pacotes)

# Criar snapshot do ambiente — gera renv.lock
renv::snapshot()

message("\nAmbiente pronto. Use renv::restore() em qualquer máquina nova.")
message("Próximo passo: execute analysis/00_download.R")
