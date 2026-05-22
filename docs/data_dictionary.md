# Data Dictionary

Variables used across model, analysis scripts, and outputs.
All variables use **snake_case** in R and **kebab-case** in NetLogo.

---

## Agent State Variables (NetLogo)

### periurban-farmer
| Variable | Type | Unit | Description |
|---|---|---|---|
| `land-area` | float | ha | Total farmed area |
| `crop-type` | string | — | Dominant crop (vegetables / fruits / grains) |
| `water-demand` | float | m³/month | Crop water requirement under optimal conditions |
| `actual-irrigation` | float | m³/month | Actual irrigation applied (may be < demand if restricted) |
| `irrigation-tech` | string | — | Irrigation technology (sprinkler / drip / flood) |
| `has-solar-pump` | bool | — | Whether farmer has solar-powered pump |
| `income` | float | BRL/month | Net farming income |
| `tenure-security` | float | [0,1] | Index of land tenure security (1 = formal title) |
| `sell-pressure` | float | [0,1] | Probability of selling land in current step |

### solar-prosumer
| Variable | Type | Unit | Description |
|---|---|---|---|
| `solar-capacity` | float | kWp | Installed solar panel capacity |
| `pump-capacity` | float | kW | Irrigation pump motor capacity |
| `energy-generated` | float | kWh/month | Monthly solar generation |
| `water-withdrawal` | float | m³/month | Water pumped for irrigation |
| `payback-period` | float | years | Estimated payback period at adoption |

### water-manager
| Variable | Type | Unit | Description |
|---|---|---|---|
| `water-stock` | float | Mm³ | Available water in managed reservoir/river reach |
| `total-grants` | float | m³/month | Sum of all active withdrawal permits |
| `restriction-level` | float | [0,1] | Current restriction coefficient (0 = no restriction) |
| `governance-mode` | string | — | "fragmented" or "integrated" |

---

## Patch (environment) Variables

| Variable | Type | Unit | Description |
|---|---|---|---|
| `land-use` | string | — | Current class: agriculture / urban / native / water |
| `soil-moisture` | float | mm | Soil water content |
| `land-value-index` | float | [0,1] | Relative land market pressure |
| `slope` | float | % | Terrain slope |
| `upstream?` | bool | — | Whether patch is upstream in watershed |

---

## Output / Analysis Variables (R)

| Variable | File | Unit | Description |
|---|---|---|---|
| `water_index` | outputs/tables/ | [0,1] | Water availability normalized to baseline |
| `energy_index` | outputs/tables/ | [0,1] | Local GD / total consumption |
| `food_index` | outputs/tables/ | [0,1] | Periurban food output normalized to baseline |
| `wef_index` | outputs/tables/ | [0,1] | Mean of three indices above |
| `rebound_rate` | outputs/tables/ | % | Increase in water withdrawal per unit of solar adoption |
| `lulc_agri_share` | outputs/tables/ | % | % of basin area in agricultural use |
| `lulc_urban_share` | outputs/tables/ | % | % of basin area in urban use |
| `n_prosumers` | outputs/tables/ | count | Number of solar prosumer agents |

---

## Scenario Identifiers

| ID | Climate | Governance | Description |
|---|---|---|---|
| S0 | Historical | Fragmented | Baseline (calibration) |
| S1 | SSP2-4.5 | Fragmented | Moderate climate, status quo governance |
| S2 | SSP5-8.5 | Fragmented | High emissions, status quo governance |
| S3 | SSP2-4.5 | Integrated | Moderate climate, coordinated policy |
| S4 | SSP5-8.5 | Integrated | High emissions, coordinated policy |
