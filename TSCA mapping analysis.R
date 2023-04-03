rm(list = ls())
library(readxl)
library(dplyr)
library(ggplot2)
library(PerformanceAnalytics)

raw=read.csv("data/DemographicImpactsofTRI.csv")

#pull out numeric & character only columns
numcols <- unlist(lapply(raw, is.numeric), use.names = FALSE)
chrcols <- unlist(lapply(raw, is.character), use.names = FALSE)
intcols <- unlist(lapply(raw, is.integer), use.names = FALSE) #n.b int cols count as numeric 


