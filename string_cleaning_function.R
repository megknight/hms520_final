######################################################################################
## Author: Megan Knight                                                             ##
## Purpose: Create string_clean function                                            ## 
######################################################################################
string_clean <- function(dataset, col_to_clean) {
  #' Function to clean special characters, remove punctuation, and add spacing
  #' to the specified col_to_clean
  #' @param dataset [data.frame/data.table] Dataset to clean strings in
  #' @param col_to_clean [str] Name of the column containing strings to clean
  
  # cast dataset as a data.table
  dataset <- setDT(copy(dataset))
  
  ## create not-in function 
  '%ni%' <- Negate('%in%')
  
  # handle user errors
  if (col_to_clean %ni% names(dataset)) {
    stop('    SUPPLIED INVALID PARAMETER: [col_to_clean]!! ENSURE [col_to_clean] IS ONE OF THE FOLLOWING: ', paste(names(dataset), collapse=', '))
  }
  
  # prep dataset
  new_col <- paste0('upper_', col_to_clean)
  dataset[, eval(new_col) := get(col_to_clean)]
  
  # clean strings
  dataset[, eval(new_col) := gsub('ÿ', "Y",  get(new_col))]
  dataset[, eval(new_col) := gsub('Ÿ', "Y",  get(new_col))]
  dataset[, eval(new_col) := gsub('æ', "AE", get(new_col))]
  dataset[, eval(new_col) := gsub('Æ', "AE", get(new_col))]
  dataset[, eval(new_col) := gsub('œ', "OE", get(new_col))]
  dataset[, eval(new_col) := gsub('Œ', "OE", get(new_col))]
  dataset[, eval(new_col) := gsub('ç', "C",  get(new_col))]
  dataset[, eval(new_col) := gsub('Ç', "C",  get(new_col))]
  dataset[, eval(new_col) := gsub('ñ', "N",  get(new_col))]
  dataset[, eval(new_col) := gsub('Ñ', "N",  get(new_col))]
  dataset[, eval(new_col) := gsub('ß', "SS", get(new_col))]
  
  dataset[, eval(new_col) := gsub('/'," ", get(new_col))]
  dataset[, eval(new_col) := gsub(':', " ", get(new_col))]
  dataset[, eval(new_col) := gsub(';', " ", get(new_col))]
  dataset[, eval(new_col) := gsub('-', " ", get(new_col))]

  dataset[, eval(new_col) := gsub('.', " ", get(new_col), fixed = T, useBytes = T)]
  dataset[, eval(new_col) := gsub(',', " ", get(new_col))]
  dataset[, eval(new_col) := gsub("'", " ", get(new_col))]
  dataset[, eval(new_col) := gsub('(', " ", get(new_col), fixed = T, useBytes = T)]
  dataset[, eval(new_col) := gsub(')', " ", get(new_col))]
  dataset[, eval(new_col) := gsub('THE', " ", get(new_col))]
  dataset[, eval(new_col) := gsub('&', " ", get(new_col))]
  dataset[, eval(new_col) := gsub('AND', " ", get(new_col))]
  
  # replace A's
  letters <- c("á", "Á", "à", "À", "ã", "Ã", "â", "Â", "å", "Å", "ä", "Ä")
  for (l in 1:length(letters)) {
    letter <- letters[l]
    dataset[, eval(new_col) := gsub(letter, "A", get(new_col))]
  }
  
  # replace E's
  letters <- c("é", "É", "ê", "Ê", "è", "È", "ë", "Ë")
  for (l in 1:length(letters)) {
    letter <- letters[l]
    dataset[, eval(new_col) := gsub(letter, "E", get(new_col))]
  }
  
  # replace I's
  letters <- c("í", "Í", "ì", "Ì", "î", "Î", "ï", "Ï")
  for (l in 1:length(letters)) {
    letter <- letters[l]
    dataset[, eval(new_col) := gsub(letter, "I", get(new_col))]
  }
  
  # replace O's
  letters <- c("ó", "Ó", "ò", "Ò", "õ", "Õ", "ô", "Ô", "ø", "Ø", "ö", "Ö")
  for (l in 1:length(letters)) {
    letter <- letters[l]
    dataset[, eval(new_col) := gsub(letter, "O", get(new_col))]
  }
  
  # replace U's
  letters <- c("ú", "Ú", "ù", "Ù", "û", "Û", "ü", "Ü")
  for (l in 1:length(letters)) {
    letter <- letters[l]
    dataset[, eval(new_col) := gsub(letter, "U", get(new_col))]
  }
  
  # Add trailing spaces and cast uppercase
  dataset[, eval(new_col) := paste0(' ', str_squish(get(new_col)), ' ')]
  dataset[, eval(new_col) := toupper(get(new_col))]
  
  # Return dataset
  return(dataset)
}
