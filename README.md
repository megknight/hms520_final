## Introduction: 
IHME’s resource tracking team lies at the intersection of economics and global health. As a result, much of the team’s research integrates elements from both of these fields. Economics researchers predominately utilize STATA; however, IHME is actively transitioning away from STATA for a multitude of reasons including cost, speed, and collaboration. The resource tracking team’s flagship project, the development assistance for health (DAH) project, involves many interconnected pipelines with tens of thousands of lines of STATA code. To transition this project out of STATA into R, a concerted effort is necessary. For our final project, we will be working on converting a series of data preparation and processing scripts from one channel’s pipeline into R. 

## Project description: 
As a result of this project, we established a precedent for translating scripts between coding languages by setting a standard for code construction and readability.  We translated 4 STATA scripts from the US Foundations pipeline. This pipeline has raw US foundation project level data as an input. It processes, cleans, and assigns the spending to health focus areas. The following scripts calculate administrative expenses and produce the final datasets which are used in the overall DAH pipeline.

## Scripts in US Foundations pipeline: 
0_DATA_PREP_* (0_DATA_PREP_1992_2002.R; 0_DATA_PREP_2002_2012.R; 0_DATA_PREP_2013_2015): Reads in raw data from Foundation Center for three different year ranges (1992-2002; 2002-2012; 2013-2015) and processes raw data by grant splitting, tagging recipients, and performing keyword search. 

0_COVID_PREP: Reads in COVID-19 specific raw data from Foundation Center and processes raw data by grant splitting, tagging recipients, and performing keyword search.

1_HFA_CLEAN.R: Takes results from 0_DATA_PREP_* to perform post-keyword search cleaning and allocate disbursements across health focus areas using weights.

2_INTPDB_ADBPDB.R: Performs in-kind calculations for US Foundations data. NOTE: This will forecast the predict envelope once implemented in the code per recommendations from the FGH team. Produces final estimates of US Foundations spending for DAH project. 

## Functions in US Foundations pipeline: 
string_cleaning_function.R: Function cleans and standardizes a string column. This is useful for merging applications. (Tested with testthat in string_cleaning_check.R)

grant_splitting_function.R: Function splits grant funding amount evenly among countries list in single column with separator. (Tested with testthat in grant_splitting_check.R)

calculate_hfa_disbursement.R: Function to calculate health focus area disbursements using keyword search output fractions and tests to ensure correct total. (Tested with testthat in calculate_hfa_disbursement_check.R)
