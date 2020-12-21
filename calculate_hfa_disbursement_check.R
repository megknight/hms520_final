######################################################################################
## Author: Ian Cogswell                                                             ##
## Purpose: Test calculate_hfa_disbursement function                                ## 
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
library(testthat)
source(file.path(h, "repos/hms520_final/calculate_hfa_disbursement_function.R"))

## create test datasets 
start_dataset <- data.table(group = c(1, 2, 3),
                            DAH = c(100, 200, 300),
                            mal_frct = c(0.2, 0.3, 0.5),
                            hiv_frct = c(0.8, 0.1, 0.1),
                            oid_frct = c(0, 0.6, 0.4),
                            final_total_frct = c(1, 1, 1))
end_dataset <- cbind(start_dataset[, .(group, DAH, final_total_frct, amount_split = DAH)],
                     data.table(mal = c(20, 60, 150),
                                hiv = c(80, 20, 30),
                                oid = c(0, 120, 120)))

## run test 
test_that("HFA catches incorrect DAH total", {
  expect_equal(calculate_hfa_disbursement(good_dataset), end_dataset)
})
