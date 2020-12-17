#----# Docstring #----# ####
# Project:  FGH 2020
# Purpose:  Intake + format CHINA COVID-19 data
# Date:     11/03/2020
# Author:   Kyle Simpson
#---------------------# ####

#----# Environment Prep #----# ####
rm(list=ls())

if (!exists("code_repo"))  {
  code_repo <- unname(ifelse(Sys.info()['sysname'] == "Windows", "H:/repos/fgh/", paste0("/ihme/homes/", Sys.info()['user'][1], "/repos/fgh/")))
}
source(paste0(code_repo, 'FUNCTIONS/utils.R'))

# Variable prep
codes <- paste0(dah.roots$j, 'Project/IRH/DAH/RESEARCH/INTEGRATED DATABASES/COUNTRY FEATURES/')
#----------------------------# ####


cat('\n\n')
cat(green(' ##########################\n'))
cat(green(' ## US FOUNDS COVID PREP ##\n'))
cat(green(' ##########################\n\n'))


cat('  Read in COVID data\n')
#----# Read in COVID data #----# ####

# CANDID data
cnd <- setDT(read.xlsx(paste0(get_path('US_FOUNDS', 'raw'), 'FC_Output_Covid_2018_revised.xlsx'), sheet = 'IHME_COVID-19_Grants'))
cnd <- cnd[gm_country == "US",
           c('gm_name', 'gm_country', 'gm_type', 'recip_name', 'recip_country', 'recip_subject_code', 'recip_subject_tran',
           'recip_organization_tran', 'amount', 'duration', 'yr_issued', 'description', 'activity_override', 'activity_override_tran',
           'grant_strategy_tran', 'grant_transaction_tran', 'currency', 'intl_countries')]
setnames(cnd, c('gm_name', 'gm_country', 'gm_type', 'recip_name', 'recip_country', 'recip_subject_tran', 'recip_organization_tran',
                'yr_issued', 'activity_override_tran', 'grant_strategy_tran', 'grant_transaction_tran', 'intl_countries'),
         c('donor_agency', 'donor_agency_iso2', 'funding_type', 'recipient_agency', 'recipient_country_iso2', 'grant_purpose', 
           'recipient_organization_type', 'year', 'purpose_name', 'grant_strategy', 'transaction_type', 'country_of_benefit_iso2'))

#-------------------------------------------------------------# ####

cat('  Format CANDID data types\n')
#----# Format CANDID data types #----# ####

# keep health codes ("SE")
others <- cnd[!(activity_override %like% "SE" | recip_subject_code %like% "SE")]
cnd <- cnd[activity_override %like% "SE" | recip_subject_code %like% "SE"]

# remove allied health codes
cnd <- cnd[activity_override %ni% c('SE080200', 'SE030100', 'SE140100', 'SE130701', 'SE130200', 'SE130702', 'SE130700')]

## get recipient country or countries -- split evenly among countries if more than one
cnd <- grant_splitting(cnd, country_col = 'recipient_country_iso2', dah_col = 'amount', separator = '; ')

# Donor type
cnd$funding_type <- ifelse(cnd$funding_type == 'CG', 'Direct Corporate Giving Program',
                           ifelse(cnd$funding_type == 'CS', 'Corporate Foundation',
                                  ifelse(cnd$funding_type == 'IF', 'Independent Foundation',
                                         ifelse(cnd$funding_type == 'PC', 'Public Charity',
                                                ifelse(cnd$funding_type == 'GO', 'GO',
                                                       ifelse(cnd$funding_type == 'FM', 'FM', ''))))))
cnd[, funding_type := paste0('Philanthropy: ', funding_type)]

# Recipient agency
cnd[recipient_agency == 'Gavi Alliance', recipient_agency := 'GAVI']

# currency
cnd[is.na(currency), currency := 'USD']

# money type
cnd[, money_type := 'new']
cnd[grepl('repurp', description, ignore.case = T),
    money_type := 'repurposed']

# channel
cnd[, channel := 'US_FOUND']

# ISO2 to ISO3
iso_map <- setDT(read.dta13(paste0(codes, 'countrycodes_official_', dah.roots$report_year, '.dta')))[, c('iso2', 'countryname_ihme')]
iso_map <- unique(iso_map)
# donor country
cnd <- merge(cnd, iso_map, by.x='donor_agency_iso2', by.y='iso2', all.x=T)
setnames(cnd, 'countryname_ihme', 'donor_country')

# recipient country
cnd <- merge(cnd, iso_map, by.x='countryname', by.y='iso2', all.x=T)
setnames(cnd, 'countryname_ihme', 'recipient_country')

# manual iso fix
cnd[countryname == 'XK',
    recipient_country := 'Kosovo']
cnd[countryname == 'SS',
    recipient_country := 'South Sudan']

# rename and subset
setnames(cnd, c('description', 'funding_type', 'purpose_name'), c('purpose', 'donor_agency_type', 'sector'))
cnd <- cnd[, c('year', 'donor_agency', 'donor_agency_type', 'donor_country', 'recipient_agency', 'recipient_country', 
               'money_type', 'purpose', 'amount', 'channel', 'sector')]
dt <- copy(cnd)
#------------------------------------# ####



cat('  Clean locations\n')
#----# Clean locations #----# ####
dt[recipient_country == 'Hong Kong Special Administrative Region of China', recipient_country := 'China']
dt[recipient_country == 'Iran', recipient_country := 'Iran (Islamic Republic of)']
dt[recipient_country == "Cote d'Ivoire", recipient_country := "Côte d'Ivoire"]
dt[recipient_country == 'Syria', recipient_country := 'Syrian Arab Republic']
dt[recipient_country == 'Tanzania', recipient_country := 'United Republic of Tanzania']
dt[recipient_country == 'Venezuela', recipient_country := 'Venezuela (Bolivarian Republic of)']
dt[recipient_country == 'United States', recipient_country := 'United States of America']
dt[donor_country == 'United States', donor_country := 'United States of America']

#---------------------------# ####

cat('  Merge metadata\n')
#----# Merge metadata #----# ####
# Donor Location IDs
isos <- setDT(fread(paste0(codes, 'fgh_custom_location_set.csv')))[level == 3, c('location_name', 'ihme_loc_id', 'region_name')]
dt <- merge(dt, isos, by.x='donor_country', by.y='location_name', all.x = T)
dt[, region_name := NULL]
setnames(dt, 'ihme_loc_id', 'iso3')
# Recipient Location IDs
dt <- merge(dt, isos, by.x='recipient_country', by.y='location_name', all.x = T)
setnames(dt, c('ihme_loc_id', 'region_name'), c('iso3_rc', 'gbd_region'))
dt[recipient_country == 'Global', iso3_rc := 'GLOBAL']
dt[recipient_country == 'Kosovo', iso3_rc := 'XKX']
rm(isos)

# Income groups
ingr <- setDT(read.dta13(paste0(codes, 'wb_historical_incgrps_', dah.roots$abrv_year, '.dta')))[YEAR == dah.roots$report_year, c('INC_GROUP', 'ISO3_RC')]
dt <- merge(dt, ingr, by.x='iso3_rc', by.y='ISO3_RC', all.x=T)
rm(ingr, codes)
dt <- dt[INC_GROUP != 'H' | is.na(INC_GROUP)]
#--------------------------# ####

# flag other channels and remove BMGF
dt <- dt[donor_agency != "Bill & Melinda Gates Foundation"]

dt[, ELIM_CH := 0]

dt[grepl('United Nations Population Fund', recipient_agency, ignore.case = T),
   `:=` (channel = 'UNFPA',
         ELIM_CH = 1)]
dt[grepl('Pan American Health Organization', recipient_agency, ignore.case = T),
   `:=` (channel = 'PAHO',
         ELIM_CH = 1)]
dt[grepl('United Nations Programme on HIV/AIDS', recipient_agency, ignore.case = T),
   `:=` (channel = 'UNAIDS',
         ELIM_CH = 1)]
dt[grepl('World Health Organization', recipient_agency, ignore.case = T),
   `:=` (channel = 'WHO',
         ELIM_CH = 1)]
dt[grepl('Global Fund to Fight AIDS, Tuberculosis and Malaria', recipient_agency, ignore.case = T),
   `:=` (channel = 'GFATM',
         ELIM_CH = 1)]
dt[grepl('GAVI', recipient_agency, ignore.case = T),
   `:=` (channel = 'GAVI',
         ELIM_CH = 1)]
dt[grepl('Inter-American Development Bank', recipient_agency, ignore.case = T),
   `:=` (channel = 'IDB',
         ELIM_CH = 1)]
dt[grepl('World Bank', recipient_agency, ignore.case = T),
   `:=` (channel = 'WB',
         ELIM_CH = 1)]
dt[grepl('UNICEF', recipient_agency, ignore.case = T),
   `:=` (channel = 'UNICEF',
         ELIM_CH = 1)]
dt[grepl('Wellcome Trust', recipient_agency, ignore.case = T),
   `:=` (channel = 'WELLCOME',
         ELIM_CH = 1)]
dt[grepl('Asian Development Bank', recipient_agency, ignore.case = T),
   `:=` (channel = 'AsDB',
         ELIM_CH = 1)]

# tag transfers from foundations to NGOs that we already track
agency_id <- data.table(read.dta13('/home/j/Project/IRH/DAH/RESEARCH/CHANNELS/2_NGO/1_VOLAG/DESCRIPTIVE_VARIABLES/Agency_ID_FF2017.dta'))
intl_agency_id <- data.table(read.dta13('/home/j/Project/IRH/DAH/RESEARCH/CHANNELS/2_NGO/1_VOLAG/DESCRIPTIVE_VARIABLES/Intl_Agency_ID_FF2017.dta'))
setnames(dt, 'recipient_agency', 'agency')

# clean strings
agency_id <- string_clean(agency_id, 'agency')
intl_agency_id <- string_clean(intl_agency_id, 'agency')
dt <- string_clean(dt, 'agency')

# merge and tag ngos
dt <- merge(dt, agency_id[, .(id, upper_agency)], by = 'upper_agency', all.x = T)
dt[!(is.na(id)),
   `:=` (ELIM_CH = 1,
         channel = 'NGO')]
dt[, id := NULL]

# merge and tag intl ngos
dt <- merge(dt, intl_agency_id[, .(id, upper_agency)], by = 'upper_agency', all.x = T)
dt[!(is.na(id)),
   `:=` (ELIM_CH = 1,
         channel = 'NGO')]
dt[, id := NULL]

# these ngos are tracked as part of fgh, but have a slight variation on the name
ngo_name_variations <- c("ACTIONAID", "ADVENTURES IN HEALTH EDUCATION AND AGRICULTURAL DEVELOPMENT", "AMERICARES", "CATHOLIC RELIEF SERVICES", "CHILDFUND",
                         "DTREE INC", "DOCTORS OF THE WORLD USA", "DOCTORS WITHOUT BORDERS USA", "ENVIRONMENTAL DEFENSE FUND",
                         "ENVIRONMENTAL LAW ALLIANCE WORLDWIDE ELAW", "FOUNDATION FOR A CIVIL SOCIETY", "FRIENDS OF THE WORLD FOOD PROGRAM",
                         "HEALTHPARTNERS INSTITUTE FOR EDUCATION AND RESEARCH", "HEART TO HEART INTERNATIONAL CHILDRENS MEDICAL ALLIANCE",
                         "INTERNATIONAL SERVICES OF HOPE/IMPACT MEDICAL DIVISION ISOH/IMPACT", "MANO A MANO MEDICAL RESOURCES", "MEDISEND", "MEDISEND",
                         "MERCY AND TRUTH MEDICAL MISSIONS", "NATIONAL ASSOCIATION OF PEOPLE LIVING WITH HIV/AIDS", "OPEN DOOR MEDICAL MINISTRIES",
                         "OPERATION SMILE INTERNATIONAL", "PARTNERS IN HEALTH", "PATH", "PROGRAM FOR APPROPRIATE TECHNOLOGY IN HEALTH PATH",
                         "PROJECT HOPE PEOPLETOPEOPLE HEALTH FOUNDATION", "RARE CENTER FOR TROPICAL CONSERVATION", "SAVE THE CHILDREN",
                         "SAVE THE CHILDREN FUND", "SURGICAL EYE EXPEDITIONS INTERNATIONAL", "VOLUNTEERS FOR INTERAMERICAN DEVELOPMENT ASSISTANCE VIDA",
                         "WATERAID", "WORLD CONCERN", "WORLD VISION RELIEF AND DEVELOPMENT", "SURGICAL EYE EXPEDITIONS INTERNATIONAL ENDOWMENT TRUST")

dt[agency %in% ngo_name_variations,
   `:=` (ELIM_CH = 1,
         channel = 'NGO')]
setnames(dt, 'agency', 'recipient_agency')

#--------------------------# ####


cat('  Configure and launch keyword search\n')
#----# Configure and launch keyword search #----# ####
dt <- covid_kws(dataset = dt, keyword_search_colnames = 'purpose', 
                keep_clean = F, keep_counts = F, languages = 'english')

covid_stats_report(dataset = dt[ELIM_CH == 0], amount_colname = 'amount',
                   recipient_iso_colname = 'iso3_rc', save_plot = T,
                   output_path = '/home/j/Project/IRH/DAH/RESEARCH/CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/OUTPUT/FGH_2020/')
#-----------------------------------------------# ####

cat('  Calculate amounts by HFA\n')
#----# Calculate amounts by HFA #----# ####
dt[, `:=`(COVID_total = NULL, COVID_total_prop = NULL)]

hfas <- gsub('_prop', '', names(dt)[names(dt) %like% '_prop'])
for (hfa in hfas) {
  dt[, eval(paste0(hfa, '_amt')) := amount * get(paste0(hfa, '_prop'))]
  dt[, eval(paste0(hfa, '_prop')) := NULL]
}

# Check sum still holds
dt <- rowtotal(dt, 'amt_test', names(dt)[names(dt) %like% '_amt'])
dt[round(amount, 2) == round(amt_test, 2), check := 1]
dt[, `:=`(amt_test = NULL, check = NULL)]

# Rename 
setnames(dt, 'amount', 'total_amt')
#------------------------------------# ####

cat('  Save out COVID dataset\n')
#----# Save out COVID dataset #----# ####
dt <- dt[, c('year', 'channel', 'donor_agency', 'iso3', 'donor_country', 'recipient_agency', 'iso3_rc', 'recipient_country', 'gbd_region', 
             'INC_GROUP', paste0(hfas, '_amt'), 'total_amt', 'money_type'), with=F]
save_dataset(dt, 'COVID_prepped', 'US_FOUNDS', 'fin')
#----------------------------------# ####