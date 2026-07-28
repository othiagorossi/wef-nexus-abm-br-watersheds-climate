# Data Dictionary

Variables used across the model, analysis scripts, and outputs.
Model variables use **kebab-case** in NetLogo; analysis variables use
**snake_case** in R. This dictionary reflects the state variables actually
declared in `model/wef_nexus_watershed_alto_tiete.nlogox` (NetLogo 7.0.4).

---

## Agent / Spatial-Unit State Variables (NetLogo)

### `municipality` (36 units — the local resource manager)

| Variable | Type | Unit | Description |
|---|---|---|---|
| `ibge-code` | string | — | IBGE municipal code |
| `muni-name` | string | — | Municipality name |
| `area-native` | float | ha | Native vegetation area |
| `area-farming` | float | ha | Agricultural area |
| `area-urban` | float | ha | Urban area |
| `area-water` | float | ha | Water-body area |
| `area-pv` | float | ha | Photovoltaic (solar plant) area |
| `area-other` | float | ha | Other / non-vegetated area |
| `total-area` | float | ha | Sum of all land-cover areas |
| `water-demand-irrigation` | float | m³/year | Aggregate irrigation demand (ANA-derived) |
| `baseline-water-capacity` | float | m³/year | Permitted water availability (ANA-derived) |
| `water-available` | float | m³/year | Availability after climate forcing |
| `water-stress` | float | ratio | Governance-adjusted demand / availability (cost; may exceed 1) |
| `restriction-level` | float | [0,1] | Restriction coefficient applied under fragmented governance |

### `farmer` (nested within a municipality)

| Variable | Type | Unit | Description |
|---|---|---|---|
| `home-muni` | agent | — | Municipality the farmer belongs to |
| `farm-area` | float | ha | Farmed area |
| `crop-water-demand` | float | model units | Ideal crop water requirement (`farm-area × base-water-per-ha`) |
| `has-solar-pump?` | bool | — | Whether the farmer has adopted a solar pump |
| `irrigation-demanded` | float | model units | Water demanded after adoption-driven demand fraction |
| `irrigation-applied` | float | model units | Water actually applied after restriction |
| `income` | float | BRL | Net farming income |
| `tenure-security` | float | [0,1] | Land-tenure security (assigned at setup, 0.4–1.0) |
| `sell-pressure` | float | [0,1] | Propensity to exit farming |

> **Prosumers are endogenous.** There is no separately populated prosumer agent:
> a farmer becomes a rural solar prosumer when `has-solar-pump?` toggles to
> `true` during the solar-adoption submodel. (A `prosumer` breed is declared in
> the source for extensibility but is not instantiated in this version.)

---

## Global Parameters (set in `set-parameters`)

| Parameter | Value | Unit | Role |
|---|---|---|---|
| `start-year` / `end-year` | 1985 / 2065 | year | Simulation horizon |
| `hectares-per-farmer` | 100 | ha | Farmers created per unit farming area |
| `solar-start-year` | 2013 | year | Solar adoption onset |
| `solar-innovation-coef` | 0.003 | — | Bass diffusion — innovation |
| `solar-imitation-coef` | 0.25 | — | Bass diffusion — imitation |
| `max-solar-adoption` | 0.20 | fraction | Municipal adoption ceiling |
| `base-water-per-ha` | 0.5 | model units/ha | Baseline crop water coefficient |
| `no-pump-irrigation-frac` | 0.55 | fraction | Demand fraction without solar pump |
| `solar-pump-irrigation-frac` | 0.95 | fraction | Demand fraction with solar pump (rebound) |
| `stress-threshold` | 0.8 | ratio | Stress level triggering restriction |
| `restriction-strength` | 0.5 | [0,1] | Restriction applied when triggered |
| `integrated-efficiency-gain` | 0.3 | fraction | Demand-side saving under integrated governance |
| `base-conversion-rate` | 0.0013 | /year | Base farming→urban conversion rate |
| `urban-pressure-coef` | 0.5 | — | Urban-share multiplier on conversion |
| `water-stress-exit-coef` | 0.3 | — | Water-stress multiplier on conversion |
| `warming-ssp245` | 1.4 | °C | Mid-century warming, SSP2-4.5 |
| `warming-ssp585` | 2.1 | °C | Mid-century warming, SSP5-8.5 |
| `et-sensitivity` | 0.04 | /°C | Fractional water loss per +1 °C |
| `climate-onset-year` | 2025 | year | Start of climate forcing ramp |

---

## Global Nexus Indices (NetLogo → recorded per tick)

| Variable | Unit | Definition |
|---|---|---|
| `basin-water-index` | [0,1] | Unweighted municipal mean of `1 − min(1, water-stress)` (benefit; higher = better) |
| `basin-food-index` | [0,1] | Demand-weighted `Σ irrigation-applied / Σ irrigation-demanded` over farmers |
| `basin-energy-index` | [0,1] | `min(1, adopted-fraction / max-solar-adoption)` — **descriptive; not in composite** |
| `basin-wef-index` | [0,1] | Composite = `(basin-water-index + basin-food-index) / 2` (water + food only) |

---

## Output / Analysis Variables (R — BehaviorSpace export)

| Variable | Unit | Description |
|---|---|---|
| `run` | int | BehaviorSpace run identifier |
| `climate` | string | `historical` / `ssp245` / `ssp585` |
| `governance` | string | `fragmented` / `integrated` |
| `year` | year | Simulation year |
| `water_index` | [0,1] | `basin-water-index` |
| `food_index` | [0,1] | `basin-food-index` |
| `energy_index` | [0,1] | `basin-energy-index` (descriptive) |
| `wef_index` | [0,1] | `basin-wef-index` — mean of water and food |
| `urban_pct` / `farming_pct` | % | Basin urban / farming share |
| `n_farmers` | count | Active farmer agents |
| `solar_pumps` | count | Farmers with a solar pump |

> The composite reported in the paper is the Water–Food index,
> `wf = (water_index + food_index) / 2`. Energy is reported
> descriptively as the driver of the pumping rebound.

---

## Scenario Identifiers

| ID | Climate | Governance | Description |
|---|---|---|---|
| S0 | Historical | Fragmented | Baseline (validation) |
| S1 | SSP2-4.5 | Fragmented | Moderate climate, status quo governance |
| S2 | SSP5-8.5 | Fragmented | High emissions, status quo governance |
| S3 | Historical | Integrated | Baseline climate, coordinated governance |
| S4 | SSP2-4.5 | Integrated | Moderate climate, coordinated governance |
| S5 | SSP5-8.5 | Integrated | High emissions, coordinated governance |