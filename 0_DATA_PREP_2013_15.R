################################################################################################################
## Author: Casey Graves                                                                                       ##
## Translated by: Megan Knight                                                                                ##
## Date: 9/12/2014                                                                                            ##
## Purpose: Estimating US Foundation DAH using new grant-level data from the Foundation Center between 2013   ##
## and 2015.                                                                                                  ## 
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

## paramaters for FGH report year
report_yr <- 2020 ## FGH report year
abrv_yr <- 20 ## abbreviated FGH report year
crs_mmyy = "1020"	## MMYY of current CRS data

## define directories 
root <- file.path(j, 'Project/IRH/DAH/RESEARCH')
raw <- file.path(root, '/CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/DATA/RAW')
int <- file.path(root, 'CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/DATA/INT')
fin <- file.path(root, 'CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/DATA/FIN')
CRS <- file.path(root, paste0('CHANNELS/1_BILATERALS_EC/1_CRS/DATA/FIN/CRS_', crs_mmyy))				
codes <- file.path(root, 'INTEGRATED DATABASES/COUNTRY FEATURES')
HFA	<- file.path(root, "INTEGRATED DATABASES/HEALTH FOCUS AREAS")

######################################################################################
## STEP 1: Import raw grant-level data from the Foundation Center -- new            ##
## classification as of FGH 2016)                                                   ##
######################################################################################
## read raw data 
grants_2013 <- setDT(read.xlsx(file.path(raw, 'FGH_2017/International_Grants_2013.xlsx')))
grants_2014 <- setDT(read.xlsx(file.path(raw, 'FGH_2017/International_Grants_2014.xlsx')))
grants_2015 <- setDT(read.xlsx(file.path(raw, 'FGH_2017/International_2015.xlsx')))
grants_2016 <- fread(file.path(raw, 'FGH_2018/FC_Output_2016.csv'))
grants_2017 <- setDT(read.xlsx(file.path(raw, 'FGH_2019/FC_Output_2017.xlsx')))
grants_2018 <- setDT(read.xlsx(file.path(raw, "FGH_2020/FC_Output_2018_revised.xlsx")))

## prep raw data for merge 
grants_2016 <- grants_2016[, amount := gsub(',', '', grants_2016$amount)]
grants_2016$amount <- as.numeric(grants_2016$amount)

grants_2018 <- grants_2018[, recip_country_tran := ifelse(recip_country_tran=="United States", "", recip_country_tran)]

## append raw data together 
grants <- rbind(grants_2013, grants_2014, grants_2015, grants_2016, grants_2017, grants_2018, fill=T)

## keep only health projects or health recipients
health_grants <- grants[activity_override %like% "SE" | recip_subject_code %like% "SE"]

## drop projects that are allied health	(Water access, sanitation and hygiene; Sanitation; Environmental health; Clean water supply; Bioethics; Art and music therapy)
allied_projects <- c("SE080200", "SE030100", "SE140100", "SE130701", "SE130200", "SE130702", "SE130700")
health_grants <- health_grants[!(activity_override %in% allied_projects)]

######################################################################################
## STEP 2: Splitting disbursements among the list recipient countries               ##
######################################################################################
## Often the country_tran variable will list two or more countries, so we will want ##
## to split the grant amount evenly between them                                    ##
######################################################################################
## clean recipient data 
health_grants[, intl_countries_tran := ifelse(intl_countries_tran == '', NA, intl_countries_tran)]
health_grants[, intl_geotree_tran := ifelse(intl_geotree_tran == '', NA, intl_geotree_tran)]
health_grants[, recip_country_tran := ifelse(recip_country_tran == '', NA, recip_country_tran)]

health_grants[, countryname := intl_countries_tran]

## subset for only US agencies that recieved grants for international work
health_grants[, countryname := ifelse(is.na(countryname), intl_geotree_tran, countryname)]
health_grants[, countryname := ifelse(is.na(countryname), recip_country_tran, countryname)]

## split grants among countries
health_grants_long <- grant_splitting(health_grants, country_col = countryname, dah_col = amount_split, separator = '; ')

## data prep for merging ISO codes
health_grants_long[, countryname := trimws(countryname)]
health_grants_long[, countryname := ifelse(countryname == 'Congo, Democratic Republic of the', 'Congo, Democratic Republic of', 
                                    ifelse(countryname == 'Gambia, Republic of The', 'Gambia, The',
                                    ifelse(countryname %in% grepl("West Bank/Gaza", health_grants_long$countryname, useBytes = T), 'West Bank and Gaza', 
                                    ifelse(countryname == 'Delhi', "India", 
                                    ifelse(countryname == 'Kalimantan', "Indonesia", 
                                    ifelse(countryname == 'Rungwe', "Tanzania", countryname))))))]
health_grants_long$country_lc <- health_grants_long$countryname

## read in ISO codes
iso_codes <- setDT(read.dta13(file.path(codes, paste0('countrycodes_official_', report_yr, '.dta'))))

## attach ISO codes
health_grants_label1 <- merge(health_grants_long, unique(iso_codes[, c('country_lc', 'iso3')]), by = 'country_lc', all.x = T)

## data prep for merging income groups
setnames(health_grants_label1, old = c('iso3', 'yr_issued'),  new = c('ISO3_RC', 'YEAR'))
health_grants_label2 <- health_grants_label1[, ISO3_RC := ifelse(country_lc == 'Africa', 'QMA',
                                                          ifelse(country_lc == 'Asia', 'QRA',
                                                          ifelse(country_lc == 'Caribbean', 'QNB',       
                                                          ifelse(country_lc %in% c("Southern Africa", "Central Africa" , "Sub-Saharan Africa", "Western Africa", "Eastern Africa", "Horn of Africa", "Africa-Great Lakes Region", "Sahel"), 'QME',
                                                          ifelse(country_lc %in% c('Central America', 'North America'), 'QNC',
                                                          ifelse(country_lc == 'Central Asia', 'QRS',
                                                          ifelse(country_lc %in% c("Eastern Europe", "Europe", "Western Europe", "Central Europe", "Moravia"),'QSA',  
                                                          ifelse(country_lc %in% c("Global Programs", "Global programs", "World"),'WLD', 
                                                          ifelse(country_lc %in% c('Latin America', 'South America'),'QNE',
                                                          ifelse(country_lc %in% c('Mediterranean Basin', 'Northeast Africa', 'Northern Africa'),'QMD',
                                                          ifelse(country_lc %in% c("Oceania", "Pacific Ocean"),'QTA',
                                                          ifelse(country_lc %in% c('Pacific Rim', 'Arctic Region', 'Developing Countries', 'Developing countries'),'QZA',  
                                                          ifelse(country_lc %in% c("Southeast Asia", "Southeastern Asia", "Mekong River and Basin", "Eastern Asia"),'QRA', 
                                                          ifelse(country_lc %in% c('Southern Asia', 'Indian Subcontinent & Afghanistan'),'QRC', 
                                                          ifelse(country_lc == 'Middle East','QRE', 
                                                          ifelse(country_lc == 'Zaire','COD', 
                                                          ifelse(country_lc == 'Northern Ireland','GRB', 
                                                          ifelse(country_lc == 'East Jerusalem','PSE',       
                                                          ifelse(country_lc == 'West Bank/Gaza (Palestinian Territories)','PSE', 
                                                          ifelse(country_lc %in% c("Kalimantan", "Sulawesi", "Java", "Bali", "Nusa Tenggara"),'IDN', 
                                                          ifelse(country_lc == 'Greater Antilles','QNB', 
                                                          ifelse(country_lc == 'Rungwe','TZA', 
                                                          ifelse(country_lc == 'Upper Egypt','EGY',
                                                          ifelse(country_lc %in% c("Urban", "Great Plains of North America", "Northeastern"),'USA',
                                                          ifelse(country_lc == 'Patna','IND',
                                                          ifelse(country_lc == 'Slezsko','CZE',
                                                          ifelse(country_lc == 'Western China','CHN', ISO3_RC)))))))))))))))))))))))))))]

## read in income groups
income_groups <- setDT(read.dta13(file.path(codes, paste0('wb_historical_incgrps_', abrv_yr, '.dta'))))

## attach income groups
health_grants_label2 <- merge(health_grants_label2, income_groups, by = c('ISO3_RC', 'YEAR'), all.x = T)

######################################################################################
## STEP 3: Tagging transfers from foundations to channels we already track          ##
## (UN Agencies and NGOs)                                                           ##
######################################################################################
## drop BMFG because they are tracked separately
health_grants_sub <- health_grants_label2[legacy_gm_key != 'GATE023']


## pull foundations to tag transfer
grant_names <- unique(health_grants_sub$recip_name)
foundation_names <- grant_names[grant_names %like% 'Foundation']

## tagging transfers to other foundations
health_grants_sub$ELIM_CH = 0
health_grants_sub$RECIPIENT_AGENCY_SECTOR = 'OTH' 
health_grants_sub$CHANNEL = 'US_FOUND'
health_grants_sub$ELIM_CH <- ifelse(health_grants_sub$gm_name %in% foundation_names, 1, 0)
tag_foundations <- health_grants_sub[, c('ELIM_CH', 'CHANNEL') := list(ifelse(recip_name %like% 'Pan American Health Organization', 1, 
                                                                              ## if UNDP is added as a channel
                                                                              ## ifelse(recip_name %like% 'United Nations Development Programme', 1, 
                                                                              ifelse(recip_name %like% 'United Nations Population Fund', 1, 
                                                                              ifelse(recip_name %like% 'United Nations Programme on HIV/AIDS', 1, 
                                                                              ifelse(recip_name %like% 'World Health Organization', 1, 
                                                                              ifelse(recip_name %like% 'Global Fund to Fight AIDS, Tuberculosis and Malaria', 1, 
                                                                              ifelse(recip_name %like% 'GAVI', 1, 
                                                                              ifelse(recip_name %like% 'Inter-American Development Bank', 1,    
                                                                              ifelse(recip_name %like% 'World Bank', 1,
                                                                              ifelse(recip_name %like% 'UNICEF', 1,
                                                                              ifelse(recip_name %like% 'Wellcome Trust', 1, 
                                                                              ifelse(recip_name %like% 'Asian Development Bank', 1, ELIM_CH))))))))))),
                                                                              ifelse(recip_name %like% 'Pan American Health Organization', 'PAHO', 
                                                                              ## if UNDP is added as a channel
                                                                              ## ifelse(recip_name %like% 'United Nations Development Programme', 'UNDP', 
                                                                              ifelse(recip_name %like% 'United Nations Population Fund', 'UNFPA', 
                                                                              ifelse(recip_name %like% 'United Nations Programme on HIV/AIDS', 'UNAIDS', 
                                                                              ifelse(recip_name %like% 'World Health Organization', 'WHO', 
                                                                              ifelse(recip_name %like% 'Global Fund to Fight AIDS, Tuberculosis and Malaria', 'GFATM', 
                                                                              ifelse(recip_name %like% 'GAVI', 'GAVI', 
                                                                              ifelse(recip_name %like% 'Inter-American Development Bank', 'IDB',    
                                                                              ifelse(recip_name %like% 'World Bank', 'WB',
                                                                              ifelse(recip_name %like% 'UNICEF', 'UNICEF',
                                                                              ifelse(recip_name %like% 'Wellcome Trust', 'WELLCOME', 
                                                                              ifelse(recip_name %like% 'Asian Development Bank', 'AsDB', ELIM_CH))))))))))))]
## tagging transfers to UN Agencies/bilaterals
agencies <- setDT(read.dta13(file.path(j, 'Project/IRH/DAH/RESEARCH/CHANNELS/2_NGO/1_VOLAG/DESCRIPTIVE_VARIABLES/Agency_ID_FF2017.dta')))
intl_agencies <- setDT(read.dta13(file.path(j, 'Project/IRH/DAH/RESEARCH/CHANNELS/2_NGO/1_VOLAG/DESCRIPTIVE_VARIABLES/Intl_Agency_ID_FF2017.dta')))
foundations <- tag_foundations[, agency := recip_name]

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
#----------------------------# ####

save_dataset(foundations_prep, 'pre_kws_2013_15', 'US_FOUNDS', 'stage1', write_dta = T)

cat('\n\n')
cat(green(' #######################\n'))
cat(green(' #### WB LAUNCH KWS ####\n'))
cat(green(' #######################\n\n'))

cat('  Create keyword search config\n')
#----# Create keyword search config #----# ####
create_Health_config(data_path = get_path('US_FOUNDS', 'stage1'),
                     channel_name = 'WB',
                     varlist = c('description', 'type_tran', 'activity_tran', 'pop_grp_tran'),
                     language = 'english',
                     function_to_run = 1)
#----------------------------------------# ####

cat('  Launch keyword search\n')
#----# Launch keyword search #----# ####
launch_Health_ADO(channel_name = 'US_FOUNDS')
#---------------------------------# ####