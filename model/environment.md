# Computational Environment

## ABM — NetLogo

| Item | Value |
|---|---|
| NetLogo version | 6.4.0 |
| Download | https://ccl.northwestern.edu/netlogo/download.shtml |
| Extensions used | `gis` (built-in), `csv` (built-in), `rnd` (built-in) |
| Main model file | `wef_nexus.nlogo` |
| Tested on | Ubuntu 24.04, macOS 14 (Sonoma), Windows 11 |

> ⚠️ Do NOT use NetLogo versions < 6.3 — `gis` extension behavior differs.

## Statistical Analysis — R

| Package | Version | Purpose |
|---|---|---|
| `tidyverse` | ≥ 2.0.0 | Data wrangling and visualization |
| `terra` | ≥ 1.7 | Raster processing (MapBiomas GeoTIFFs) |
| `sf` | ≥ 1.0 | Vector geospatial data |
| `ggplot2` | ≥ 3.5 | Manuscript figures |
| `patchwork` | ≥ 1.2 | Figure composition |
| `sensitivity` | ≥ 1.29 | Sensitivity analysis (Sobol indices) |
| `nlrx` | ≥ 0.4 | NetLogo–R interface for BehaviorSpace runs |
| `renv` | ≥ 1.0 | Environment reproducibility |

To restore the exact R environment:
```r
install.packages("renv")
renv::restore()
```

## System Information (development machine)

```
OS: Ubuntu 24.04 LTS
R:  4.4.x
Java: 17+ (required by NetLogo)
RAM: ≥ 8 GB recommended for MapBiomas rasters
```

## Reproducibility Notes

- All random seeds are set explicitly in both NetLogo (`random-seed`) and R (`set.seed()`)
- Seed values are documented in each scenario configuration
- Batch runs use NetLogo BehaviorSpace, called via `nlrx` from R
- Outputs are deterministic given the same seed and input data
