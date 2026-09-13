library(dplyr); library(readr); library(tidyr); library(ggplot2)

f_c2 <- "outputs/tables/factorial_governance_efficiency_bass.csv"
raw <- read_csv(f_c2, skip = 6, show_col_types = FALSE); names(raw) <- trimws(names(raw))

d <- raw %>%
  rename(climate=`climate-scenario`, gov=`governance-mode`, eps=`efficiency-gain`,
         u=`initial-utilisation`, year=`current-year`,
         WF=`basin-wef-index`, water=`basin-water-index`, food=`basin-food-index`) %>%
  filter(eps == 0, u == 1.3, year == 2065)

clim_lab <- c(historical="Historical", ssp245="SSP2-4.5", ssp585="SSP5-8.5")
gov_lev  <- c("fragmented","calibrated-cut","solar-gating","integrated")
d$climate <- factor(d$climate, levels=names(clim_lab), labels=clim_lab)
d$gov     <- factor(d$gov, levels=gov_lev)

table5 <- d %>% group_by(climate, gov) %>%
  summarise(n=n(), mean_WF=mean(WF), sd=sd(WF), mcse=sd(WF)/sqrt(n()),
            cv_pct=100*sd(WF)/mean(WF), .groups="drop")
print(table5, n=Inf)
write_csv(table5, "outputs/tables/table5_mc_precision.csv")

pil <- d %>% filter(gov %in% c("fragmented","integrated")) %>%
  group_by(climate, gov) %>%
  summarise(Water=mean(water), Food=mean(food), .groups="drop") %>%
  pivot_longer(c(Water,Food), names_to="pillar", values_to="value")
pil$gov <- factor(pil$gov, levels=c("fragmented","integrated"),
                  labels=c("Fragmented","Integrated"))
p1 <- ggplot(pil, aes(gov, value, fill=pillar)) +
  geom_col(position=position_dodge(0.75), width=0.7) +
  geom_text(aes(label=sprintf("%.2f", value)),
            position=position_dodge(0.75), vjust=-0.4, size=2.8) +
  facet_wrap(~climate) +
  scale_fill_manual(values=c(Water="#4C78A8", Food="#E45756")) +
  labs(x=NULL, y="Pillar sub-index (0–1)", fill="Pillar",
       title="Pillar decomposition: governance reallocates the water–food trade-off") +
  ylim(0, 1.1) + theme_minimal(base_size=11) + theme(legend.position="bottom")
ggsave("outputs/figures/14_fig_pillar_decomposition.png", p1, width=10, height=4.2, dpi=300)
ggsave("outputs/figures/14_fig_pillar_decomposition.pdf", p1, width=10, height=4.2, device=cairo_pdf)

p2 <- ggplot(d, aes(climate, WF, fill=gov)) +
  geom_boxplot(outlier.shape=NA, alpha=0.75, position=position_dodge(0.8), width=0.7) +
  scale_fill_manual(values=c(fragmented="#E45756", `calibrated-cut`="#54A24B",
                             `solar-gating`="#F58518", integrated="#4C78A8"),
                    name="Governance") +
  labs(x=NULL, y="Composite Water–Food index (2065)",
       title="Composite by scenario: coordinated regimes separate only under climate stress, with far lower variance") +
  theme_minimal(base_size=11) + theme(legend.position="bottom")
ggsave("outputs/figures/14_fig_composite_by_scenario.png", p2, width=10, height=5, dpi=300)
ggsave("outputs/figures/14_fig_composite_by_scenario.pdf", p2, width=10, height=5, device=cairo_pdf)