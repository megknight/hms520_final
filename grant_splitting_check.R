######################################################################################
## Author: Ian Cogswell                                                             ##
## Purpose: Test grant_splitting function                                           ## 
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
source(file.path(h, "repos/hms520_final/grant_splitting_function.R"))

## create test datasets 
good_dataset <- data.table(group = c(1, 2, 3),
                           DAH = c(100, 200, 300),
                           recipients = c('Mali,Egypt,Mauritania', 'Mexico,Bolivia,Guatemala,Nicaragua,El Salvador', 'China'))

## run test 
test_that("grants sum to total", {
  expect_equal(sum(grant_splitting(good_dataset, country_col = 'recipients', dah_col = 'DAH', separator = ',')$DAH),
               sum(good_dataset$DAH))
})




