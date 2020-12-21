#----# Docstring #----# ####
# Project:  FGH 2020
# Purpose:  Post keyword search cleaning
# Date:     07/17/2020
# Author:   Kyle Simpson
#---------------------# ####

#----# Environment Prep #----# ####
rm(list=ls())

if (!exists("code_repo"))  {
  code_repo <- unname(ifelse(Sys.info()['sysname'] == "Windows", "H:/repos/fgh/", paste0("/ihme/homes/", Sys.info()['user'][1], "/repos/fgh/")))
}
source(paste0(code_repo, 'FUNCTIONS/utils.R'))

#----------------------------# ####

cat('\n\n')
cat(green(' ################################################\n'))
cat(green(' #### US FOUNDS POST KEYWORD SEARCH CLEANING ####\n'))
cat(green(' ################################################\n\n'))


cat('  Read in 1992 - 2002 post keyword search data\n')
#----# Read in 1992 - 2002 post keyword search data #----# ####

pkws <- setDT(read.dta13(paste0(get_path('US_FOUNDS', 'stage1'), 'post_kws_1992_2002.dta')))

# Allocate disbursements across all health focus areas using weights
pkws <- calculate_hfa_disbursements(pkws)
save_dataset(pkws, paste0('1992_2002_foundation_data_FGH_', dah.roots$report_year), 'US_FOUNDS', 'stage1', write_dta = T)


#----------------------------# ####
cat('  Read in 2002 - 2012 post keyword search data\n')
#----# Read in 2002 - 2012 post keyword search data #----# ####

pkws <- setDT(read.dta13(paste0(get_path('US_FOUNDS', 'stage1'), 'post_kws_1992_2002.dta')))

# Allocate disbursements across all health focus areas using weights
pkws <- calculate_hfa_disbursements(pkws)
save_dataset(pkws, paste0('2002_2012_foundation_data_FGH_', dah.roots$report_year), 'US_FOUNDS', 'stage1', write_dta = T)


#----------------------------# ####
cat('  Read in 2013 - 2015 post keyword search data\n')
#----# Read in 2013 - 2015 post keyword search data #----# ####

pkws <- setDT(read.dta13(paste0(get_path('US_FOUNDS', 'stage1'), 'post_kws_1992_2002.dta')))

# Allocate disbursements across all health focus areas using weights
pkws <- calculate_hfa_disbursements(pkws)
save_dataset(pkws, paste0('2013_16_foundation_data_FGH_', dah.roots$report_year), 'US_FOUNDS', 'stage1', write_dta = T)
#----------------------------# ####