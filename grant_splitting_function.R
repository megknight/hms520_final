######################################################################################
## Author: Ian Cogswell                                                             ##
## Purpose: Create grant_splitting                                                  ## 
######################################################################################
grant_splitting <- function(dataset, country_col, dah_col, separator) {
  
  #' Function to split grant funding evenly among countries in single column with separator
  #' @param dataset [data.frame/data.table] Dataset to grant split
  #' @param country_col [str] Name of the column containing the countries to split funding among
  #' @param dah_col [str] Name of the column containing the funding value to be split
  #' @param separator [str] Symbols between country names or codes

  
  # Change to datatable
  dt <- setDT(copy(dataset))
  
  # Calculate number of countries to split between 
  dt[, N := count.fields(textConnection(get(country_col)), sep = separator)]
  
  # Create country columns to fill with country names
  country_cols <- rep(paste0('countryname_', 1:max(dt$N, na.rm = T)))
  
  # Split countries among columns
  dt[, c(country_cols) := tstrsplit(get(country_col), separator, fixed = TRUE)]

  # Data wide to long by country names
  dt <- melt.data.table(dt,
                        measure.vars = country_cols,
                        variable.factor = F,
                        na.rm = T)
  
  # Split grant money according to number of countries
  dt[, DAH := DAH / N]

  # Remove columns
  dt[, c('N', 'variable') := NULL]

  return(dt)
  
}
  
    
    