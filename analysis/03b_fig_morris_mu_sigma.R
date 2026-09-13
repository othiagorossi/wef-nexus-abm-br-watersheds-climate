library(dplyr)
library(ggplot2)
library(here)
if (!requireNamespace("ggrepel", quietly = TRUE)) install.packages("ggrepel")
library(ggrepel)

in_csv  <- here::here("outputs", "tables",  "morris_mu_sigma_both.csv")
out_png <- here::here("outputs", "figures", "fig_morris_mu_sigma.png")
out_pdf <- here::here("outputs", "figures", "fig_morris_mu_sigma.pdf")
dir.create(dirname(out_png), recursive = TRUE, showWarnings = FALSE)

m <- read.csv(in_csv, stringsAsFactors = FALSE, check.names = FALSE)
cat("\n[morris] responses available:\n"); print(unique(m$response))

keep        <- c("WF index", "food pillar")
resp_labels <- c("WF index" = "Water\u2013Food composite", "food pillar" = "Food pillar")

df <- m %>%
  filter(response %in% keep) %>%
  mutate(
    response   = factor(resp_labels[response], levels = unname(resp_labels)),
    governance = factor(governance,
                        levels = c("fragmented", "integrated"),
                        labels = c("Fragmented", "Integrated"))
  )
stopifnot(nrow(df) > 0)

gov_cols  <- c("Fragmented" = "#E45756", "Integrated" = "#4C78A8")
gov_shape <- c("Fragmented" = 16,        "Integrated" = 17)

cat("\n== Top μ* by panel and regime (expect: WF -> efficiency-gain / rebound-share;",
    "\n   food pillar -> stress-threshold, collapsing 0.396 frag -> 0.052 integ) ==\n")
df %>%
  group_by(response, governance) %>%
  slice_max(mu_star, n = 3, with_ties = FALSE) %>%
  arrange(response, governance, desc(mu_star)) %>%
  select(response, governance, parameter, mu_star, sigma) %>%
  as.data.frame() %>%
  print(row.names = FALSE)

p <- ggplot(df, aes(mu_star, sigma, colour = governance, shape = governance)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed",
              colour = "grey60", linewidth = 0.4) +
  geom_point(size = 2.4) +
  ggrepel::geom_text_repel(aes(label = parameter), size = 2.7,
                           max.overlaps = Inf, min.segment.length = 0,
                           seed = 1, show.legend = FALSE) +
  facet_wrap(~ response, scales = "free") +
  scale_colour_manual(values = gov_cols,  name = "Governance") +
  scale_shape_manual(values  = gov_shape, name = "Governance") +
  expand_limits(x = 0, y = 0) +
  labs(
    title    = "Morris elementary-effects screening",
    subtitle = "Points near the dashed \u03c3 = \u03bc* line indicate additive, non-interaction-dominated effects",
    x = expression(mu * "*" ~ "(mean absolute elementary effect)"),
    y = expression(sigma ~ "(standard deviation of elementary effects)")
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position  = "top",
    plot.title       = element_text(face = "bold"),
    strip.text       = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

ggsave(out_png, p, width = 9, height = 4.6, dpi = 300, bg = "white")
ggsave(out_pdf, p, width = 9, height = 4.6, device = cairo_pdf, bg = "white")
cat("\nSaved:", out_png, "and", out_pdf, "\n")