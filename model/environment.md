# Computational Environment

## ABM — NetLogo

| Item | Value |
|---|---|
| NetLogo version | 7.0.4 |
| Download | https://ccl.northwestern.edu/netlogo/download.shtml |
| Extensions used | `csv` (built-in) |
| Main model file | `model/wef_nexus_watershed_alto_tiete.nlogox` |
| Tested on | Ubuntu 24.04, Windows 11 |

> ⚠️ NetLogo **7.x is required**. The model is stored in the NetLogo 7 XML
> format (`.nlogox`); open and edit it only through the NetLogo Code tab and
> save with Ctrl+S. Do not edit `.nlogox` in a plain-text editor — it corrupts
> the XML. Earlier NetLogo versions (≤ 6.x) cannot open this file.

## Statistical Analysis — R

| Package | Version | Purpose |
|---|---|---|
| `tidyverse` | ≥ 2.0.0 | Data wrangling and visualization (dplyr, tidyr, ggplot2, readr, stringr, purrr) |
| `here` | ≥ 1.0 | Project-root-relative paths |
| `sf` | ≥ 1.0 | Vector geospatial data (basin / municipality shapefiles for the map) |
| `patchwork` | ≥ 1.2 | Multi-panel figure composition |
| `ggrepel` | ≥ 0.9 | Non-overlapping labels (Morris plot) |
| `scales` | ≥ 1.3 | Axis formatting |
| `logolink` | ≥ 0.1 | NetLogo (≥ 7) — R bridge for headless / Morris runs |
| `sensitivity` | ≥ 1.29 | Morris elementary-effects screening (μ*, σ) |
| `renv` | ≥ 1.0 | Environment reproducibility |

> **Note:** `nlrx` is **not** used — it is incompatible with NetLogo ≥ 7.
> The NetLogo–R bridge is `logolink`. Sensitivity analysis uses the **Morris**
> method (elementary-effects screening), **not** Sobol indices.

To restore the exact R environment:
```r
install.packages("renv")
renv::restore()
```

## System Information (development machine)

```
OS: Ubuntu 24.04 LTS
R:  4.4.x
Java: 17+ (required by NetLogo 7)
RAM: >= 8 GB recommended
```

## Reproducibility Notes

- Scenario batch runs use NetLogo **BehaviorSpace** (6 scenarios × 50 replicates
  = 300 runs); BehaviorSpace assigns a distinct random seed per run.
- Morris sensitivity screening is executed through `logolink` from R.
- Climate and land-cover inputs are supplied as pre-processed CSVs
  (IPCC AR6 regional warming deltas; MapBiomas Collection 10.1 municipal
  statistics) — no NetCDF or raster processing is required at model runtime.
- The R analysis pipeline is deterministic given the same BehaviorSpace export.