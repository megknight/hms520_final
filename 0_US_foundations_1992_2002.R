################################################################################################################
## Author: Casey Graves                                                                                       ##
## Translated by: Megan Knight                                                                                ##
## Date: 9/12/2014                                                                                            ##
## Purpose: Estimating US Foundation DAH using new grant-level data from the Foundation Center between 1992   ## 
## and 2002.                                                                                                  ##
## Please Note that this script feeds into:                                                                   ##
## 'J:\Project\IRH\DAH\RESEARCH\CHANNELS\6_FOUNDATIONS\2_US_FOUNDATIONS\CODE\1_US_FOUND_PD_CREATE_FGH2014.do' ##
################################################################################################################
## clean work environment
rm(list = ls())

## runtime configuration
if (Sys.info()['sysname'] == 'Linux') {
  j <- '/home/j'
  h <- file.path('/homes', Sys.getenv('USER'))
} else {
  j <- 'J:/'
  h <- 'H:/'
}

## load libraries 
pacman::p_load(openxlsx, data.table, stringr, tidyr, readstata13)

## source functions 
source(file.path(h, "repos/hms520_final/string_cleaning_function.R"))

## define directories 
root <- file.path(j, 'Project/IRH/DAH/RESEARCH')
raw <- file.path(root, 'CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/DATA/RAW/FGH_2014')
int <- file.path(root, 'CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/DATA/INT')
fin <- file.path(root, 'CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/DATA/FIN')
codes <- file.path(root, 'INTEGRATED DATABASES/COUNTRY FEATURES')

## paramaters for FGH report year
report_yr <- 2020 ## FGH report year
abrv_yr <- 20 ## abbreviated FGH report year 

######################################################################################
## STEP 1: Import grant-level data from the Foundation Center (new classification   ##
## as of FGH 2014)                                                                  ##
######################################################################################
## pull all relevant files with data between 1992 - 2002
grant_files <- list.files(path = raw, pattern = 'Batch ')

## read and rbind files together 
setwd(raw)
grant_tables <- lapply(grant_files, read.xlsx)
grants <- do.call(rbind, grant_tables)

## subset to include health projects only
health_grants <- setDT(grants)[primary_code == 'E']

######################################################################################
## STEP 2: Splitting disbursements among the list recipient countries               ##
######################################################################################
## Often the country_tran variable will list two or more countries, so we will      ##
## want to split the grant amount evenly between them)                              ##
######################################################################################
## TODO: @Ian -- ADD FUNCTION FOR GRANT SPLITTING
## clean recipient country list
health_grants[, country_tran := ifelse((is.na(country_tran)&length(location)!=2), location, country_tran)]

## create separate column for each recipient (some grants have up to 10 recipients listed)
health_grants[, n_recip := count.fields(textConnection(country_tran), sep = "; ")]
country_cols <- rep(paste0('country_tran_', 1:max(health_grants$n_recip, na.rm = T)))
health_grants_wide <- health_grants[, c(country_cols) := tstrsplit(country_tran, ";", fixed = TRUE)]

## transform data long
health_grants_wide$recipient <- health_grants_wide$country_tran
health_grants_long <- melt(health_grants_wide, measure.vars = country_cols, value.name = 'recipient_country')
health_grants_long <- health_grants_long[!(is.na(recipient_country) & !is.na(recipient))]

## cumulative and total counts by grant
health_grants_long$n=ave(1:length(health_grants_long$grant_key), health_grants_long$grant_key, FUN = seq_along)
health_grants_long$N=ave(1:length(health_grants_long$grant_key), health_grants_long$grant_key, FUN = length)

## split grant amount evenly among recipients
health_grants_long[, amount_split := amount/N]

## data prep for merging ISO codes
health_grants_long[, country_lc := trimws(recipient)]
health_grants_long[, country_lc := ifelse(country_lc == 'Bosnia-Herzegovina', 'Bosnia Herzegovina', 
                                   ifelse(country_lc == 'Congo, Democratic Republic of the', 'Congo, the Democratic Republic of the', 
                                   ifelse(country_lc == 'England', 'United Kingdom, England and Wales', 
                                   ifelse(country_lc == 'Wales', 'United Kingdom, England and Wales', 
                                   ifelse(country_lc == 'Georgia (Republic of)', 'Georgia',
                                   ifelse(country_lc == 'Myanmar (Burma)', 'Myanmar',
                                   ifelse(country_lc == 'Soviet Union', 'Union of Soviet Socialist Republics',
                                   ifelse(country_lc == 'Soviet Union (Former)', 'Union of Soviet Socialist Republics',
                                   ifelse(country_lc == 'Yemen Arab Republic', 'Republic of Yemen', 
                                   ifelse(country_lc == 'West Bank/Gaza (Palestinian Territories)', 'West Bank and Gaza',
                                   ifelse(country_lc == 'West Bank/Gaza', 'West Bank and Gaza', country_lc)))))))))))]

## read in ISO codes
iso_codes <- setDT(read.dta13(file.path(codes, paste0('countrycodes_official_', report_yr, '.dta'))))

## attach ISO codes
health_grants_label1 <- merge(health_grants_long, unique(iso_codes[, c('countryname_ihme', 'iso3')]), by.x = 'country_lc', by.y = 'countryname_ihme', all.x = T)

## data prep for merging income groups
setnames(health_grants_label1, old = c('iso3', 'yr_issued'),  new = c('ISO3_RC', 'YEAR'))
health_grants_label2 <- health_grants_label1[, ISO3_RC := ifelse(country_lc == 'Africa', 'QMA',
                            ifelse(country_lc == 'Asia', 'QRA',
                            ifelse(country_lc == 'Caribbean', 'QNB',       
                            ifelse(country_lc %in% c('Southern Africa', 'Central Africa' , 'Sub-Saharan Africa', 'Western Africa', 'Eastern Africa', 'Horn of Africa'), 'QME',
                            ifelse(country_lc %in% c('Central America', 'North America'), 'QNC',
                            ifelse(country_lc == 'Central Asia', 'QRS',
                            ifelse(country_lc %in% c('Eastern Asia', 'China & Mongolia'),'QRB',  
                            ifelse(country_lc %in% c('Eastern Europe', 'Europe'),'QSA', 
                            ifelse(country_lc %in% c('Global Programs', 'Global programs'),'WLD', 
                            ifelse(country_lc %in% c('Latin America', 'South America'),'QNE',
                            ifelse(country_lc %in% c('Mediterranean Basin', 'Northeast Africa', 'Northern Africa'),'QMD',
                            ifelse(country_lc == 'Oceania','QTA',
                            ifelse(country_lc %in% c('Pacific Rim', 'Arctic Region', 'Developing Countries', 'Developing countries'),'QZA',  
                            ifelse(country_lc == 'Scandinavia','SWE',  
                            ifelse(country_lc %in% c('Southeast Asia', 'Southeastern Asia'),'QRA', 
                            ifelse(country_lc %in% c('Southern Asia', 'Indian Subcontinent & Afghanistan'),'QRC', 
                            ifelse(country_lc == 'Middle East','QRE', 
                            ifelse(country_lc == 'Zaire','COD', 
                            ifelse(country_lc == 'Northern Ireland','GRB', 
                            ifelse(country_lc == 'East Jerusalem','PSE',       
                            ifelse(country_lc == 'Kosovo','KOS', 
                            ifelse(country_lc %in% c('United Kingdom, England and Wales', 'Scotland', 'Northern Ireland'),'GBR', ISO3_RC))))))))))))))))))))))]

## read in income groups
income_groups <- setDT(read.dta13(file.path(codes, paste0('wb_historical_incgrps_', abrv_yr, '.dta'))))

## attach income groups
health_grants_label2 <- merge(health_grants_label2, income_groups, by = c('ISO3_RC', 'YEAR'), all.x = T)

######################################################################################
## STEP 3: Tagging transfers from foundations to channels we already track          ##
## (UN Agencies and NGOs)                                                           ##
######################################################################################
## drop BMFG because they are tracked separately
health_grants_sub <- health_grants_label2[gm_key != 'GATE023']

## pull foundations to tag transfer
grant_names <- unique(health_grants_sub$name)
foundation_names <- grant_names[grant_names %like% 'Foundation']

## tagging transfers to other foundations
health_grants_sub$ELIM_CH = 0
health_grants_sub$RECIPIENT_AGENCY_SECTOR = 'OTH' 
health_grants_sub$CHANNEL = 'US_FOUND'
health_grants_sub$ELIM_CH <- ifelse(health_grants_sub$gm_name %in% foundation_names, 1, 0)
tag_foundations <- health_grants_sub[, c('ELIM_CH', 'CHANNEL') := list(ifelse(name %like% 'Pan American Health Organization', 1, 
                                                      ## if UNDP is added as a channel
                                                      ## ifelse(name %like% 'United Nations Development Programme', 1, 
                                                      ifelse(name %like% 'United Nations Population Fund', 1, 
                                                      ifelse(name %like% 'United Nations Programme on HIV/AIDS', 1, 
                                                      ifelse(name %like% 'World Health Organization', 1, 
                                                      ifelse(name %like% 'Global Fund to Fight AIDS, Tuberculosis and Malaria', 1, 
                                                      ifelse(name %like% 'GAVI', 1, 
                                                      ifelse(name %like% 'Inter-American Development Bank', 1,    
                                                      ifelse(name %like% 'World Bank', 1,
                                                      ifelse(name %like% 'UNICEF', 1,
                                                      ifelse(name %like% 'Wellcome Trust', 1, ELIM_CH)))))))))),
                                                      ifelse(name %like% 'Pan American Health Organization', 'PAHO', 
                                                      ## if UNDP is added as a channel
                                                      ## ifelse(name %like% 'United Nations Development Programme', 'UNDP', 
                                                      ifelse(name %like% 'United Nations Population Fund', 'UNFPA', 
                                                      ifelse(name %like% 'United Nations Programme on HIV/AIDS', 'UNAIDS', 
                                                      ifelse(name %like% 'World Health Organization', 'WHO', 
                                                      ifelse(name %like% 'Global Fund to Fight AIDS, Tuberculosis and Malaria', 'GFATM', 
                                                      ifelse(name %like% 'GAVI', 'GAVI', 
                                                      ifelse(name %like% 'Inter-American Development Bank', 'IDB',    
                                                      ifelse(name %like% 'World Bank', 'WB',
                                                      ifelse(name %like% 'UNICEF', 'UNICEF',
                                                      ifelse(name %like% 'Wellcome Trust', 'WELLCOME', ELIM_CH)))))))))))]

## tagging transfers to UN Agencies/bilaterals
agencies <- setDT(read.dta13(file.path(j, 'Project/IRH/DAH/RESEARCH/CHANNELS/2_NGO/1_VOLAG/DESCRIPTIVE_VARIABLES/Agency_ID_FF2017.dta')))
intl_agencies <- setDT(read.dta13(file.path(j, 'Project/IRH/DAH/RESEARCH/CHANNELS/2_NGO/1_VOLAG/DESCRIPTIVE_VARIABLES/Intl_Agency_ID_FF2017.dta')))
foundations <- tag_foundations[, agency := name]

## use string_clean function so agency information is comparable across mutliple data sources 
agencies <- string_clean(dataset = agencies, col_to_clean = 'agency')
intl_agencies <- string_clean(dataset = intl_agencies, col_to_clean = 'agency')
foundations <- string_clean(dataset = foundations, col_to_clean = 'agency')

## flag for NGOs tracked by FGH in foundations data -- these will be dropped
foundations_track_flag <- foundations[, c('ELIM_CH', 'RECIPIENT_AGENCY_SECTOR', 'CHANNEL') := list(ifelse(foundations$upper_agency %in% agencies$upper_agency, 1, 
                                                                                                        ifelse(foundations$upper_agency %in% intl_agencies$upper_agency, 1, ELIM_CH)),
                                                                                                        ifelse(foundations$upper_agency %in% agencies$upper_agency, 'NGO', 
                                                                                                        ifelse(foundations$upper_agency %in% intl_agencies$upper_agency, 'NGO', RECIPIENT_AGENCY_SECTOR)),
                                                                                                        ifelse(foundations$upper_agency %in% agencies$upper_agency, 'NGO', 
                                                                                                        ifelse(foundations$upper_agency %in% intl_agencies$upper_agency, 'NGO', CHANNEL)))]

## these NGOs are tracked as part of FGH, but have a slight variation on the name
flagged_ngos <- c('ACTIONAID', 'ADVENTURES IN HEALTH EDUCATION AND AGRICULTURAL DEVELOPMENT', 'AMERICARES', 'CATHOLIC RELIEF SERVICES',
                  'CHILDFUND', 'DTREE INC', 'DOCTORS OF THE WORLD USA', 'DOCTORS WITHOUT BORDERS USA', 'ENVIRONMENTAL DEFENSE FUND', 
                  'ENVIRONMENTAL LAW ALLIANCE WORLDWIDE ELAW', 'FOUNDATION FOR A CIVIL SOCIETY', 'FRIENDS OF THE WORLD FOOD PROGRAM', 
                  'HEALTHPARTNERS INSTITUTE FOR EDUCATION AND RESEARCH', 'HEART TO HEART INTERNATIONAL CHILDRENS MEDICAL ALLIANCE', 
                  'INTERNATIONAL SERVICES OF HOPE/IMPACT MEDICAL DIVISION ISOH/IMPACT', 'MANO A MANO MEDICAL RESOURCES', 'MEDISEND', 
                  'MEDISEND', 'MERCY AND TRUTH MEDICAL MISSIONS', 'NATIONAL ASSOCIATION OF PEOPLE LIVING WITH HIV/AIDS', 'OPEN DOOR MEDICAL MINISTRIES', 
                  'OPERATION SMILE INTERNATIONAL', 'PARTNERS IN HEALTH', 'PATH', 'PROGRAM FOR APPROPRIATE TECHNOLOGY IN HEALTH PATH', 
                  'PROJECT HOPE PEOPLETOPEOPLE HEALTH FOUNDATION', 'RARE CENTER FOR TROPICAL CONSERVATION', 'SAVE THE CHILDREN', 'SAVE THE CHILDREN FUND', 
                  'SURGICAL EYE EXPEDITIONS INTERNATIONAL', 'VOLUNTEERS FOR INTERAMERICAN DEVELOPMENT ASSISTANCE VIDA', 'WATERAID', 
                  'WORLD CONCERN', 'WORLD VISION RELIEF AND DEVELOPMENT', 'SURGICAL EYE EXPEDITIONS INTERNATIONAL ENDOWMENT TRUST')

foundations_name_flag <- foundations_track_flag[, c('ELIM_CH', 'RECIPIENT_AGENCY_SECTOR', 'CHANNEL') := list(ifelse(upper_agency %in% flagged_ngos, 1, ELIM_CH),
                                                                                                             ifelse(upper_agency %in% flagged_ngos, 'NGO', RECIPIENT_AGENCY_SECTOR),
                                                                                                             ifelse(upper_agency %in% flagged_ngos, 'NGO', CHANNEL))]

## drop high income countries
foundations_prep <- foundations_name_flag[is.na(INC_GROUP) | INC_GROUP != 'H']

######################################################################################
## STEP 4: Allocate to health focus areas                                           ## 
######################################################################################
## data prep for keyword search on the detailed grant description, activity description, and grant type description
keyword_prep <- string_clean(dataset = foundations_prep, col_to_clean = 'description')
keyword_prep <- string_clean(dataset = foundations_prep, col_to_clean = 'type_tran')
keyword_prep <- string_clean(dataset = foundations_prep, col_to_clean = 'activity_tran')
keyword_prep <- string_clean(dataset = foundations_prep, col_to_clean = 'pop_grp_tran')

## TODO: @Ian -- INTEGRATE FGH KEYWORD SEARCH FUNCTION (lines 314+)