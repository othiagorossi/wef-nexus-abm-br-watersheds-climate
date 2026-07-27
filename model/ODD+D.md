# ODD+D Protocol
## Modeling the Water–Energy–Food Nexus in Brazilian Periurban Watersheds

> **Reference:** Grimm et al. (2020). The ODD Protocol for Describing Agent-Based
> and Other Simulation Models: A Second Update to Improve Clarity, Replication,
> and Structural Realism. *Journal of Artificial Societies and Social Simulation*,
> 23(2), 7. https://doi.org/10.18564/jasss.4259

> **Model version:** 1.0.0  
> **NetLogo version:** 7.0.4  
> **Last updated:** [26 July 2026]
> **Status:** Revised

---

## OVERVIEW

### 1. Purpose and Patterns

**Purpose:**  
This model simulates Water–Energy–Food (WEF) nexus dynamics in the Brazilian periurban watershed of the Alto Tietê (UGRHI 6). It investigates how institutional governance fragmentation interacts with climate-driven water scarcity and distributed solar energy adoption. The model aims to quantify the aggregate effects of decentralized agent decisions on water stress, agricultural food production, and land-use transitions under contrasting governance regimes (fragmented vs. integrated) and IPCC AR6 climate scenarios (SSP2-4.5 and SSP5-8.5).

**Patterns used for calibration and validation:**
- Historical land use transition rates, specifically the urbanization of agricultural land (MapBiomas Collection 10.1, 1985–2024).
- Observed distributed rural solar adoption diffusion curves (ANEEL, 2012–2024).
- Spatial co-location of water demand and solar capacity (ANA water use permits).

---

### 2. Entities, State Variables, and Scales

#### Agents and Spatial Units

| Entity | Description | Key State Variables |
|---|---|---|
| `municipality` | Spatial and administrative unit (36 in the basin). Acts as the local resource manager. | `ibge-code`, `muni-name`, `area-native`, `area-farming`, `area-urban`, `baseline-water-capacity`, `water-available`, `water-demand-irrigation`, `water-stress`, `restriction-level` |
| `farmer` | Smallholder farmer operating within a municipality. | `home-muni`, `farm-area`, `crop-water-demand`, `has-solar-pump?`, `irrigation-demanded`, `irrigation-applied` |

*(Note: Solar prosumers are modeled endogenously when a `farmer` adopts a solar pump, toggling their `has-solar-pump?` state to true).*

#### Scales

| Dimension | Value | Justification |
|---|---|---|
| Spatial extent | Alto Tietê Basin (UGRHI 6) | Densely urbanized core surrounded by a periurban fringe (~5,900 km²). |
| Spatial resolution| Municipality level | Matches the institutional resolution of ANEEL and demographic data; farmers are heterogeneous agents nested within these units. |
| Time step | 1 Year | Captures annual agricultural, hydrological, and land-use cycles. |
| Simulation duration | 80 years (1985–2065) | 1985–2024 for initialization/calibration; 2025–2065 for IPCC SSP projections and scenario analysis. |

---

### 3. Process Overview and Scheduling

Each annual time step (`tick`), the following processes execute in strict order:

1. **Update Climate:** Calculates the temperature anomaly based on the selected IPCC scenario (historical, SSP2-4.5, or SSP5-8.5) and defines the `climate-availability-factor`.
2. **Update Hydrology:** Municipalities adjust their `water-available` by applying the climate availability factor to their baseline permitted capacity.
3. **Solar Adoption Decision:** Starting in 2013, non-adopting farmers probabilistically adopt solar pumps based on a Bass-type diffusion model (innovation + local imitation), up to a municipal adoption ceiling.
4. **Irrigation Decision (Rebound Stage 1):** Farmers calculate their `irrigation-demanded`. Farmers with solar pumps demand a higher fraction of their ideal crop water requirement due to near-zero marginal pumping costs.
5. **Water Allocation (Governance):** Municipalities calculate aggregate `water-stress`. 
    - Under *Integrated Governance*, demand is reduced at the source via an efficiency gain constraint. 
    - Under *Fragmented Governance*, if stress exceeds the `stress-threshold`, a `restriction-level` is triggered, reducing the actual `irrigation-applied` to farmers post-demand.
6. **Land-Use Transition:** Municipalities calculate the agricultural-to-urban conversion rate based on urban pressure and local water stress. Farming area is reduced, urban area grows, and a proportional fraction of farmer agents are probabilistically removed from the system.
7. **Update Nexus Indices:** The aggregate Basin Water Index, Food Index, Energy Driver Index, and the Composite WEF Index are calculated and recorded.

---

## DESIGN CONCEPTS

### 4. Design Concepts

**Basic principles:**  
The model operationalizes the *Jevons Paradox* (rebound effect) within a socio-hydrological system. Subsidized or cost-free technological efficiency (solar pumping) leads to greater resource extraction unless constrained by integrated governance. Institutional compartmentalization acts as a structural context driving coordination failures.

**Emergence:**  
- *Solar Pumping Rebound Effect:* Aggregate irrigation abstraction rises without any new farmland.
- *Land-use Displacement Cascade:* Water stress and urban proximity drive farmers to exit, reducing the local food supply capacity.
- *Governance Coordination Failures:* Fragmented rules lead to emergency water restrictions that crash food production, a trade-off avoided under integrated governance.

**Adaptation:**  
- *Farmers:* Autonomously adopt solar technologies influenced by peer networks, and exit farming when land-use pressure becomes untenable.
- *Institutions (Municipalities):* Adapt water delivery via restrictions when the resource buffer is breached.

**Objectives:**  
Farmers attempt to meet their crop water demand to maximize yield. Water managers (municipalities under fragmented rules) attempt to keep water stress below critical thresholds using blunt restrictions.

**Sensing:**  
- Farmers sense the share of solar adoption among peers in their municipality.
- Municipalities sense the aggregate water demand of their nested farmers relative to their `baseline-water-capacity`.

**Interaction:**  
- *Information exchange:* Farmers imitate the technology adoption of other farmers within the same municipality.
- *Resource competition:* Farmers compete for the municipal water budget, where the collective demand generates systemic stress affecting all local users.

**Stochasticity:**  
- Solar pump adoption is evaluated against a uniform random float (`random-float 1 < p`).
- Farmer exit during land-use transition (urbanization) is stochastic (`random-float 1 < exit-frac`).
- `tenure-security` is randomly assigned at setup (0.4 to 1.0).

**Observation:**  
Key outputs recorded at each time step include:
- `basin-wef-index`: Arithmetic mean of Water and Food indices.
- `basin-water-index`: 1 minus the mean water stress.
- `basin-food-index`: Ratio of total `irrigation-applied` to `irrigation-demanded`.
- `basin-energy-index`: Share of rural solar diffusion (acts as the rebound driver, reported separately).
- Land-use trajectories (`area-farming`, `area-urban`).

---

## DETAILS

### 5. Initialization

The model is initialized at year `1985` (tick 0).
- **Municipalities:** Initialized using `municipality_initial_conditions.csv`. Land-use areas (Native, Farming, Urban, Water, PV, Other) are set using MapBiomas Collection 10.1 data for 1985. `baseline-water-capacity` and `water-demand-irrigation` are set using ANA permit databases.
- **Farmers:** Generated proportionally to the initial `area-farming` of each municipality (default: 1 agent per 100 hectares). All farmers start with `has-solar-pump? = false`.
- **Global Variables:** Climate scenarios and governance modes are selected via user interface or BehaviorSpace setup prior to tick 0.

---

### 6. Input Data

| Dataset | Source | Purpose |
|---|---|---|
| Land Use / Land Cover | MapBiomas Col. 10.1 (1985-2024) | Baseline areas and calibration target for the transition cascade. |
| Water Use Permits | ANA (Agência Nacional de Águas) | Proxies for municipal baseline water availability and initial irrigation demand. |
| Distributed Generation | ANEEL (Law 14.300/2022) | Observed spatial footprint and empirical target for the rural solar diffusion curve. |
| Climate Projections | IPCC AR6 (CMIP6) | Defines temperature anomalies (+1.4°C for SSP2-4.5; +2.1°C for SSP5-8.5 by mid-century). |

*(All preprocessing is fully documented and reproducible via R scripts `00_download.R` through `01e_model_inputs.R`).*

---

### 7. Submodels

#### 7.1 Climate and Hydrology
Temperature anomalies increase linearly from 2025 to 2050 based on the SSP scenario. The effective water availability drops due to warming-driven evapotranspiration (ET):
```text
temp-anomaly = target-warming * ((current-year - 2025) / (2050 - 2025))
water-available = baseline-water-capacity * (1 - (et-sensitivity * temp-anomaly))

```

#### 7.2 Solar Adoption

Executes only if `current-year >= 2013`. Uses a Bass-diffusion logic capped at `max-solar-adoption`:

```text
adopted-share = (adopting farmers in muni) / (total farmers in muni)
Probability of adoption (p) = solar-innovation-coef + (solar-imitation-coef * adopted-share)

```

#### 7.3 Irrigation Decision

Calculates the theoretical crop demand and the fraction actually demanded based on marginal pumping costs:

```text
crop-water-demand = farm-area * base-water-per-ha
If has-solar-pump? == true: 
    irrigation-demanded = crop-water-demand * solar-pump-irrigation-frac
Else: 
    irrigation-demanded = crop-water-demand * no-pump-irrigation-frac

```

#### 7.4 Water Allocation and Governance

Aggregates demand and applies policy logic:

```text
If Governance == "integrated":
    effective-demand = total-demanded * (1 - integrated-efficiency-gain)
Else:
    effective-demand = total-demanded

water-stress = effective-demand / water-available

If water-stress > stress-threshold (Fragmented Governance):
    restriction-level = restriction-strength
    irrigation-applied = irrigation-demanded * (1 - restriction-level)
Else:
    irrigation-applied = irrigation-demanded

```

#### 7.5 Land-Use Displacement Cascade

Simulates urban sprawl and farm abandonment:

```text
urban-share = area-urban / total-area
conversion-rate = base-conversion-rate * (1 + urban-pressure-coef * urban-share) * (1 + water-stress-exit-coef * water-stress)

area-farming(t+1) = area-farming(t) - (area-farming(t) * conversion-rate)
area-urban(t+1) = area-urban(t) + (area-farming(t) * conversion-rate)

Farmers are stochastically removed (`die`) proportional to the fraction of farming area lost.