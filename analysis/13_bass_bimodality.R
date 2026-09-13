library(dplyr); library(readr); library(tidyr); library(diptest); library(e1071); library(ggplot2)

raw <- read_csv("outputs/tables/factorial_governance_efficiency_bass.csv", skip = 6, show_col_types = FALSE)
names(raw) <- trimws(names(raw))
d <- raw %>%
  rename(climate=`climate-scenario`, gov=`governance-mode`, eps=`efficiency-gain`,
         u=`initial-utilisation`, year=`current-year`, WF=`basin-wef-index`) %>%
  filter(eps == 0, u == 1.3, year == 2065)
d$climate <- factor(d$climate, levels=c("historical","ssp245","ssp585"),
                    labels=c("Historical","SSP2-4.5","SSP5-8.5"))
d$gov <- factor(d$gov, levels=c("fragmented","calibrated-cut","solar-gating","integrated"))

dip_tab <- d %>% group_by(climate, gov) %>%
  summarise(n=n(), dip=dip.test(WF)$statistic, p=dip.test(WF)$p.value,
            sd=sd(WF), skew=e1071::skewness(WF), .groups="drop") %>%
  mutate(bimodal_p05 = p < 0.05)
print(dip_tab, n=Inf)

d %>% group_by(climate, gov) %>% summarise(sd=sd(WF), .groups="drop") %>%
  pivot_wider(names_from=gov, values_from=sd) %>%
  mutate(ratio = fragmented / `calibrated-cut`) %>% print()

p <- ggplot(d, aes(WF, fill=gov, colour=gov)) +
  geom_density(alpha=0.2, adjust=1) + facet_wrap(~climate, ncol=1, scales="free_y") +
  labs(x="Composite Water–Food index (2065)", y="Density", fill="Governance", colour="Governance",
       title="Predictability is an outcome of governance",
       subtitle="Fragmented widens variance and the low-performance tail; coordination collapses it") +
  theme_minimal(base_size=11)
ggsave("outputs/figures/fig_variance_governance.png", p, width=7, height=8, dpi=300)