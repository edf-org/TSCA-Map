##############################################################
### Data processing code for the Environmental Defense Fund's
### Chemical Exposure Action Map
###
### Final release, 8/8/2023
### Updated by Paige Varner, 4/9/2024
### by Jeremy Proville and Mary Collins, Environmental Defense Fund (edf.org)
### for more visit https://github.com/proville/TSCA-Map
##############################################################

rm(list = ls())
library(readxl)
library(maps)
library(ggplot2)
library(dplyr)
library(sf)
#library(rgdal)
library(openxlsx)
library(progress)

raw=read.csv("data/DemographicImpactsofTRIv2.csv")
naics=read.xlsx("data/NAICS.xlsx")
weights=read.xlsx("data/TSCA Fenceline Map Chem Hazard Data Extraction_v2.xlsx",sheet=3,startRow = 2)


####################################
#Weights

colnames(weights) <- make.unique(colnames(weights))

weights <- weights %>%
  mutate(across(where(is.character), ~ case_when(
    . == "Carbon Tetrachloride" ~ "Carbon tetrachloride",
    . == "Trichloroethylene (TCE)" ~ "Trichloroethylene",
    . == "Tetrachloroethylene (PCE)" ~ "Tetrachloroethylene",
    . == "Di-ethylhexyl phthalate (DEHP)" ~ "Di(2-ethylhexyl) phthalate",
    . == "1,2-Dibromoethane (ethylene dibromide)" ~ "1,2-Dibromoethane (Ethylene dibromide)",
    . == "1,2-Dichloroethane (ethylene dichloride)" ~ "1,2-Dichloroethane",
    . == "Phthalic anhydride (PA)" ~ "Phthalic anhydride",
    . == "Methylene chloride" ~ "Dichloromethane (Methylene chloride)",
    . == "Cyclic Aliphatic Bromide Cluster (HBCD)" ~ "Hexabromocyclododecane",
    . == "Dibutyl phthalate (DBP)" ~ "Dibutyl phthalate",
    . == "N-Methyl-2-pyrrolidone (NMP)" ~ "N-Methyl-2-pyrrolidone",
    . == "1,1-Dichloroethane" ~ "Ethylidene dichloride (1,1-Dichloroethane)",
    . == "Benzenamine (aniline)" ~ "Aniline",
    . == "4,4′-Methylene bis(2-chloroaniline) (MBOCA)" ~ "4,4'-Methylenebis(2-chloroaniline)",
    TRUE ~ .
  )))

Cancer_weights <- weights[, c(1, 5)]
Cancer_weights <- Cancer_weights[complete.cases(Cancer_weights), ]
Dev_weights <- weights[, c(6, 11)]
Dev_weights <- Dev_weights[complete.cases(Dev_weights), ]
Asthma_weights <- weights[, c(12, 17)]
Asthma_weights <- Asthma_weights[complete.cases(Asthma_weights), ]

####################################
#Calcs for releases across years
raw$PoundsReleased_5yr_min <- apply(raw[, c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")], MARGIN = 1, FUN = min, na.rm = TRUE)

raw$PoundsReleased_5yr_max <- apply(raw[, c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")], MARGIN = 1, FUN = max, na.rm = TRUE)

raw$PoundsReleased_5yr_sum <- apply(raw[, c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")], MARGIN = 1, FUN = sum, na.rm = TRUE)

####################################
#Health outcome calcs
#CANCER chemicals only
Cancer <- c("1,1,2-Trichloroethane", "1,2-Dibromoethane (Ethylene dibromide)", "1,2-Dichloroethane", "1,2-Dichloropropane", "1,3-Butadiene", "1,4-Dichlorobenzene (p-Dichlorobenzene)", "1,4-Dioxane", "1-Bromopropane", "Asbestos (friable)", "Carbon tetrachloride", "Di(2-ethylhexyl) phthalate", "Formaldehyde", "Dichloromethane (Methylene chloride)", "Tetrachloroethylene", "Trichloroethylene", "Tetrabromobisphenol A", "Acetaldehyde", "Acrylonitrile", "Aniline", "Vinyl chloride", "4,4'-Methylenebis(2-chloroaniline)")

raw$Cancer_PoundsReleased_5yr_min <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Cancer, min(as.numeric(row[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")]), na.rm = TRUE), 0)
})
raw$Cancer_PoundsReleased_5yr_max <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Cancer, max(as.numeric(row[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")]), na.rm = TRUE), 0)
})

raw$Cancer_PoundsReleased_5yr_sum <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Cancer, sum(as.numeric(row[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")]), na.rm = TRUE), 0)
})

raw$Cancer_weighted_5yr_max <- apply(raw, MARGIN = 1, FUN = function(x) {
  lbs<-as.numeric(x[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")])
  max_value <- max(lbs, na.rm = TRUE)  # Get the max
  chemical <- x[["Chemical"]]  # Get the corresponding 'Chemical' value 
  weight <- Cancer_weights$Weight[Cancer_weights$Chemical.Name == chemical]  # Lookup the weight based on 'Chemical' value
  result=as.numeric(max_value * weight)
  if (length(result) == 0) {
    result <- 0
  }
  return(result)
})

raw$Cancer_weighted_5yr_sum <- apply(raw, MARGIN = 1, FUN = function(x) {
  lbs<-as.numeric(x[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")])
  sum_value <- sum(lbs, na.rm = TRUE)  # Get the sum
  chemical <- x[["Chemical"]]  # Get the corresponding 'Chemical' value 
  weight <- Cancer_weights$Weight[Cancer_weights$Chemical.Name == chemical]  # Lookup the weight based on 'Chemical' value
  result=as.numeric(sum_value * weight)
  if (length(result) == 0) {
    result <- 0
  }
  return(result)
})


#DEV chemicals only
Dev <- c("1,2-Dichloroethane", "1,2-Dibromoethane (Ethylene dibromide)", "1,2-Dichloropropane", "1,3-Butadiene", "1,4-Dioxane", "1-Bromopropane", "Dibutyl phthalate", "Di(2-ethylhexyl) phthalate", "N-Methyl-2-pyrrolidone", "Tetrachloroethylene", "Trichloroethylene", "Hexabromocyclododecane", "Acrylonitrile", "Vinyl chloride")

raw$Dev_PoundsReleased_5yr_min <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Dev, min(as.numeric(row[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")]), na.rm = TRUE), 0)
})

raw$Dev_PoundsReleased_5yr_max <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Dev, max(as.numeric(row[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")]), na.rm = TRUE), 0)
})

raw$Dev_PoundsReleased_5yr_sum <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Dev, sum(as.numeric(row[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")]), na.rm = TRUE), 0)
})

raw$Dev_weighted_5yr_max <- apply(raw, MARGIN = 1, FUN = function(x) {
  lbs <- as.numeric(x[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")])
  max_value <- max(lbs, na.rm = TRUE)
  chemical <- x[["Chemical"]]
  weight <- Dev_weights$Weight[Dev_weights$Chemical.Name == chemical]
  result <- as.numeric(max_value * weight)
  if (length(result) == 0) {
    result <- 0
  }
  return(result)
})

raw$Dev_weighted_5yr_sum <- apply(raw, MARGIN = 1, FUN = function(x) {
  lbs <- as.numeric(x[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")])
  sum_value <- sum(lbs, na.rm = TRUE)
  chemical <- x[["Chemical"]]
  weight <- Dev_weights$Weight[Dev_weights$Chemical.Name == chemical]
  result <- as.numeric(sum_value * weight)
  if (length(result) == 0) {
    result <- 0
  }
  return(result)
})


#ASTHMA chemicals only
Asthma <- c("1,2-Dibromoethane (Ethylene dibromide)", "Formaldehyde", "Phthalic anhydride", "Acetaldehyde")

raw$Asthma_PoundsReleased_5yr_min <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Asthma, min(as.numeric(row[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")]), na.rm = TRUE), 0)
})

raw$Asthma_PoundsReleased_5yr_max <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Asthma, max(as.numeric(row[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")]), na.rm = TRUE), 0)
})

raw$Asthma_PoundsReleased_5yr_sum <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Asthma, sum(as.numeric(row[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")]), na.rm = TRUE), 0)
})

raw$Asthma_weighted_5yr_max <- apply(raw, MARGIN = 1, FUN = function(x) {
  lbs <- as.numeric(x[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")])
  max_value <- max(lbs, na.rm = TRUE)
  chemical <- x[["Chemical"]]
  weight <- Asthma_weights$Weight[Asthma_weights$Chemical.Name == chemical]
  result <- as.numeric(max_value * weight)
  if (length(result) == 0) {
    result <- 0
  }
  return(result)
})

raw$Asthma_weighted_5yr_sum <- apply(raw, MARGIN = 1, FUN = function(x) {
  lbs <- as.numeric(x[c("PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020", "PoundsReleased_2021", "PoundsReleased_2022")])
  sum_value <- sum(lbs, na.rm = TRUE)
  chemical <- x[["Chemical"]]
  weight <- Asthma_weights$Weight[Asthma_weights$Chemical.Name == chemical]
  result <- as.numeric(sum_value * weight)
  if (length(result) == 0) {
    result <- 0
  }
  return(result)
})



####################################
#Collapsing data to single facility per row
raw_collapsed <- raw %>%
  group_by(FacilityID) %>%
  summarise(across(PoundsReleased_5yr_min, min, na.rm = TRUE),
            across(PoundsReleased_5yr_max, max, na.rm = TRUE),
            across(PoundsReleased_5yr_sum, sum, na.rm = TRUE), 
            across(Cancer_PoundsReleased_5yr_min, min, na.rm = TRUE),
            across(Cancer_PoundsReleased_5yr_max, max, na.rm = TRUE),
            across(Cancer_PoundsReleased_5yr_sum, sum, na.rm = TRUE), 
            across(Dev_PoundsReleased_5yr_min, min, na.rm = TRUE),
            across(Dev_PoundsReleased_5yr_max, max, na.rm = TRUE),
            across(Dev_PoundsReleased_5yr_sum, sum, na.rm = TRUE), 
            across(Asthma_PoundsReleased_5yr_min, min, na.rm = TRUE),
            across(Asthma_PoundsReleased_5yr_max, max, na.rm = TRUE),
            across(Asthma_PoundsReleased_5yr_sum, sum, na.rm = TRUE),
            #across(Cancer_weighted_5yr_sum, sum, na.rm = TRUE),
            #across(Dev_weighted_5yr_sum, sum, na.rm = TRUE),
            #across(Asthma_weighted_5yr_sum, sum, na.rm = TRUE),
            Chemical = toString(unique(Chemical)),
            across(everything(), ~ if(is.numeric(.)) max(., na.rm = TRUE) else first(.)))


#Renaming some mismatched demographic columns
raw_collapsed <- raw_collapsed %>%
  rename(housing_units_county = housing_unitsE_county, avg_median_income_county = medincomeE_county, avg_median_house_value_county = median_house_valueE_county, housing_units_10km = housing_unitsE_10km, avg_median_income_10km = medincomeE_10km, avg_median_house_value_10km = median_house_valueE_10km, population_10km = populationE_10km, population_county = populationE_county)

####################################
#Spatial buffer calcs

# Convert 'raw_collapsed' data frame to an sf object
raw_collapsed_sf <- st_as_sf(raw_collapsed, coords = c("Longitude", "Latitude"), crs = st_crs(4326),remove=FALSE)

raw_collapsed_sf$`10km_Pounds_sum`=0
raw_collapsed_sf$`10km_Pounds_min`=0
raw_collapsed_sf$`10km_Pounds_max`=0
raw_collapsed_sf$`10km_Cancer_Pounds_sum`=0
raw_collapsed_sf$`10km_Cancer_Pounds_min`=0
raw_collapsed_sf$`10km_Cancer_Pounds_max`=0
raw_collapsed_sf$`10km_Dev_Pounds_sum`=0
raw_collapsed_sf$`10km_Dev_Pounds_min`=0
raw_collapsed_sf$`10km_Dev_Pounds_max`=0
raw_collapsed_sf$`10km_Asthma_Pounds_sum`=0
raw_collapsed_sf$`10km_Asthma_Pounds_min`=0
raw_collapsed_sf$`10km_Asthma_Pounds_max`=0

raw_collapsed_sf <- raw_collapsed_sf %>%
  mutate(`10km_facnum` = lengths(st_within(st_geometry(.), st_buffer(st_geometry(.), dist = 10000))))

#Init progress bar for buffer spatial calcs
n_rows <- nrow(raw_collapsed_sf)
progress_bar <- txtProgressBar(min = 0, max = n_rows, style = 3)

points_within_radius=0

#All facility buffer calcs
for (i in seq_len(n_rows)) {
  geom <- st_geometry(raw_collapsed_sf)[i]
  buffer <- st_buffer(geom, dist = 10000)
  distances <- st_distance(raw_collapsed_sf, buffer)
  points_within_radius <- raw_collapsed_sf[as.numeric(distances) <= 10000, ]
  sum_sum <- sum(points_within_radius$PoundsReleased_5yr_sum, na.rm = TRUE)
  sum_min <- sum(points_within_radius$PoundsReleased_5yr_min, na.rm = TRUE)
  sum_max <- sum(points_within_radius$PoundsReleased_5yr_max, na.rm = TRUE)
  raw_collapsed_sf$`10km_Pounds_sum`[i] <- sum_sum
  raw_collapsed_sf$`10km_Pounds_min`[i] <- sum_min
  raw_collapsed_sf$`10km_Pounds_max`[i] <- sum_max
  setTxtProgressBar(progress_bar, i)
}

#Cancer risk buffer calcs
for (i in seq_len(n_rows)) {
  geom <- st_geometry(raw_collapsed_sf)[i]
  buffer <- st_buffer(geom, dist = 10000)
  distances <- st_distance(raw_collapsed_sf, buffer)
  points_within_radius <- raw_collapsed_sf[as.numeric(distances) <= 10000, ]
  sum_sum <- sum(points_within_radius$Cancer_PoundsReleased_5yr_sum, na.rm = TRUE)
  sum_min <- sum(points_within_radius$Cancer_PoundsReleased_5yr_min, na.rm = TRUE)
  sum_max <- sum(points_within_radius$Cancer_PoundsReleased_5yr_max, na.rm = TRUE)
  raw_collapsed_sf$`10km_Cancer_Pounds_sum`[i] <- sum_sum
  raw_collapsed_sf$`10km_Cancer_Pounds_min`[i] <- sum_min
  raw_collapsed_sf$`10km_Cancer_Pounds_max`[i] <- sum_max
  setTxtProgressBar(progress_bar, i)
}

#Dev risk buffer calcs
for (i in seq_len(n_rows)) {
  geom <- st_geometry(raw_collapsed_sf)[i]
  buffer <- st_buffer(geom, dist = 10000)
  distances <- st_distance(raw_collapsed_sf, buffer)
  points_within_radius <- raw_collapsed_sf[as.numeric(distances) <= 10000, ]
  sum_sum <- sum(points_within_radius$Dev_PoundsReleased_5yr_sum, na.rm = TRUE)
  sum_min <- sum(points_within_radius$Dev_PoundsReleased_5yr_min, na.rm = TRUE)
  sum_max <- sum(points_within_radius$Dev_PoundsReleased_5yr_max, na.rm = TRUE)
  raw_collapsed_sf$`10km_Dev_Pounds_sum`[i] <- sum_sum
  raw_collapsed_sf$`10km_Dev_Pounds_min`[i] <- sum_min
  raw_collapsed_sf$`10km_Dev_Pounds_max`[i] <- sum_max
  setTxtProgressBar(progress_bar, i)
}

#Asthma risk buffer calcs
for (i in seq_len(n_rows)) {
  geom <- st_geometry(raw_collapsed_sf)[i]
  buffer <- st_buffer(geom, dist = 10000)
  distances <- st_distance(raw_collapsed_sf, buffer)
  points_within_radius <- raw_collapsed_sf[as.numeric(distances) <= 10000, ]
  sum_sum <- sum(points_within_radius$Asthma_PoundsReleased_5yr_sum, na.rm = TRUE)
  sum_min <- sum(points_within_radius$Asthma_PoundsReleased_5yr_min, na.rm = TRUE)
  sum_max <- sum(points_within_radius$Asthma_PoundsReleased_5yr_max, na.rm = TRUE)
  raw_collapsed_sf$`10km_Asthma_Pounds_sum`[i] <- sum_sum
  raw_collapsed_sf$`10km_Asthma_Pounds_min`[i] <- sum_min
  raw_collapsed_sf$`10km_Asthma_Pounds_max`[i] <- sum_max
  setTxtProgressBar(progress_bar, i)
}

close(progress_bar)

raw_collapsed_sf$'10km_facnum'=raw_collapsed_sf$'10km_facnum'-1
raw_collapsed=raw_collapsed_sf


#Adding NAICS descriptions 
raw_collapsed <- raw_collapsed %>%
  left_join(naics, by = c("ModeledNAICS" = "NAICS"))
raw_collapsed <- raw_collapsed %>%
  rename(NAICS = '2022.NAICS.US.Title')

####################################
#Demographic calcs 
demovars <- c("WhtPercent", "NWPercent","HispPercent", "BlkPercent", "AsianPercent", "AmerIndPercent", "Under5Percent","ReprodFemPercent", "Over64Percent","EduPercent","housing_units","VacPercent","OwnOccPercent","avg_median_income","avg_median_house_value")

# Loop through demos and create new columns 
for (v in demovars) {
  new_col <- paste0(v, "_change")
  raw_collapsed[[new_col]] <- (raw_collapsed[[paste0(v, "_10km")]] - raw_collapsed[[paste0(v, "_county")]]) / raw_collapsed[[paste0(v, "_county")]] * 100
}


#Creating percentile rank vars
raw_collapsed <- raw_collapsed %>%
  mutate(Pounds_5yr_perc = percent_rank(PoundsReleased_5yr_max) * 100) 
raw_collapsed <- raw_collapsed %>%
  mutate(Cancer_Pounds_5yr_perc = percent_rank(Cancer_PoundsReleased_5yr_max) * 100) 
raw_collapsed <- raw_collapsed %>%
  mutate(Dev_Pounds_5yr_perc = percent_rank(Dev_PoundsReleased_5yr_max) * 100) 
raw_collapsed <- raw_collapsed %>%
  mutate(Asthma_Pounds_5yr_perc = percent_rank(Asthma_PoundsReleased_5yr_max) * 100) 

#Calculating number of health risks facility contributes to
raw_collapsed$Health_Risk_Count <- 0
for (i in 1:nrow(raw_collapsed)) {
  if (raw_collapsed$Cancer_PoundsReleased_5yr_sum[i] > 0)
    raw_collapsed$Health_Risk_Count[i] <- raw_collapsed$Health_Risk_Count[i] + 1
  
  if (raw_collapsed$Dev_PoundsReleased_5yr_sum[i] > 0)
    raw_collapsed$Health_Risk_Count[i] <- raw_collapsed$Health_Risk_Count[i] + 1
  
  if (raw_collapsed$Asthma_PoundsReleased_5yr_sum[i] > 0)
    raw_collapsed$Health_Risk_Count[i] <- raw_collapsed$Health_Risk_Count[i] + 1
}

####################################
#District & State Summary Info

#download 119th congressional district shapefile (2024 = 119th) and add to raw data
districts <- congressional_districts(cb = TRUE, year = 2024)
raw_sf <- raw %>%
  st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326)  # WGS84
districts <- st_transform(districts, crs = 4326)
raw_districts <- st_join(raw_sf, districts, join = st_within)

#State and district summary info 
state_summary <- raw_districts %>%
  mutate(total_release = PoundsReleased_2018 + PoundsReleased_2019 +
           PoundsReleased_2020 + PoundsReleased_2021 +
           PoundsReleased_2022) %>%
  group_by(State) %>%
  summarise(
    state_num_facilities = n_distinct(FacilityID),
    state_num_chemicals = n_distinct(Chemical),
    state_sum_releases = sum(total_release, na.rm = TRUE)
  ) %>%
  mutate(
    state_avg_release_per_facility = state_sum_releases / state_num_facilities
  )


district_summary <- raw_districts %>%
  mutate(total_release = PoundsReleased_2018 + PoundsReleased_2019 +
           PoundsReleased_2020 + PoundsReleased_2021 +
           PoundsReleased_2022) %>%
  group_by(GEOID) %>%
  summarise(
    district_num_facilities = n_distinct(FacilityID),
    district_num_chemicals = n_distinct(Chemical),
    district_sum_releases = sum(total_release, na.rm = TRUE)
  ) %>%
  mutate(
    district_avg_release_per_facility = district_sum_releases / district_num_facilities
  )

#Add district info to raw_collapsed to add summary data back in
raw_collapsed_sf <- raw_collapsed %>%
  st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326)  # WGS84
districts <- st_transform(districts, crs = 4326)
raw_collapsed_districts <- st_join(raw_collapsed_sf, districts, join = st_within)

#Adding summary info to original data
raw_collapsed_districts <- raw_collapsed_districts %>%
  st_drop_geometry() %>%
  left_join(state_summary, by = "State") %>%
  bind_cols(st_geometry(raw_collapsed_districts)) %>%
  st_as_sf()

raw_collapsed_districts <-raw_collapsed_districts %>%
  st_drop_geometry() %>%
  left_join(district_summary, by = "GEOID") %>%
  bind_cols(st_geometry(raw_collapsed_districts)) %>%
  st_as_sf()

####################################
#Cleanup & Export 
colnames(raw_collapsed_districts)

final= raw_collapsed_districts %>% select(FacilityID,FacilityName,Street,City,County,State,ZIPCode,GEOID,NAMELSAD,Longitude,Latitude,Chemical,PoundsReleased_2018,PoundsReleased_2019,PoundsReleased_2020,PoundsReleased_2021,PoundsReleased_2022,PoundsReleased_5yr_min,PoundsReleased_5yr_sum,PoundsReleased_5yr_max,Pounds_5yr_perc,Cancer_PoundsReleased_5yr_min,Cancer_PoundsReleased_5yr_sum,Cancer_PoundsReleased_5yr_max,Cancer_Pounds_5yr_perc,Cancer_weighted_5yr_sum,Dev_PoundsReleased_5yr_min,Dev_PoundsReleased_5yr_sum,Dev_PoundsReleased_5yr_max,Dev_Pounds_5yr_perc,Dev_weighted_5yr_sum,Asthma_PoundsReleased_5yr_min,Asthma_PoundsReleased_5yr_sum,Asthma_PoundsReleased_5yr_max,Asthma_Pounds_5yr_perc,Asthma_weighted_5yr_sum,state_num_facilities,state_num_chemicals,state_sum_releases,state_avg_release_per_facility,district_num_facilities,district_num_chemicals,district_sum_releases,district_avg_release_per_facility,population_10km,WhtPercent_10km,NWPercent_10km,HispPercent_10km,BlkPercent_10km,AsianPercent_10km,AmerIndPercent_10km,Under5Percent_10km,ReprodFemPercent_10km,Over64Percent_10km,EduPercent_10km,housing_units_10km,VacPercent_10km,OwnOccPercent_10km,avg_median_income_10km,avg_median_house_value_10km,population_county,WhtPercent_county,NWPercent_county,HispPercent_county,BlkPercent_county,AsianPercent_county,AmerIndPercent_county,Under5Percent_county,ReprodFemPercent_county,Over64Percent_county,EduPercent_county,housing_units_county,VacPercent_county,OwnOccPercent_county,avg_median_income_county,avg_median_house_value_county,WhtPercent_change,NWPercent_change,HispPercent_change,BlkPercent_change,AsianPercent_change,AmerIndPercent_change,Under5Percent_change,ReprodFemPercent_change,Over64Percent_change,EduPercent_change,NAICS,'10km_Pounds_sum','10km_Pounds_min','10km_Pounds_max','10km_Cancer_Pounds_sum','10km_Cancer_Pounds_min','10km_Cancer_Pounds_max','10km_Dev_Pounds_sum','10km_Dev_Pounds_min','10km_Dev_Pounds_max','10km_Asthma_Pounds_sum','10km_Asthma_Pounds_min','10km_Asthma_Pounds_max','10km_facnum', Health_Risk_Count)
names(final)[names(final) == "NAMELSAD"] = "District"

#Export table
write.xlsx(st_drop_geometry(final), file = "data/TSCA_merged_dist.xlsx", rowNames = FALSE)

#Export shapefile
gdb_path <- "~/TSCA/Fenceline Map/TSCA-Map/TSCA_facilities_dist.gpkg"
st_write(final, gdb_path, driver = "GPKG", layer_options = "OVERWRITE=yes",append=FALSE)



###################################################################
#QC code
####################################
# Create a map of the United States
map_data <- map_data("state")

us_map <- ggplot(map_data, aes(x=long, y=lat)) +
  geom_polygon(aes(group=group), fill="white", color="black")

# Add points from 'raw' data frame to the map
us_map <- us_map + geom_point(data=raw, aes(x=Longitude, y=Latitude))

# Display the map with points
us_map

# Set fixed size and aspect ratio for map
map_size <- theme(
  plot.background = element_rect(fill = "white"),
  plot.margin = margin(10, 10, 10, 10),
  plot.title = element_text(hjust = 0.5),
  axis.line = element_blank(),
  axis.text = element_blank(),
  axis.ticks = element_blank(),
  axis.title = element_blank(),
  panel.grid = element_blank(),
  panel.border = element_blank(),
  panel.background = element_blank()
)

# Loop through numeric columns and add points to the map, colored by column
for (col in names(raw)[sapply(raw, is.numeric)]) {
  us_map <- ggplot(map_data, aes(x=long, y=lat)) +
    geom_polygon(aes(group=group), fill="white", color="black") +
    geom_point(data=raw, aes(x=Longitude, y=Latitude, color=.data[[col]])) +
    scale_color_gradient(low = "yellow", high = "red") +
    theme(legend.position = "bottom") +
    labs(title = paste("Map of", col)) +
    map_size
  print(us_map)
}

#filtering/QC
test2 = final %>% 
  filter(FacilityID == "01041HZNPPTHIRD") %>% select(everything())

#testing weighting functions
test = raw %>% select(FacilityID,Chemical,PoundsReleased_5yr_min,PoundsReleased_5yr_min,PoundsReleased_5yr_sum,Cancer_PoundsReleased_5yr_sum,Cancer_weighted_5yr_sum,Dev_weighted_5yr_sum,Asthma_weighted_5yr_sum)