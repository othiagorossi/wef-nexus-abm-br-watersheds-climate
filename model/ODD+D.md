# ODD+D Protocol
## Modeling the Water–Energy–Food Nexus in Brazilian Periurban Watersheds

> **Reference:** Grimm et al. (2020). The ODD Protocol for Describing Agent-Based
> and Other Simulation Models: A Second Update to Improve Clarity, Replication,
> and Structural Realism. *Journal of Artificial Societies and Social Simulation*,
> 23(2), 7. https://doi.org/10.18564/jasss.4259

> **Model version:** 0.1.0  
> **NetLogo version:** 6.4.0  
> **Last updated:** 2026-04-24  
> **Status:** 🚧 Draft — to be completed during Phases 1–2

---

## OVERVIEW

### 1. Purpose and Patterns

**Purpose:**  
This model simulates Water–Energy–Food (WEF) nexus dynamics in a Brazilian
periurban watershed to investigate how institutional governance fragmentation
interacts with climate-driven water scarcity and distributed solar energy
adoption, generating emergent trade-offs and coordination failures across the
nexus. The model aims to quantify the aggregate effects of individual agent
decisions on water availability, energy production, and food output under
contrasting governance regimes and IPCC AR6 climate scenarios.

**Patterns used for calibration and validation:**
- Historical land use transition rates (MapBiomas 1985–2024)
- Observed distributed solar adoption curves (ANEEL 2012–2024)
- Annual water withdrawal volumes by sector (ANA, selected sub-basin)

---

### 2. Entities, State Variables, and Scales

#### Agents

| Agent Type | Description | Key State Variables |
|---|---|---|
| `periurban-farmer` | Smallholder farmer in the periurban fringe | `land-area`, `crop-type`, `water-demand`, `irrigation-technology`, `income`, `tenure-security` |
| `residential-consumer` | Urban household in the watershed | `water-consumption`, `energy-consumption`, `has-solar-panel` |
| `solar-prosumer` | Residential or farm unit with rooftop solar + irrigation pump | `solar-capacity-kW`, `pump-size-kW`, `water-withdrawal-rate`, `energy-balance` |
| `water-manager` | Institutional agent representing ANA / basin committee | `available-water-stock`, `granted-withdrawals`, `restriction-threshold`, `governance-mode` |

#### Environment (patches)

| Variable | Description | Source |
|---|---|---|
| `land-use` | Current land use class (agriculture / urban / native vegetation) | MapBiomas |
| `land-value` | Relative land market value index | TODO: proxy from municipal data |
| `soil-moisture` | Simplified soil water balance (mm) | Derived from precipitation + withdrawals |
| `slope` | Terrain slope (%) | SRTM DEM |

#### Scales

| Dimension | Value | Justification |
|---|---|---|
| Spatial extent | [TBD — bacia de estudo] | Sub-basin scale (< 5,000 km²) |
| Spatial resolution | 30 m × 30 m per patch | Matches MapBiomas resolution |
| Time step | 1 month | Seasonal agricultural and hydrological cycles |
| Simulation duration | 40 years (1985–2024 calibration; 2025–2065 projection) | Aligns with MapBiomas series and IPCC projections |

---

### 3. Process Overview and Scheduling

Each time step (month), the following processes execute in order:

1. **Climate forcing** — update precipitation and temperature from scenario data (SSP2-4.5 or SSP5-8.5)
2. **Hydrological update** — recalculate water stock in patches based on precipitation, evapotranspiration, and upstream flow
3. **Solar adoption decision** — prosumers evaluate whether to install/expand solar capacity (annual sub-step)
4. **Irrigation decision** — farmers decide how much to irrigate based on soil moisture, water cost, and pump capacity
5. **Water withdrawal** — aggregate withdrawals are summed; water manager evaluates against available stock and governance rules
6. **Crop yield calculation** — farmer income updated based on actual irrigation vs. water demand
7. **Land use transition decision** — farmers under financial pressure evaluate selling land; residential agents evaluate expansion
8. **Land use update** — patches change state based on transition decisions
9. **Data collection** — record WEF index components, withdrawals, land use shares, adoption rates

---

## DESIGN CONCEPTS

### 4. Design Concepts

**Basic principles:**  
The model draws on rational choice theory for agent decision-making, bounded
by institutional constraints (governance rules, access to credit, tenure
security). The WEF nexus is modeled as an emergent property of decentralized
individual decisions rather than a centrally planned allocation.

**Emergence:**  
- Solar pumping rebound effect (aggregate withdrawal increase from individual adoption decisions)
- Land use displacement cascade (urbanization displacing agriculture)
- Governance coordination failure (conflicting sectoral signals producing suboptimal aggregate outcomes)

**Adaptation:**  
Farmers adapt irrigation technology based on energy cost changes (solar
incentives). Prosumers adapt solar capacity based on payback period.
Water managers adapt restriction thresholds based on stock levels.

**Objectives:**  
- Farmers: maximize net income subject to water and land constraints
- Prosumers: minimize energy costs / maximize energy independence
- Water managers: maintain water stock above critical threshold

**Learning:**  
TODO: evaluate whether social learning (peer influence on solar adoption)
should be included — likely yes for prosumer diffusion.

**Prediction:**  
Agents use simple heuristics (if-then rules) rather than forward-looking
optimization, except water managers who use threshold-based rules.

**Sensing:**  
- Farmers sense: local soil moisture, water cost, energy cost, neighbor land use
- Prosumers sense: electricity tariff, solar incentive policy, neighbor adoption
- Water managers sense: aggregate withdrawal, water stock, governance mode

**Interaction:**  
- Farmers and managers interact through water permit system
- Prosumers and farmers interact through shared aquifer/river withdrawals
- Spatial neighbors influence land use transition decisions

**Stochasticity:**  
- Crop yield variability (weather noise around scenario mean)
- Land market shocks
- Solar adoption timing (stochastic within expected diffusion curve)

**Collectives:**  
- Basin committee (aggregation of water managers) — active only in integrated governance scenario
- Farmer cooperative (optional) — TBD

**Observation:**  
At each time step, record:
- Water availability index (current stock / long-term mean)
- Energy self-sufficiency index (local GD / total consumption)
- Food production index (periurban output / baseline)
- Composite WEF index (arithmetic mean of three normalized indices)
- Land use shares by class
- Total water withdrawals by agent type
- Number of solar prosumers

---

## DETAILS

### 5. Initialization

TODO: document initial conditions for each scenario after calibration.

- Initial land use: MapBiomas 1985 raster (reclassified)
- Initial water stock: ANA historical mean (1985–1990 average)
- Initial solar adoption: 0 (pre-GD era)
- Initial farmer population: [TBD from census data]

---

### 6. Input Data

| Dataset | File | Resolution | Processing script |
|---|---|---|---|
| MapBiomas LULC | `data/raw/MapBiomas/collection9_*.tif` | 30 m, annual | `analysis/01_preprocess.R` |
| ANA water withdrawals | `data/raw/ANA/outorgas_*.csv` | Municipal, annual | `analysis/01_preprocess.R` |
| ANEEL distributed solar | `data/raw/ANEEL/gd_solar_*.csv` | Municipal, monthly | `analysis/01_preprocess.R` |
| IPCC SSP2-4.5 precip. | `data/raw/IPCC/ssp245_pr_*.nc` | ~100 km, monthly | `analysis/01_preprocess.R` |
| IPCC SSP5-8.5 precip. | `data/raw/IPCC/ssp585_pr_*.nc` | ~100 km, monthly | `analysis/01_preprocess.R` |

See `data/README_data.md` for full provenance and download instructions.

---

### 7. Submodels

TODO: formalize equations for each submodel after implementation.

#### 7.1 Water Balance (patch-level)
```
W(t+1) = W(t) + Precip(t) - ET(t) - Withdrawal(t) + Upstream_inflow(t)
```

#### 7.2 Solar Adoption (prosumer agent)
Logistic diffusion based on payback period relative to peer adoption rate.
```
P_adopt(t) = f(payback_period, neighbor_adoption_rate, tariff_incentive)
```

#### 7.3 Irrigation Decision (farmer agent)
```
Irrigation(t) = min(Water_demand(t), Permitted_withdrawal, Pump_capacity)
if has_solar_pump: Pump_capacity = f(solar_irradiance, panel_size)
```

#### 7.4 Land Use Transition (farmer agent)
```
P_sell(t) = f(income_stress, land_value, tenure_security, urban_pressure)
```

#### 7.5 WEF Composite Index
```
WEF_index(t) = (W_norm(t) + E_norm(t) + F_norm(t)) / 3
```
where each component is normalized to [0,1] relative to baseline (S0).

---

## References

Grimm, V., et al. (2020). The ODD Protocol for Describing Agent-Based and
Other Simulation Models: A Second Update. *JASSS*, 23(2), 7.

Müller, B., et al. (2013). Describing Human Decisions in Agent-Based Models —
ODD+D, An Extension of the ODD Protocol. *Environmental Modelling & Software*, 48, 37–48.

[Additional references to be added during manuscript writing]
