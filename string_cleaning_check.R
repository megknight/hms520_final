######################################################################################
## Author: Megan Knight                                                             ##
## Purpose: Test string_clean function                                              ## 
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
source(file.path(h, "repos/hms520_final/string_cleaning_function.R"))

## create test datasets 
unclean <- data.table(x = 1:2, y = c('(This is one example . of a string with lots, of & & special charäcters)', 'This is another - Ëxample of a string with lÖts of THE special characters'))
clean <- data.table(x = 1:2, y = c('(This is one example . of a string with lots, of & & special charäcters)', 'This is another - Ëxample of a string with lÖts of THE special characters'), upper_y = c(toupper(' This is one example of a string with lots of special characters '), toupper(' This is another example of a string with lots of special characters ')))

## run test 
test_that("Function cleans string vector as expected", {
  expect_equal(string_clean(dataset = unclean, col_to_clean='y'), clean)
})
