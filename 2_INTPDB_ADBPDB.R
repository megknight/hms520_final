#----# Docstring #----# ####
# Project:  FGH 2020
# Purpose:  Calculate in-kind for US Foundations
# Last updated: 12/11/20     
# Author:   Ian Cogswell
#---------------------# ####

#----# Environment Prep #----# ####
rm(list=ls())

if (!exists("code_repo"))  {
  code_repo <- unname(ifelse(Sys.info()['sysname'] == "Windows", "H:/repos/fgh/", paste0("/ihme/homes/", Sys.info()['user'][1], "/repos/fgh/")))
}
source(paste0(code_repo, 'FUNCTIONS/utils.R'))

# Variable prep
defl <- paste0(dah.roots$j, 'Project/IRH/DAH/RESEARCH/INTEGRATED DATABASES/DEFLATORS/')
#----------------------------# ####


cat('\n\n')
cat(green(' ##########################\n'))
cat(green(' ## US FOUNDATONS INKIND ##\n'))
cat(green(' ##########################\n\n'))

cat('  Import Datasets\n')
#----# Import Datasets #----# ####

# In-kind
inkind <- setDT(read_excel(paste0(get_path('US_FOUNDS', 'raw'), 'INKIND_RATIOS_FGH', dah.roots$report_year, '.xlsx')))
inkind <- inkind[, .(YEAR, DONOR_NAME, INKIND_RATIO)]

# Check top and bottom 10 funding foundations
cat(yellow('   REMINDER: Complete a manual inspection\n'))
cat(yellow('   These are the current donors for inkind ratios:'))

inkind[YEAR == dah.roots$report_year - 2]$DONOR_NAME

# Load clean names
cleaning_names <- setDT(read_excel(paste0(get_path('US_FOUNDS', 'raw'), '../Cleaning Raw Names.xlsx')))
colnames(cleaning_names) <- toupper(colnames(cleaning_names))

# Ensure that these are the same 20 US Foundations 
# from last year's US Foundations adbpdb dataset
prev_adbpdb <- setDT(read.dta13(paste0(get_path('US_FOUNDS', 'fin'), '../F_USA_ADB_PDB_FGH', dah.roots$prev_report_year, '.dta')))
prev_adbpdb <- prev_adbpdb[ELIM_CH != 1, .(YEAR, DONOR_NAME, DAH)]

# Clean donor names
prev_adbpdb[, DONOR_NAME := toupper(DONOR_NAME)]
prev_adbpdb <- merge(prev_adbpdb, cleaning_names, by = 'DONOR_NAME', all.x = T)
prev_adbpdb[CLEAN_NAME != "", DONOR_NAME := CLEAN_NAME]
prev_adbpdb[, CLEAN_NAME := NULL]

# Deflate
deflators <- setDT(read.dta13(paste0(defl, 'imf_usgdp_deflators_', dah.roots$defl_MMYY, '.dta')))
deflators <- deflators[, .(YEAR, get(paste0('GDP_deflator_', dah.roots$report_year)))]
prev_adbpdb <- merge(prev_adbpdb, deflators, by = 'YEAR', all.x = T)
prev_adbpdb[, eval(paste0('DAH_', dah.roots$abrv_year)) := DAH / V2]

# Collapse
prev_adbpdb <- collapse(prev_adbpdb, 'sum', c('DONOR_NAME'), paste0('DAH_', dah.roots$abrv_year))
prev_adbpdb <- prev_adbpdb[order(-(get(paste0('DAH_', dah.roots$abrv_year))))]

cat(yellow('   These are the top 15 donors from last year:\n'))
prev_adbpdb$DONOR_NAME[1:15]
cat(yellow('   These are the bottom 10 donors from last year:\n'))
prev_adbpdb$DONOR_NAME[(nrow(prev_adbpdb) - 9):nrow(prev_adbpdb)]

prev_prev_adbpdb <- setDT(read.dta13(paste0(get_path('US_FOUNDS', 'fin'), '../F_USA_ADB_PDB_FGH', dah.roots$report_year - 2, '.dta')))
prev_prev_adbpdb <- prev_prev_adbpdb[ELIM_CH != 1]
prev_prev_adbpdb <- prev_prev_adbpdb[, .(YEAR, DONOR_NAME, DAH)]

# Clean donor names
prev_prev_adbpdb[, DONOR_NAME := toupper(DONOR_NAME)]
prev_prev_adbpdb <- merge(prev_prev_adbpdb, cleaning_names, by = 'DONOR_NAME', all.x = T)
prev_prev_adbpdb[CLEAN_NAME != "", DONOR_NAME := CLEAN_NAME]
prev_prev_adbpdb[, CLEAN_NAME := NULL]

# Deflate
prev_prev_adbpdb <- merge(prev_prev_adbpdb, deflators, by = 'YEAR', all.x = T)
prev_prev_adbpdb[, eval(paste0('DAH_', dah.roots$abrv_year)) := DAH / V2]

# Collapse
prev_prev_adbpdb <- collapse(prev_prev_adbpdb, 'sum', c('DONOR_NAME'), paste0('DAH_', dah.roots$abrv_year))
prev_prev_adbpdb <- prev_prev_adbpdb[order(-(get(paste0('DAH_', dah.roots$abrv_year))))]

cat(yellow('   These are the top 15 donors from two years ago\n'))
prev_prev_adbpdb$DONOR_NAME[1:15]
cat(yellow('   These are the bottom 10 donors from two years ago\n'))
prev_prev_adbpdb$DONOR_NAME[(nrow(prev_prev_adbpdb) - 9):nrow(prev_prev_adbpdb)]

rm(prev_adbpdb, prev_prev_adbpdb, cleaning_names, deflators)

# Notes

## FGH2019: There are significant changes to the list (especially the bottom 10)

### Top 10: Bloomberg Philanthropies is not included because it didn't have enough 990s to be usable.
### The Merck Company Foundation and Bristol-Myers Squibb Foundation, Inc. are also missing although it's
### unclear why. Instead of these two, we use ExxonMobil Foundation (#13) and Conrand N. Hilton Foundation (#22).
### Bottom 10: The bottom 10 used for the inkind ratio calculation are totally different than shown above. Unsure why.

## FGH2020: 

### Top 10: I would like to look into possibly updating the top foundations list (may consider what foundations
### are disbursing the most funding over the entire timespan?). Not enough time this year with the
### freakin' coronavirus updates (CARDI B Voice).
### Bottom 10: Significant changes to bottom 10. Same issues as last year are present. May need new
### solution to bottom 10 because these will likely change annually.

## Because some of the smaller foundations have really crazy in-kind ratios
## (0% or 1% in some years) we will take the average across time to standardize.
inkind <- inkind[, .(YEAR = 1990:dah.roots$report_year,
                     INKIND_RATIO = mean(INKIND_RATIO, na.rm = T))]

# cat(yellow('   FGH2019 Experiment thank you Steve\n'))
# ## Can we use the top and bottom 10 to calculate annual in-kind ratios instead of
# ## a single one across all years?
# 
# inkind_experiment <- setDT(read_excel(paste0(get_path('US_FOUNDS', 'raw'), 'INKIND_RATIOS_FGH', dah.roots$report_year, '.xlsx')))
# inkind_experiment <- inkind_experiment[, .(INKIND_RATIO = mean(INKIND_RATIO)),
#                                        by = .(YEAR)]
# 
# ## Add two new years using 3-year weighted average of last three years known
# ## ADD LAGGING CALCULATIONS LATER
# 
# # Back cast 1990-1996 using 3-year weighted average of 1997-1999
# ## ADD LAGGING CALCULATION LATER
# 
# inkind_experiment <- merge(inkind_experiment, inkind, by = 'YEAR', all = T)
# 
# ## ADD GGPLOT CODE LATER
# inkind_experiment_line_graph <- ggplot(inkind_experiment)
# 
# 
# pdf()
# inkind_experiment_line_graph
# dev.off()
# 
# rm(inkind_experiment, inkind_experiment_line_graph)

## Is this something we want to do instead? For the sake of time, we will 
## continue using a single value this year.
## Not addressed during FGH2020 due to lack of time with additional covid pipeline.

dt_file_3 <- setDT(read.dta13(paste0(get_path('US_FOUNDS', 'stage1'), '../2013_16_foundation_data_FGH_', dah.roots$report_year, '.dta')))
dt_file_2 <- setDT(read.dta13(paste0(get_path('US_FOUNDS', 'stage1'), '../2002_2012_foundation_data_FGH_', dah.roots$report_year, '.dta')))
dt_new <- rbind(dt_file_2, dt_file_3, fill = T)

dt_new_inkind <- merge(dt_new, inkind, by = 'YEAR', all.x = T)

to_eval <- colnames(dt_new_inkind)[colnames(dt_new_inkind) %like% '_DAH' | colnames(dt_new_inkind) == 'amount_split']
dt_new_inkind[, c(to_eval) := .SD * INKIND_RATIO,
              .SDcols = to_eval]
dt_new_inkind[, INKIND := 1]
dt_new_inkind[INKIND == 1, ELIM_CH := 0] # we want to include administrative costs of projects that are double counted

dt_new <- rbind(dt_new, dt_new_inkind, fill = T)
dt_new[is.na(INKIND), INKIND := 0]

rm(dt_file_2, dt_file_3)

# For creating final dataset
dt_new_envelope <- copy(dt_new)
dt_new_envelope <- dt_new_envelope[ELIM_CH != 1]
dt_new_envelope <- collapse(dt_new_envelope, 'sum', 'YEAR', to_eval)

dt_new_envelope[, iso3 := 'USA']
setnames(dt_new_envelope, 'YEAR', 'year')

dt_new_for_merge <- copy(dt_new_envelope)
dt_new_for_merge <- dt_new_for_merge[, .(year, DAH_newdata = amount_split)]

# Pull in old foundation data - this needs to be done separately because the
# variable names are different

dt_old <- setDT(read.dta13(paste0(get_path('US_FOUNDS', 'stage1'), '../1992_2012_foundation_data_FGH_', dah.roots$report_year, '.dta')))

# Drop double counting and add in-kind
dt_old_inkind <- merge(dt_old, inkind, by = 'YEAR', all.x = T)

dt_old_inkind <- dt_old_inkind[, c(to_eval) := .SD * INKIND_RATIO,
                               .SDcols = to_eval]
dt_old_inkind[, INKIND := 1]
dt_old_inkind[INKIND == 1, ELIM_CH := 0] # we want to include administrative costs of projects that are double counted

dt_old <- rbind(dt_old, dt_old_inkind, fill = T)
dt_old[is.na(INKIND), INKIND := 0]

# For creating final dataset
dt_old_envelope <- copy(dt_old)
dt_old_envelope <- dt_old_envelope[ELIM_CH != 1]
dt_old_envelope <- collapse(dt_old_envelope, 'sum', 'YEAR', to_eval)

dt_old_envelope[, iso3 := 'USA']
setnames(dt_old_envelope, 'YEAR', 'year')

dt_old_for_merge <- copy(dt_old_envelope)
dt_old_for_merge <- dt_old_for_merge[, .(year, DAH_olddata = amount_split)]

dt <- merge(dt_old_for_merge, dt_new_for_merge, by = 'year', all = T)

# Method #2: (method used in previous years)
# 3-year weighted average to predict comparable DAH for new data classification from 1992 to 2001

dt[, dah_frct := DAH_newdata / DAH_olddata]

# Use the three most relevant
dt[, DAH := DAH_olddata * (dt[year == 2002]$dah_frct / 2 + dt[year == 2003]$dah_frct / 3 + dt[year == 2004]$dah_frct / 6)]
dt[year > 2001, DAH := DAH_newdata]
dt <- dt[, .(year, DAH)]

#--------------------------# ####

cat('  Add final disbursement values to aggregate data\n')
#----# Add final disbursement values to aggregate data #----# ####

# Old data
dt_old_envelope <- dt_old_envelope[year < 2002]
dt_envelope <- rbind(dt_old_envelope, dt_new_envelope, fill = T)
dt <- merge(dt_envelope, dt, by = 'year', all.x = T)

to_eval <- colnames(dt)[colnames(dt) %like% '_DAH']

for (col in to_eval) {
  dt[, eval(paste0(col, 'frct')) := get(eval(col)) / amount_split]
  dt[, eval(col) := get(eval(paste0(col, 'frct'))) * DAH]
}
#--------------------------# ####

cat('  Make predictions using GDP per capita\n')
#----# Make predictions using GDP per capita #----# ####

cat(yellow('   MAKE SURE you are using an updated version of this dataset!\n'))

## ADD LDI FILE TO ENV PREP OR dah.roots also update the LDI file according to Brandon
ldi <- setDT(read.dta13(paste0(dah.roots$j, 'Project/IRH/LDI_PPP/LDI/output_data/part6_ian_temp.dta')))

##ADDRESS THIS FILE
setnames(ldi, c('IHME_usd_gdppc_b2018', 'year'), c('IHME_usd_gdppc_b2019', 'YEAR')) ## currently a bandaid fix
ldi <- ldi[, .(iso3, YEAR, get(paste0('IHME_usd_gdppc_b', dah.roots$prev_report_year)))]

# Put in nominal USD
deflators <- setDT(read.dta13(paste0(defl, 'imf_usgdp_deflators_', dah.roots$defl_MMYY, '.dta')))
deflators <- deflators[, .(YEAR, get(paste0('GDP_deflator_', dah.roots$prev_report_year)))]
ldi <- merge(ldi, deflators, by = 'YEAR')
ldi[, V3 := V3 * V2]
ldi[, V2 := NULL]
setnames(ldi, 'YEAR', 'year')

ldi <- ldi[iso3 == 'USA' & year >= 1989 & year <= dah.roots$report_year]

dt <- merge(ldi, dt, by = c('iso3', 'year'), all.x = T)
setnames('iso3', 'iso3_n')

dt[, `:=` (ln_DAH = log(DAH),
           ln_gdppc = log(V3))]

# This is what is predicting the envelope! Make sure to understand this
### COME BACK TO ADD MODEL

setnames(dt, c('DAH'), c('dah'))
dt[, DAH := dah]
dt[is.na(DAH), DAH := pr_ln_DAH]
dt[, c('ln_DAH', 'pr_ln_DAH') := NULL]

# Deflate to real USD
deflators <- setDT(read.dta13(paste0(defl, 'imf_usgdp_deflators_', dah.roots$defl_MMYY, '.dta')))
deflators <- deflators[, .(year = YEAR, get(paste0('GDP_deflator_', dah.roots$report_year)))]

dt <- merge(dt, deflators, by = 'year')
to_eval <- colnames(dt)[colnames(dt) %like% '_DAH' | colnames(dt) %in% c('DAH', 'dah')]

dt <- dt[, c(to_eval) := .SD / V2,
         .SDcols = to_eval]

dt[, V2 := NULL]
dt <- dt[year > 1989]




# Generating variables
## For ADB
dt[, `:=` (ISO_CODE = 'USA',
           DONOR_NAME = gm_name,
           DONOR_COUNTRY = 'United States',
           OUTFLOW = final_amtsplit,
           INCOME_SECTOR = 'PRIVATE',
           INCOME_TYPE = 'FOUND',
           SOURCE_DOC = 'Foundation Center',
           GHI = 'US_FOUND',
           INCOME_ALL = NA)]

## For PDB
dt[, `:=` (DATA_SOURCE = 'Foundation Center',
           FUNDING_TYPE = 'GRANT',
           PROJECT_ID = grant_key,
           PROJECT_DESCRIPTION = description,
           PROJECT_PURPOSE = activity_override_tran,
           FUNDING_COUNTRY = 'United States',
           ISO3_FC = 'USA',
           FUNDING_AGENCY = gm_name,
           FUNDING_AGENCY_TYPE = 'FOUND',
           FUNDING_AGENCY_SECTOR = 'CSO',
           RECIPIENT_COUNTRY = countryname,
           RECIPIENT_AGENCY = agency,
           DISBURSEMENT = final_amtsplit)]

dt[, gov := ifelse(RECIPIENT_AGENCY_SECTOR == 'OTH', 0,
                   ifelse(RECIPIENT_AGENCY_SECTOR == 'GOV', 1,
                          ifelse(RECIPIENT_AGENCY_SECTOR == 'NGO', 2, '')))]

table(dt[, .(gov, RECIPIENT_AGENCY_SECTOR)])
table(dt[ISO3_RC == 'QZA']$recipient)
table(dt[ISO3_RC == '']$recipient)

# Note: These recipients will sometimes list an individual country, but it is always followed
# by "Developing Countries". These projects have a wider reach than a single country but are not actually
# unallocable - will be reassigned to global.

dt[ISO3_RC == 'QZA' | ISO3_RC == '', ISO3_RC := 'WLD']
setnames(dt, 'ISO3_RC', 'iso3')
dt[ISO3_RC]
dt[iso3 := NULL] # wat is going on here






cat('  Step 5: Save ADB\n')
#----# Step 5: Save ADB #----# ####

dt <- dt[, .(YEAR, ISO_CODE, INCOME_ALL, DONOR_NAME, DONOR_COUNTRY, OUTFLOW, INCOME_SECTOR,
             INCOME_TYPE, CHANNEL, SOURCE_DOC, ELIM_CH, GHI, INKIND)]


cat('  Step 6: Save PDB\n')
#----# Step 5: Save PDB #----# ####
dt <- dt[INKIND != 1]
dt <- dt[, .(YEAR, FUNDING_TYPE, DATA_SOURCE, PROJECT_DESCRIPTION, PROJECT_PURPOSE, FUNDING_COUNTRY,
             ISO3_FC, FUNDING_AGENCY, FUNDING_AGENCY_SECTOR, RECIPIENT_COUNTRY, ISO3_RC, RECIPIENT_AGENCY,
             RECIPIENT_AGENCY_SECTOR, DISBURSEMENT)]







