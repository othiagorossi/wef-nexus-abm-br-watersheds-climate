if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")

renv::init()

packages <- c(
  # tidyverse
  "tidyverse",    
  "here",         
  # spatial
  "sf",           
  "terra",        
  # data cleaning
  "janitor",      
  "abjutils",     
  # Download
  "httr2",        
  # stats
  "broom",        
  "rstatix",      
  "emmeans",      
  "car",          
  "nortest",      
  # visualization
  "glue",         
  "scales",       
  "patchwork",    
  "gt"            
)

install.packages(packages)

renv::snapshot()

message("\nEnvironment ready. Use renv::restore() in any new machine.")
message("Next step: run analysis/00_download.R")
