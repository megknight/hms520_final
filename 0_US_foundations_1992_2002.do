**********************************************************
// Author: Casey Graves
// Date: 9/12/2014
// Purpose: Estimating US Foundation DAH using new grant-level data from the Foundation Center
// do "J:\Project\IRH\DAH\RESEARCH\CHANNELS\6_FOUNDATIONS\2_US_FOUNDATIONS\CODE\1_US_FOUND_PD_CREATE_FGH2014.do"
**********************************************************

clear all
set more off
set scheme s1color
global j "J:" 

	local report_yr = 2020			// FGH report year
	local abrv_yr = 20				// abbreviated FGH report year

	cd 				"$j\Project\IRH\DAH\RESEARCH"	
	local RAW 		".\CHANNELS\6_FOUNDATIONS\2_US_FOUNDATIONS\DATA\RAW\FGH_2014"
	local INT 		".\CHANNELS\6_FOUNDATIONS\2_US_FOUNDATIONS\DATA\INT"
	local FIN 		".\CHANNELS\6_FOUNDATIONS\2_US_FOUNDATIONS\DATA\FIN"
	local CODES		".\INTEGRATED DATABASES\COUNTRY FEATURES"
	
** ***
// Step 1: Import grant-level data from the Foundation Center (new as of FGH 2014)
** ***
	foreach year in "1_INTL_1992_1998" "2_INTL_1999_2002_1 of 2" "2_INTL_2003_2005_2 of 2" "3_INTL_2006_2009_1 of 2" "3_INTL_2010_2012_2 of 2" {
		di as red "Importing file: `year'"
		import excel using "`RAW'\Batch `year'.xlsx", firstrow clear
		tempfile data_`year'
		save `data_`year''
		}
		
	use `data_1_INTL_1992_1998', clear
	foreach year in "2_INTL_1999_2002_1 of 2" "2_INTL_2003_2005_2 of 2" "3_INTL_2006_2009_1 of 2" "3_INTL_2010_2012_2 of 2" {
		append using `data_`year'', force
		}
	
// keep only health projects
	keep if primary_code == "E"

** ***
// Step 2: Splitting disbursements among the list recipient countries (often the country_tran variable will list two or more countries, so we will want to split the grant amount evenly between them).
** ***
	
// clean recipient country
	//replace country_tran = "Global programs" if country_tran == "Global programs; Developing countries"
	//replace country_tran = subinstr(country_tran, "Global programs; Developing countries", "Global programs", .)
	replace country_tran=location if country_tran==""&length(location)!=2
	split country_tran, p(;)
	
	// split up grant amount among all recipient countries (some grants have up to 10 recipients listed)
	rename country_tran recipient
	reshape long country_tran, i(grant_key) j(recipient_country)
	drop if country_tran=="" & recipient!=""
	
	bysort grant_key: gen n= _n
	bysort grant_key: gen N= _N
	gen double amount_split = amount/N
	
	// merge in recipient country isocode
	rename country_tran country_lc
	replace country_lc = trim(country_lc) 

	// Clean some names before merging 
	replace country_lc = "Bosnia Herzegovina" if country_lc=="Bosnia-Herzegovina"
	replace country_lc = "Congo, the Democratic Republic of the" if country_lc=="Congo, Democratic Republic of the"
	replace country_lc = "United Kingdom, England and Wales" if country_lc=="England"
	replace country_lc = "United Kingdom, England and Wales" if country_lc=="Wales"
	replace country_lc = "Georgia" if country_lc=="Georgia (Republic of)"
	replace country_lc = "Myanmar" if country_lc=="Myanmar (Burma)"
	replace country_lc = "Union of Soviet Socialist Republics" if country_lc=="Soviet Union"
	replace country_lc = "Union of Soviet Socialist Republics" if country_lc=="Soviet Union (Former)"
	replace country_lc = "Republic of Yemen" if country_lc=="Yemen Arab Republic"
	replace country_lc = "West Bank and Gaza" if country_lc=="West Bank/Gaza (Palestinian Territories)"
	replace country_lc = "West Bank and Gaza" if country_lc=="West Bank/Gaza"

	merge m:1 country_lc using "`CODES'\countrycodes_official_`report_yr'.dta", keepusing(countryname_ihme iso3)
	keep if _m==1 | _m==3
	drop _m
	
// merge in income groups
	rename iso3 ISO3_RC
	rename yr_issued YEAR
	
// Fill in ISO3_RC codes for regions and country names that didn't match
	
	// Regions
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
	replace ISO3_RC = "COD" if country_lc == "Zaire" 
	replace ISO3_RC = "GRB" if country_lc == "Northern Ireland"
	replace ISO3_RC = "PSE" if country_lc == "East Jerusalem"
	replace ISO3_RC = "KOS" if country_lc == "Kosovo"
	replace ISO3_RC = "GBR" if country_lc == "United Kingdom, England and Wales" | country_lc=="Scotland" | country_lc == "Northern Ireland"
	
	merge m:1 ISO3_RC YEAR using "`CODES'\wb_historical_incgrps_`abrv_yr'.dta", keepusing(INC_GROUP)
	keep if _m==1 | _m==3
	drop _m

** ***
// Step 3: Tagging transfers from foundations to channels we already track (UN Agencies and NGOs).
** ***
	
// drop BMGF (we track them separately)
	drop if gm_key == "GATE023"
	
// Tagging transfers to other foundations

	preserve
	keep name 
	duplicates drop
	keep if regexm(name, "Foundation")
	rename name gm_name
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

	replace ELIM_CH = 1 if regexm(name, "Pan American Health Organization")
		replace CHANNEL = "PAHO" if regexm(name, "Pan American Health Organization")
	// If UNDP is added as a channel:
		//replace ELIM_CH = 1 if regexm(name, "United Nations Development Programme")
		//replace CHANNEL = "UNDP" if regexm(name, "United Nations Development Programme")
	replace ELIM_CH = 1 if regexm(name, "United Nations Population Fund")
		replace CHANNEL = "UNFPA" if regexm(name, "United Nations Population Fund")
	replace ELIM_CH = 1 if regexm(name, "United Nations Programme on HIV/AIDS")
		replace CHANNEL = "UNAIDS" if regexm(name, "United Nations Programme on HIV/AIDS")
	replace ELIM_CH = 1 if regexm(name, "World Health Organization")
		replace CHANNEL = "WHO" if regexm(name, "World Health Organization")
	replace ELIM_CH = 1 if regexm(name, "Global Fund to Fight AIDS, Tuberculosis and Malaria")
		replace CHANNEL = "GFATM" if regexm(name, "Global Fund to Fight AIDS, Tuberculosis and Malaria")
	replace ELIM_CH = 1 if regexm(name, "GAVI")
		replace CHANNEL = "GAVI" if regexm(name, "GAVI")
	replace ELIM_CH = 1 if regexm(name, "Inter-American Development Bank")
		replace CHANNEL = "IDB" if regexm(name, "Inter-American Development Bank")
	replace ELIM_CH = 1 if regexm(name, "World Bank")
		replace CHANNEL = "WB" if regexm(name, "World Bank")
	replace ELIM_CH = 1 if regexm(name, "UNICEF")
		replace CHANNEL = "UNICEF" if regexm(name, "UNICEF")
	replace ELIM_CH = 1 if regexm(name, "Wellcome Trust")
		replace CHANNEL = "WELLCOME" if regexm(name, "Wellcome Trust")

	// UNICEF, AfDB, AsDB not in data 

	tempfile temp
	save `temp', replace

// Tagging transfers from foundations to NGOs that we already track

// Agencies
	use "J:\Project\IRH\DAH\RESEARCH\CHANNELS\2_NGO\1_VOLAG\DESCRIPTIVE_VARIABLES\Agency_ID_FF2017.dta", clear // keep for now (new dataset not yet available)
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
	use "J:\Project\IRH\DAH\RESEARCH\CHANNELS\2_NGO\1_VOLAG\DESCRIPTIVE_VARIABLES\Intl_Agency_ID_FF2017.dta", clear // keep for now (new dataset not yet available)
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
	rename name agency
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
	foreach var of varlist description type_tran activity_tran pop_grp_tran {
		gen upper_`var' = upper(`var')
		replace upper_`var' = subinstr(upper_`var', "ÿ", "Y", .)
		replace upper_`var' = subinstr(upper_`var', "Ÿ", "Y", .)

		replace upper_`var' = subinstr(upper_`var', "æ", "AE", .)
		replace upper_`var' = subinstr(upper_`var', "Æ", "AE", .)

		replace upper_`var' = subinstr(upper_`var', "œ", "OE", .)
		replace upper_`var' = subinstr(upper_`var', "Œ", "OE", .) 

		replace upper_`var' = subinstr(upper_`var', "ç", "C", .)
		replace upper_`var' = subinstr(upper_`var', "Ç", "C", .)

		replace upper_`var' = subinstr(upper_`var', "ñ", "N", .)
		replace upper_`var' = subinstr(upper_`var', "Ñ", "N", .)

		replace upper_`var' = subinstr(upper_`var', "ß", "SS", .)
		
		replace upper_`var' = subinstr(upper_`var', "/", " ", .)
		replace upper_`var' = subinstr(upper_`var', ":", " ", .)
		replace upper_`var' = subinstr(upper_`var', ";", " ", .)
		replace upper_`var' = subinstr(upper_`var', "-", " ", .)
		}

	// Add blank space to beginning and end of each description
	foreach var of varlist upper_* {
		replace `var'= " " + `var' + " "
		}

	foreach var of varlist description type_tran activity_tran pop_grp_tran {
		foreach letter in á Á à À ã Ã â Â å Å ä Ä {
			replace upper_`var' = subinstr(upper_`var', "`letter'", "A", .)
			}
		}

	foreach var of varlist description type_tran activity_tran pop_grp_tran {
		foreach letter in é É ê Ê è È ë Ë {
			replace upper_`var' = subinstr(upper_`var', "`letter'", "E", .)
			}
		}

	foreach var of varlist description type_tran activity_tran pop_grp_tran {
		foreach letter in í Í ì Ì î Î ï Ï {
			replace upper_`var' = subinstr(upper_`var', "`letter'", "I", .)
			}
		}

	foreach var of varlist description type_tran activity_tran pop_grp_tran { 
		foreach letter in ó Ó ò Ò õ Õ ô Ô ø Ø ö Ö {
			replace upper_`var' = subinstr(upper_`var', "`letter'", "O", .)
			}
		}

	foreach var of varlist description type_tran activity_tran pop_grp_tran {
		foreach letter in ú Ú ù Ù û Û ü Ü {
			replace upper_`var' = subinstr(upper_`var', "`letter'", "U", .)
			}
		}
	
	***********
	// a.) keyword searches
	***********
	// new keywords		
		do "J:/Project/IRH/DAH/RESEARCH/INTEGRATED DATABASES/HEALTH FOCUS AREAS/Health_ADO_master.ado"
		HFA_ado_master upper_description upper_activity_tran upper_type_tran upper_pop_grp_tran, language(english) channel(US_FOUNDATIONS)
		
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
				
	save "`INT'/1992_2012_foundation_data_FGH_`report_yr'.dta", replace

