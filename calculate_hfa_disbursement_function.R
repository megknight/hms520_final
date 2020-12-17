######################################################################################
## Author: Ian Cogswell                                                             ##
## Purpose: Create calculate_hfa_disbursement                                       ## 
######################################################################################
calculate_hfa_disbursement <- function(dataset) {
  
  #' Function to calculate hfa disbursements using keyword search output fractions and test to ensure correct total
  #' @param dataset [data.frame/data.table] Dataset post keyword search

  # Change to datatable
  dt <- setDT(copy(dataset))
  
  # Create column to split
  dt[, amount_split := DAH]
  
  # Get kws fraction columns
  to_eval <- colnames(dt)[colnames(dt) %like% '_frct' & colnames(dt) != 'final_total_frct']
  
  # Remove '_frct' from columns for new column names
  to_eval <- gsub('_frct', '', to_eval)
  
  # Loop through hfas to calculate new values
  for (col in to_eval) {
    dt[, eval(col) := get(eval(paste0(col, '_frct'))) * amount_split]
    dt[, eval(paste0(col, '_frct')) := NULL]
  }

  # Check that hfas add to total DAH
  dt2 <- dt[, c(to_eval), with = F]
  dt2 <- rowSums(dt2)
  dt2 <- cbind(dt, dt2)
  dt2[, check := amount_split - dt2]
  
  # Return error if not all zeros
  if (sum(dt2$check) != 0) {
    stop('    STOP: HFA VALUES NOT ADDING TO TOTAL. PLEASE INVESTIGATE DATA PRE KEYWORD SEARCH FOR ERRORS'))
  }
  
  return(dt)
  
}
  
  