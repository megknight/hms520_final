
** ***
******************************* 2002-2012 data *******************************************************************
// Step 1: Import grant-level data from the Foundation Center (new classification as of FGH 2016)
** ***************************************************************************************************************

set more off
	clear all
	set maxvar 32000
	cap log close
	if c(os) == "Unix" {
		global j "/home/j"
		set odbcmgr unixodbc
	}
	else if c(os) == "Windows" {
		global j "J:"
	}
	
	
	local report_yr = 2020				// FGH report year
	local abrv_yr = 20					// abbraviated FGH report year
	local crs_mmyy = "1020"				// MMYY of current CRS data
	

	local working_dir 	            "$j/Project/IRH/DAH/RESEARCH"
	local RAW		                "`working_dir'/CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/DATA/RAW/FGH_`report_yr'"
	local INT 						"`working_dir'/CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/DATA/INT"
	local FIN 						"`working_dir'/CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/DATA/FIN"
	local CRS 						"`working_dir'/CHANNELS/1_BILATERALS_EC/1_CRS/DATA/FIN/CRS_`crs_mmyy'"
	local CODES 					"`working_dir'/INTEGRATED DATABASES/COUNTRY FEATURES"
	local HFA						"`working_dir'/INTEGRATED DATABASES/HEALTH FOCUS AREAS"

// So here, I should add in the 2013 data to this .csv, right? (which is the standalone 2016 data)
import delimited "`working_dir'/CHANNELS/6_FOUNDATIONS/2_US_FOUNDATIONS/DATA/RAW/FGH_2017/International_Grants_2002_2012.csv",  clear varnames(1)  // Don't change this path - files not brought forward
	
	tempfile data
	save `data'
	
// keep only health projects or health recipients
	keep if regexm(activity_override, "SE") ==1 | regexm(recip_subject_code, "SE")==1
	
// drop projects that are allied health	- (Water access, sanitation and hygiene, Sanitation, Environmental health, Clean water supply, Bioethics, Art and music therapy)
	drop if activity_override=="SE080200" | activity_override =="SE030100" | activity_override =="SE140100" | activity_override =="SE130701" | activity_override =="SE130200" | activity_override =="SE130702" | activity_override =="SE130700" 
        	
** ***
// Step 2: Splitting disbursements among the list recipient countries (often the country_tran variable will list two or more countries, so we will want to split the grant amount evenly between them).
** ***	
// keep US grants
	drop if gm_country!=""

// clean recipient country
	g countryname=grant_intl_area_served_tran
	//replace countryname="Congo, Democratic Republic of" if countryname=="Congo, Democratic Republic of the"
	//replace countryname="Gambia, The" if countryname=="Gambia, Republic of The"
	//replace countryname="West Bank and Gaza" if regexm(countryname,"West Bank/Gaza")==1
	
	// subset for only US agencies that recieved grants for international work
	replace countryname= recip_country_tran if grant_intl_area_served_tran==""
	
	split countryname, p(";")
	
// split up grant amount among all recipient countries (some grants have up to 10 recipients listed)
	rename countryname recipient
	reshape long countryname, i(grant_key) j(recipient_country)
	drop if countryname=="" & recipient!=""
	
	bysort grant_key: gen n= _n
	bysort grant_key: gen N= _N
	gen double amount_split = amount/N
	
// merge in recipient country isocode 
// clean data for merge
	replace countryname = trim(countryname) 
	replace countryname="Congo, Democratic Republic of" if countryname=="Congo, Democratic Republic of the"
	replace countryname="Gambia, The" if countryname=="Gambia, Republic of The"
	replace countryname="West Bank and Gaza" if regexm(countryname,"West Bank/Gaza")==1
	replace countryname="Lao Peoples Democratic Republic" if regexm(countryname,"Lao")==1
	replace countryname="Democratic Peoples Republic of Korea" if regexm(countryname,"s Republic of Korea")==1
	
	preserve
	
	import delimited "`INT'/Countries for Cities_FGH_2018.csv" , clear varnames(1) // Don't change this path - files not brought forward
	drop if countryname ==""
	tempfile correctednames
	save `correctednames'
	
	restore
	merge m:1 countryname using `correctednames'
	
	replace countryname =countryname_corrected if _m==3
	drop _m
	
	rename countryname country_lc
	replace country_lc = "United Kingdom, England and Wales" if country_lc=="England"
	replace country_lc = "United Kingdom, England and Wales" if country_lc=="Wales"
	replace country_lc = "United Kingdom, England and Wales" if country_lc=="Northern Ireland"
	replace country_lc = "Philippines" if country_lc=="Philipines"
	replace country_lc = "Philippines" if country_lc=="Phillipines"
	replace country_lc = "Bolivia" if country_lc=="Plurinational State of Bolivia"

	merge m:1 country_lc using "`CODES'/countrycodes_official_`report_yr'.dta", keepusing(country_lc iso3)
	keep if _m==1 | _m==3
	drop _m
	
	rename iso3 ISO3_RC
	
// Fill in ISO3_RC codes for regions and country names that didn't match	
	replace ISO3_RC = "QMA" if country_lc == "Africa" 
	replace ISO3_RC = "QRA" if country_lc == "Asia" 
	replace ISO3_RC = "QNB" if country_lc == "Caribbean" 
	replace ISO3_RC = "QME" if inlist(country_lc, "Southern Africa", "Central Africa" , "Sub-Saharan Africa", "Western Africa", "Eastern Africa", "Horn of Africa")
	replace ISO3_RC = "QNC" if inlist(country_lc, "Central America", "North America")
	replace ISO3_RC = "QRS" if country_lc == "Central Asia"
	replace ISO3_RC = "QRB" if inlist(country_lc, "Eastern Asia", "China & Mongolia")
	replace ISO3_RC = "QSA" if inlist(country_lc, "Eastern Europe", "Europe")
	replace ISO3_RC = "WLD" if inlist(country_lc, "Global Programs", "Global programs")
	replace ISO3_RC = "QNE" if inlist(country_lc, "Latin America", "South America")
	replace ISO3_RC = "QMD" if inlist(country_lc, "Mediterranean Basin", "Northeast Africa", "Northern Africa")
	replace ISO3_RC = "QTA" if country_lc == "Oceania"
	replace ISO3_RC = "QZA" if inlist(country_lc, "Pacific Rim", "Arctic Region", "Developing Countries", "Developing countries")
	replace ISO3_RC = "SWE" if country_lc == "Scandinavia" // will be dropped because HIC
	replace ISO3_RC = "QRA" if inlist(country_lc, "Southeast Asia", "Southeastern Asia")
	replace ISO3_RC = "QRC" if inlist(country_lc, "Southern Asia", "Indian Subcontinent & Afghanistan")
	replace ISO3_RC = "QRE" if country_lc=="Middle East"
	// Countries
	replace ISO3_RC = "PSE" if country_lc == "East Jerusalem"
	replace ISO3_RC = "CIV" if regexm(country_lc, "Ivoire")==1
	replace ISO3_RC = "BEL" if country_lc=="Paal" // Either a town in the netherlands or belgium, high income so will be dropped
	*replace ISO3_RC = "KOS" if country_lc == "Kosovo"

	rename country_lc countryname
	
// merge in income groups
	rename yr_issued YEAR

	replace ISO3_RC="GBR" if countryname=="Scotland" | countryname=="United Kingdom, England and Wales"
	
	merge m:1 ISO3_RC YEAR using "`CODES'/wb_historical_incgrps_`abrv_yr'.dta", keepusing(INC_GROUP)
	keep if _m==1 | _m==3
	drop _m

** ***
// Step 3: Tagging transfers from foundations to channels we already track (UN Agencies and NGOs).
** ***
	
// drop BMGF (we track them separately)
	drop if legacy_gm_key == "GATE023"
	
// Tagging transfers to other foundations

	preserve
	keep recip_name 
	duplicates drop
	keep if regexm(recip_name, "Foundation")
	rename recip_name gm_name
	tempfile grantrecipients
	save `grantrecipients', replace
	restore	
	
	gen ELIM_CH = 0
	gen RECIPIENT_AGENCY_SECTOR = "OTH" 
	gen CHANNEL = "US_FOUND"
	merge m:m gm_name using `grantrecipients'
	replace ELIM_CH = 1 if _m == 3
	drop if _m == 2 
	drop _m
	
// Tagging transfers to UN Agencies/bilaterals

	replace ELIM_CH = 1 if regexm(recip_name, "Pan American Health Organization")
		replace CHANNEL = "PAHO" if regexm(recip_name, "Pan American Health Organization")
	// If UNDP is added as a channel:
		//replace ELIM_CH = 1 if regexm(recip_name, "United Nations Development Programme")
		//replace CHANNEL = "UNDP" if regexm(recip_name, "United Nations Development Programme")
	replace ELIM_CH = 1 if regexm(recip_name, "United Nations Population Fund")
		replace CHANNEL = "UNFPA" if regexm(recip_name, "United Nations Population Fund")
	replace ELIM_CH = 1 if regexm(recip_name, "United Nations Programme on HIV/AIDS")
		replace CHANNEL = "UNAIDS" if regexm(recip_name, "United Nations Programme on HIV/AIDS")
	replace ELIM_CH = 1 if regexm(recip_name, "World Health Organization")
		replace CHANNEL = "WHO" if regexm(recip_name, "World Health Organization")
	replace ELIM_CH = 1 if regexm(recip_name, "Global Fund to Fight AIDS, Tuberculosis and Malaria")
		replace CHANNEL = "GFATM" if regexm(recip_name, "Global Fund to Fight AIDS, Tuberculosis and Malaria")
	replace ELIM_CH = 1 if regexm(recip_name, "GAVI")
		replace CHANNEL = "GAVI" if regexm(recip_name, "GAVI")
	replace ELIM_CH = 1 if regexm(recip_name, "Inter-American Development Bank")
		replace CHANNEL = "IDB" if regexm(recip_name, "Inter-American Development Bank")
	replace ELIM_CH = 1 if regexm(recip_name, "World Bank")
		replace CHANNEL = "WB" if regexm(recip_name, "World Bank")
	replace ELIM_CH = 1 if regexm(recip_name, "UNICEF")
		replace CHANNEL = "UNICEF" if regexm(recip_name, "UNICEF")
	replace ELIM_CH = 1 if regexm(recip_name, "Wellcome Trust")
		replace CHANNEL = "WELLCOME" if regexm(recip_name, "Wellcome Trust")

	// AfDB, AsDB not in data 

	tempfile temp
	save `temp', replace

// Tagging transfers from foundations to NGOs that we already track

// Agencies
	use "$j/Project/IRH/DAH/RESEARCH/CHANNELS/2_NGO/1_VOLAG/DESCRIPTIVE_VARIABLES/Agency_ID_FF2017.dta", clear // keep for now (new dataset not yet available)
	replace agency = strupper(agency)
	replace agency = trim(agency)
	replace agency = subinstr(agency, ".", "", .)
	replace agency = subinstr(agency, ",", "", .)
	replace agency = subinstr(agency, "'", "", .)
	replace agency = subinstr(agency, "(", "", .)
	replace agency = subinstr(agency, ")", "", .)	
	replace agency = subinstr(agency, "-", "", .)
	replace agency = subinstr(agency, "THE", "", .)	
	replace agency = subinstr(agency, "&", "", .)
	replace agency = subinstr(agency, "AND", "", .)	
	replace agency = subinstr(agency, "  ", " ", .)	
	tempfile agency
	save `agency', replace

// International agencies
	use "$j/Project/IRH/DAH/RESEARCH/CHANNELS/2_NGO/1_VOLAG/DESCRIPTIVE_VARIABLES/Intl_Agency_ID_FF2017.dta", clear // keep for now (new dataset not yet available)
	replace agency = strupper(agency)
	replace agency = trim(agency)
	replace agency = subinstr(agency, ".", "", .)
	replace agency = subinstr(agency, ",", "", .)
	replace agency = subinstr(agency, "'", "", .)
	replace agency = subinstr(agency, "(", "", .)
	replace agency = subinstr(agency, ")", "", .)	
	replace agency = subinstr(agency, "-", "", .)
	replace agency = subinstr(agency, "THE", "", .)	
	replace agency = subinstr(agency, "&", "", .)
	replace agency = subinstr(agency, "AND", "", .)	
	replace agency = subinstr(agency, "  ", " ", .)	
	tempfile intlagency
	save `intlagency', replace

// Foundations 	
	use `temp',clear
	rename recip_name agency
	replace agency = strupper(agency)
	replace agency = trim(agency)
	replace agency = subinstr(agency, ".", "", .)
	replace agency = subinstr(agency, ",", "", .)
	replace agency = subinstr(agency, "'", "", .)
	replace agency = subinstr(agency, "(", "", .)
	replace agency = subinstr(agency, ")", "", .)	
	replace agency = subinstr(agency, "-", "", .)
	replace agency = subinstr(agency, "THE", "", .)	
	replace agency = subinstr(agency, "&", "", .)
	replace agency = subinstr(agency, "AND", "", .)	
	replace agency = subinstr(agency, "  ", " ", .)
	
// merge the list of NGOs we track and mark to drop if it matches. Drop if merge = 2 because this is an NGO that we track but is not in the foundations data. 
	merge m:m agency using `agency'
	replace ELIM_CH = 1 if _merge == 3
	replace RECIPIENT_AGENCY_SECTOR = "NGO" if _merge == 3
	replace CHANNEL = "NGO" if _merge == 3
	drop if _m == 2
	drop _merge
	merge m:m agency using `intlagency'
	replace ELIM_CH = 1 if _merge == 3
	replace RECIPIENT_AGENCY_SECTOR = "NGO" if _merge == 3
	replace CHANNEL = "NGO" if _merge == 3
	drop if _m == 2	
	drop _merge
	
// These NGOs are tracked as part of FGH, but have a slight variation on the name
	replace ELIM_CH =1 if agency == "ACTIONAID" | agency == "ADVENTURES IN HEALTH EDUCATION AND AGRICULTURAL DEVELOPMENT" | agency == "AMERICARES" | agency == "CATHOLIC RELIEF SERVICES" | agency == "CHILDFUND" | agency == "DTREE INC" | agency == "DOCTORS OF THE WORLD USA" | agency == "DOCTORS WITHOUT BORDERS USA" | agency == "ENVIRONMENTAL DEFENSE FUND" | agency == "ENVIRONMENTAL LAW ALLIANCE WORLDWIDE ELAW" | agency == "FOUNDATION FOR A CIVIL SOCIETY" | agency == "FRIENDS OF THE WORLD FOOD PROGRAM" | agency == "HEALTHPARTNERS INSTITUTE FOR EDUCATION AND RESEARCH" | agency == "HEART TO HEART INTERNATIONAL CHILDRENS MEDICAL ALLIANCE" | agency == "INTERNATIONAL SERVICES OF HOPE/IMPACT MEDICAL DIVISION ISOH/IMPACT" | agency == "MANO A MANO MEDICAL RESOURCES" | agency == "MEDISEND" | agency == "MEDISEND" | agency == "MERCY AND TRUTH MEDICAL MISSIONS" | agency == "NATIONAL ASSOCIATION OF PEOPLE LIVING WITH HIV/AIDS" | agency == "OPEN DOOR MEDICAL MINISTRIES" | agency == "OPERATION SMILE INTERNATIONAL" | agency == "PARTNERS IN HEALTH" | agency == "PATH" | agency == "PROGRAM FOR APPROPRIATE TECHNOLOGY IN HEALTH PATH" | agency == "PROJECT HOPE PEOPLETOPEOPLE HEALTH FOUNDATION" | agency == "RARE CENTER FOR TROPICAL CONSERVATION" | agency == "SAVE THE CHILDREN" | agency == "SAVE THE CHILDREN FUND" | agency == "SURGICAL EYE EXPEDITIONS INTERNATIONAL" | agency == "VOLUNTEERS FOR INTERAMERICAN DEVELOPMENT ASSISTANCE VIDA" | agency == "WATERAID" | agency == "WORLD CONCERN" | agency == "WORLD VISION RELIEF AND DEVELOPMENT" | agency == "SURGICAL EYE EXPEDITIONS INTERNATIONAL ENDOWMENT TRUST"
	
	replace RECIPIENT_AGENCY_SECTOR = "NGO" if agency == "ACTIONAID" | agency == "ADVENTURES IN HEALTH EDUCATION AND AGRICULTURAL DEVELOPMENT" | agency == "AMERICARES" | agency == "CATHOLIC RELIEF SERVICES" | agency == "CHILDFUND" | agency == "DTREE INC" | agency == "DOCTORS OF THE WORLD USA" | agency == "DOCTORS WITHOUT BORDERS USA" | agency == "ENVIRONMENTAL DEFENSE FUND" | agency == "ENVIRONMENTAL LAW ALLIANCE WORLDWIDE ELAW" | agency == "FOUNDATION FOR A CIVIL SOCIETY" | agency == "FRIENDS OF THE WORLD FOOD PROGRAM" | agency == "HEALTHPARTNERS INSTITUTE FOR EDUCATION AND RESEARCH" | agency == "HEART TO HEART INTERNATIONAL CHILDRENS MEDICAL ALLIANCE" | agency == "INTERNATIONAL SERVICES OF HOPE/IMPACT MEDICAL DIVISION ISOH/IMPACT" | agency == "MANO A MANO MEDICAL RESOURCES" | agency == "MEDISEND" | agency == "MEDISEND" | agency == "MERCY AND TRUTH MEDICAL MISSIONS" | agency == "NATIONAL ASSOCIATION OF PEOPLE LIVING WITH HIV/AIDS" | agency == "OPEN DOOR MEDICAL MINISTRIES" | agency == "OPERATION SMILE INTERNATIONAL" | agency == "PARTNERS IN HEALTH" | agency == "PATH" | agency == "PROGRAM FOR APPROPRIATE TECHNOLOGY IN HEALTH PATH" | agency == "PROJECT HOPE PEOPLETOPEOPLE HEALTH FOUNDATION" | agency == "RARE CENTER FOR TROPICAL CONSERVATION" | agency == "SAVE THE CHILDREN" | agency == "SAVE THE CHILDREN FUND" | agency == "SURGICAL EYE EXPEDITIONS INTERNATIONAL" | agency == "VOLUNTEERS FOR INTERAMERICAN DEVELOPMENT ASSISTANCE VIDA" | agency == "WATERAID" | agency == "WORLD CONCERN" | agency == "WORLD VISION RELIEF AND DEVELOPMENT" | agency == "SURGICAL EYE EXPEDITIONS INTERNATIONAL ENDOWMENT TRUST"	
	
	replace CHANNEL = "NGO" if agency == "ACTIONAID" | agency == "ADVENTURES IN HEALTH EDUCATION AND AGRICULTURAL DEVELOPMENT" | agency == "AMERICARES" | agency == "CATHOLIC RELIEF SERVICES" | agency == "CHILDFUND" | agency == "DTREE INC" | agency == "DOCTORS OF THE WORLD USA" | agency == "DOCTORS WITHOUT BORDERS USA" | agency == "ENVIRONMENTAL DEFENSE FUND" | agency == "ENVIRONMENTAL LAW ALLIANCE WORLDWIDE ELAW" | agency == "FOUNDATION FOR A CIVIL SOCIETY" | agency == "FRIENDS OF THE WORLD FOOD PROGRAM" | agency == "HEALTHPARTNERS INSTITUTE FOR EDUCATION AND RESEARCH" | agency == "HEART TO HEART INTERNATIONAL CHILDRENS MEDICAL ALLIANCE" | agency == "INTERNATIONAL SERVICES OF HOPE/IMPACT MEDICAL DIVISION ISOH/IMPACT" | agency == "MANO A MANO MEDICAL RESOURCES" | agency == "MEDISEND" | agency == "MEDISEND" | agency == "MERCY AND TRUTH MEDICAL MISSIONS" | agency == "NATIONAL ASSOCIATION OF PEOPLE LIVING WITH HIV/AIDS" | agency == "OPEN DOOR MEDICAL MINISTRIES" | agency == "OPERATION SMILE INTERNATIONAL" | agency == "PARTNERS IN HEALTH" | agency == "PATH" | agency == "PROGRAM FOR APPROPRIATE TECHNOLOGY IN HEALTH PATH" | agency == "PROJECT HOPE PEOPLETOPEOPLE HEALTH FOUNDATION" | agency == "RARE CENTER FOR TROPICAL CONSERVATION" | agency == "SAVE THE CHILDREN" | agency == "SAVE THE CHILDREN FUND" | agency == "SURGICAL EYE EXPEDITIONS INTERNATIONAL" | agency == "VOLUNTEERS FOR INTERAMERICAN DEVELOPMENT ASSISTANCE VIDA" | agency == "WATERAID" | agency == "WORLD CONCERN" | agency == "WORLD VISION RELIEF AND DEVELOPMENT" | agency == "SURGICAL EYE EXPEDITIONS INTERNATIONAL ENDOWMENT TRUST"	
// Drop high income countries
	tab countryname if INC_GROUP== "H"
	drop if INC_GROUP == "H"

** ***
// Step 3: Allocate to health focus areas -- Thanks to Casey and Elizabeth for the original code (J:\Project\IRH\DAH\RESEARCH\INTEGRATED DATABASES\HEALTH FOCUS AREAS\FGH_2014_ALLOCATING_HFAS.do)
** ***

// Doing a key word search on the detailed grant description, activity description, and grant type description
	
***********
	// a.) keyword searches
***********
	// new keywords		
		do "$j/Project/IRH/DAH/RESEARCH/INTEGRATED DATABASES/HEALTH FOCUS AREAS/Health_ADO_master.ado"
		
		HFA_ado_master description grant_subject_tran activity_override_tran grant_population_tran recip_subject_tran, language(english) channel(US_FOUNDATIONS)
			
	// ado. also does post keyword fixes and calculates weights by health focus area level 1 and level 2
	
	
	// allocate disbursements across all health focus areas using weights
		foreach var of varlist final*frct {
			if "`var'" != "final_total_frct"  { // we do not want to include these umbrella terms
				local healthfocus = subinstr("`var'", "final_", "", .)
				local healthfocus = subinstr("`healthfocus'", "_frct", "", .)
				gen double `healthfocus'_DAH = `var' * amount_split
				}
			}	
			
	// test that it is good
		egen total_DAH = rowtotal(*_DAH)
		gen tester = total_DAH - amount_split
		quietly count if abs(tester) > 50
		if `r(N)' > 0 {
			display in red "we are broke"
			wearebroke
			}
		drop total_DAH tester

save "`INT'/2002_2012_foundation_data_FGH_`report_yr'.dta", replace
