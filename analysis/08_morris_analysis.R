suppressPackageStartupMessages({
  library(here); library(dplyr); library(ggplot2); library(patchwork)
  library(readr); library(ggrepel)
})
source(here("analysis", "utils.R"))
source(here("analysis", "04_figures.R"))  # save_fig (convenção 300 DPI)

res_path <- here("outputs", "tables", "morris_mu_sigma.csv")
if (!file.exists(res_path)) stop("Resultados do método de Morris não encontrados: ", res_path)

res_tbl <- read_csv(res_path, show_col_types = FALSE)
if (ncol(res_tbl) == 1) res_tbl <- read_csv2(res_path, show_col_types = FALSE)

req_cols <- c("mu_star", "sigma", "parameter", "response")
faltando <- setdiff(req_cols, names(res_tbl))
if (length(faltando) > 0)
  stop("Colunas ausentes em morris_mu_sigma.csv: ", paste(faltando, collapse = ", "),
       "\nColunas encontradas: ", paste(names(res_tbl), collapse = ", "))

plot_morris_panel <- function(df, ttl) {
  ggplot(df, aes(mu_star, sigma, label = parameter)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey80") +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey80") +
    geom_point(size = 3.5, color = "#2c3e50", alpha = 0.8) +
    geom_text_repel(size = 3.5, box.padding = 0.6, point.padding = 0.4,
                    segment.color = "grey50") +
    labs(title = ttl,
         x = expression(mu^"*" ~ "(Direct Influence)"),
         y = expression(sigma ~ "(Non-linearity / Interactions)")) +
    theme_minimal(base_size = 11) +
    theme(panel.border = element_rect(color = "grey80", fill = NA))
}

niveis <- unique(res_tbl$response)
message("[info] Valores de 'response' encontrados: ", paste(niveis, collapse = " | "))

pega_response <- function(padrao) {
  hit <- niveis[grepl(padrao, niveis, ignore.case = TRUE)][1]
  if (is.na(hit)) { warning("Nenhum 'response' casou com: ", padrao); return(NULL) }
  filter(res_tbl, response == hit)
}

df_wef <- pega_response("wf|wef")
df_str <- pega_response("stress|estresse|water")

paineis <- list()
if (!is.null(df_wef)) paineis <- c(paineis, list(plot_morris_panel(df_wef, "Sensitivity: WF Index")))
if (!is.null(df_str)) paineis <- c(paineis, list(plot_morris_panel(df_str, "Sensitivity: Water Stress")))
if (length(paineis) == 0) stop("Nenhum painel pôde ser construído — verifique a coluna 'response'.")

p_morris <- Reduce(`+`, paineis) + plot_annotation(tag_levels = "A")
save_fig(p_morris, "08_composite_morris.pdf", width = 28, height = 12)
message("[ok] Painel de sensibilidade gerado (08_composite_morris.pdf).")