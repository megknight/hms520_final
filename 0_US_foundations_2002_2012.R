######################################################################################
## Author: Casey Graves                                                             ##
## Translated by: Megan Knight                                                      ##
## Date: 9/12/2014                                                                  ##
## Purpose: Estimating US Foundation DAH using new grant-level data from the        ##
## Foundation Center between 2002 and 2012.                                         ## 
######################################################################################
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
source(file.path(h, 'repos/hms520_final/string_cleaning_function.R'))

## paramaters for FGH report year
report_yr <- 2020 ## FGH report year
abrv_yr <- 20 ## abbreviated FGH report year
crs_mmyy = '1020'	## MMYY of current CRS data

## define directories 
root <- file.path(j, 'Project/IRH/DAH/RESEARCH')
raw <- file.path(root, paste0('CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/DATA/RAW/FGH_',report_yr))
int <- file.path(root, 'CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/DATA/INT')
fin <- file.path(root, 'CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/DATA/FIN')
CRS <- file.path(root, paste0('CHANNELS/1_BILATERALS_EC/1_CRS/DATA/FIN/CRS_', crs_mmyy))				
codes <- file.path(root, 'INTEGRATED DATABASES/COUNTRY FEATURES')
HFA	<- file.path(root, 'INTEGRATED DATABASES/HEALTH FOCUS AREAS')

######################################################################################
## STEP 1: Import grant-level data from the Foundation Center -- new classification ##
## as of FGH 2016)                                                                  ##
######################################################################################
## pull grants with data between 2002 - 2012
grants <- fread(file.path(root, 'CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/DATA/RAW/FGH_2017/International_Grants_2002_2012.csv'))  

## keep only health projects or health recipients
health_grants <- grants[activity_override %like% 'SE' | recip_subject_code %like% 'SE']

## drop projects that are allied health	(Water access, sanitation and hygiene; Sanitation; Environmental health; Clean water supply; Bioethics; Art and music therapy)
allied_projects <- c('SE080200', 'SE030100', 'SE140100', 'SE130701', 'SE130200', 'SE130702', 'SE130700')
health_grants <- health_grants[!(activity_override %in% allied_projects)]

######################################################################################
## STEP 2: Splitting disbursements among the list recipient countries               ##
######################################################################################
## Often the country_tran variable will list two or more countries, so we will want ##
## to split the grant amount evenly between them.                                   ##
######################################################################################
## TODO: @Ian -- ADD FUNCTION FOR GRANT SPLITTING
## keep US grants
health_grants <- health_grants[gm_country != "CH"]

## clean recipient country
health_grants[, countryname := grant_intl_area_served_tran]

## subset for only US agencies that recieved grants for international work
health_grants[, countryname := ifelse(grant_intl_area_served_tran=="", recip_country_tran, countryname)]

## create separate column for each recipient (some grants have up to 8 recipients listed)
cols <- max(lengths(gregexpr(';', health_grants$countryname)) + 1)
health_grants_wide <- separate(health_grants, col = 'countryname', sep = ';', into = paste0('countryname_',seq_along(1:cols)), remove = F)

## transform data long
health_grants_wide$recipient <- health_grants_wide$countryname
health_grants_long <- melt(health_grants_wide, measure.vars = paste0('countryname_',seq_along(1:cols)), value.name = 'recipient_country')
health_grants_long[, c('recipient_country', 'recipient') := list(ifelse(recipient_country == '', NA, recipient_country), 
                                                                 ifelse(recipient == '', NA, recipient))]
health_grants_long <- health_grants_long[!(is.na(recipient_country) & !is.na(recipient))]

## cumulative and total counts by grant
health_grants_long$n=ave(1:length(health_grants_long$grant_key), health_grants_long$grant_key, FUN = seq_along)
health_grants_long$N=ave(1:length(health_grants_long$grant_key), health_grants_long$grant_key, FUN = length)

## split grant amount evenly among recipients
health_grants_long[, amount_split := amount/N]

## data prep for merging ISO codes
health_grants_long[, countryname := trimws(countryname)]
health_grants_long[, countryname := ifelse(countryname == 'Congo, Democratic Republic of the', 'Congo, Democratic Republic of', 
                                    ifelse(countryname == 'Gambia, Republic of The', 'Gambia, The',
                                    ifelse(countryname %in% grepl("West Bank/Gaza", health_grants_long$countryname, useBytes = T), 'West Bank and Gaza', 
                                    ifelse(countryname %in% grepl("Lao", health_grants_long$countryname, useBytes = T), "Laos", 
                                    ifelse(countryname %in% grepl("s Republic of Korea", health_grants_long$countryname, useBytes = T), "Democratic Peoples Republic of Korea", countryname)))))]

corrected_names <- fread(file.path(int, "Countries for Cities_FGH_2018.csv"))[countryname != '']
health_grants_long <- merge(health_grants_long, corrected_names, by = 'countryname', all.x = T)
health_grants_long <- health_grants_long[, countryname := ifelse(!is.na(countryname_corrected), countryname_corrected, countryname)]                                                                                            

health_grants_long$country_lc <- health_grants_long$countryname
health_grants_long <- health_grants_long[, country_lc := ifelse(country_lc %in% c('England', "Wales", 'Northern Ireland'), "United Kingdom, England and Wales",
                                                         ifelse(country_lc %in% c("Philipines", "Phillipines"), "Philippines",
                                                         ifelse(country_lc == 'Plurinational State of Bolivia', 'Bolivia',country_lc)))]

## pull ISO codes
iso_codes <- setDT(read.dta13(file.path(codes, paste0("countrycodes_official_",report_yr,".dta"))))

## attach ISO codes
health_grants_label1 <- merge(health_grants_long, unique(iso_codes[, c('country_lc', 'iso3')]), by = 'country_lc', all.x = T)

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

health_grants_label2$countryname <- health_grants_label2$country_lc 
health_grants_label2[, ISO3_RC := ifelse(countryname %in% c("Scotland","United Kingdom, England and Wales") , "GBR", ISO3_RC)]

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

## pull foundations to tag transfers
grant_names <- unique(health_grants_sub$recip_name)
foundation_names <- grant_names[grepl("Foundation", grant_names, useBytes = T)]

## tagging transfers to other foundations
health_grants_sub$ELIM_CH = 0
health_grants_sub$RECIPIENT_AGENCY_SECTOR = 'OTH' 
health_grants_sub$CHANNEL = 'US_FOUND'
health_grants_sub$ELIM_CH <- ifelse(health_grants_sub$gm_name %in% foundation_names, 1, 0)
tag_foundations <- health_grants_sub[, c('ELIM_CH', 'CHANNEL') := list(ifelse(recip_name %in% grepl('Pan American Health Organization', health_grants_sub$recip_name, useBytes = T), 1, 
                                                                       ## if UNDP is added as a channel
                                                                       ## ifelse(recip_name %in% grepl('United Nations Development Programme', health_grants_sub$recip_name, useBytes = T), 1, 
                                                                       ifelse(recip_name %in% grepl('United Nations Population Fund', health_grants_sub$recip_name, useBytes = T), 1, 
                                                                       ifelse(recip_name %in% grepl('United Nations Programme on HIV/AIDS', health_grants_sub$recip_name, useBytes = T), 1, 
                                                                       ifelse(recip_name %in% grepl('World Health Organization', health_grants_sub$recip_name, useBytes = T), 1, 
                                                                       ifelse(recip_name %in% grepl('Global Fund to Fight AIDS, Tuberculosis and Malaria', health_grants_sub$recip_name, useBytes = T), 1, 
                                                                       ifelse(recip_name %in% grepl('GAVI', health_grants_sub$recip_name, useBytes = T), 1, 
                                                                       ifelse(recip_name %in% grepl('Inter-American Development Bank', health_grants_sub$recip_name, useBytes = T), 1, 
                                                                       ifelse(recip_name %in% grepl('World Bank', health_grants_sub$recip_name, useBytes = T), 1, 
                                                                       ifelse(recip_name %in% grepl('UNICEF', health_grants_sub$recip_name, useBytes = T), 1, 
                                                                       ifelse(recip_name %in% grepl('Wellcome Trust', health_grants_sub$recip_name, useBytes = T), 1, ELIM_CH)))))))))),
                                                                       ifelse(recip_name %in% grepl('Pan American Health Organization', health_grants_sub$recip_name, useBytes = T), 'PAHO', 
                                                                       ## if UNDP is added as a channel
                                                                       ## ifelse(recip_name %in% grepl('United Nations Development Programme', health_grants_sub$recip_name, useBytes = T), 'United Nations Development Programme',  
                                                                       ifelse(recip_name %in% grepl('United Nations Population Fund', health_grants_sub$recip_name, useBytes = T), 'UNFPA', 
                                                                       ifelse(recip_name %in% grepl('United Nations Programme on HIV/AIDS', health_grants_sub$recip_name, useBytes = T), 'UNAIDS', 
                                                                       ifelse(recip_name %in% grepl('World Health Organization', health_grants_sub$recip_name, useBytes = T), 'WHO', 
                                                                       ifelse(recip_name %in% grepl('Global Fund to Fight AIDS, Tuberculosis and Malaria', health_grants_sub$recip_name, useBytes = T), 'GFATM', 
                                                                       ifelse(recip_name %in% grepl('GAVI', health_grants_sub$recip_name, useBytes = T), 'GAVI', 
                                                                       ifelse(recip_name %in% grepl('Inter-American Development Bank', health_grants_sub$recip_name, useBytes = T), 'IDB', 
                                                                       ifelse(recip_name %in% grepl('World Bank', health_grants_sub$recip_name, useBytes = T), 'WB', 
                                                                       ifelse(recip_name %in% grepl('UNICEF', health_grants_sub$recip_name, useBytes = T), 'UNICEF', 
                                                                       ifelse(recip_name %in% grepl('Wellcome Trust', health_grants_sub$recip_name, useBytes = T), 'WELLCOME', ELIM_CH)))))))))))]

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

######################################################################################
## STEP 4: Allocate to health focus areas                                           ##
######################################################################################
## TODO: @Ian -- INTEGRATE FGH KEYWORD SEARCH FUNCTION (lines 281+). ALSO DOUBLE CHECK -- THEY DON'T PREP THE KEYWORDS LIKE THE LAST SCRIPT 
