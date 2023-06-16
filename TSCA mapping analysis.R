rm(list = ls())
library(readxl)
library(maps)
library(ggplot2)
library(dplyr)
library(sf)
library(rgdal)
library(openxlsx)
library(progress)

raw=read.csv("data/DemographicImpactsofTRI.csv")
naics=read.xlsx("data/NAICS.xlsx")
weights=read.xlsx("data/TSCA Fenceline Map Chem Hazard Data Extraction.xlsx",sheet=3,startRow = 2)


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
    TRUE ~ .
  )))

Cancer_weights <- weights[, c(1, 5)]
Cancer_weights <- Cancer_weights[complete.cases(Cancer_weights), ]
DevNeu_weights <- weights[, c(6, 9)]
DevNeu_weights <- DevNeu_weights[complete.cases(DevNeu_weights), ]
Asthma_weights <- weights[, c(10, 15)]
Asthma_weights <- Asthma_weights[complete.cases(Asthma_weights), ]

####################################
#Calcs for releases across years
raw$PoundsReleased_5yr_min <- apply(raw[, c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")], MARGIN = 1, FUN = min, na.rm = TRUE)

raw$PoundsReleased_5yr_max <- apply(raw[, c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")], MARGIN = 1, FUN = max, na.rm = TRUE)

#Sum field needs to be the max value across all 5 years, but then summed later across chemicals (hence the different field name)
raw$PoundsReleased_5yr_sum <- apply(raw[, c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")], MARGIN = 1, FUN = max, na.rm = TRUE)

####################################
#Health outcome calcs
#CANCER chemicals only
Cancer <- c("1,1,2-Trichloroethane", "1,2-Dibromoethane (Ethylene dibromide)", "1,2-Dichloroethane", "1,2-Dichloropropane", "1,3-Butadiene", "1,4-Dichlorobenzene (p-Dichlorobenzene)", "1,4-Dioxane", "1-Bromopropane", "Asbestos (friable)", "Carbon tetrachloride", "Di(2-ethylhexyl) phthalate", "Formaldehyde", "Dichloromethane (Methylene chloride)", "Tetrachloroethylene", "Trichloroethylene")

raw$Cancer_PoundsReleased_5yr_min <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Cancer, min(as.numeric(row[c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")]), na.rm = TRUE), 0)
})
raw$Cancer_PoundsReleased_5yr_max <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Cancer, max(as.numeric(row[c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")]), na.rm = TRUE), 0)
})

raw$Cancer_PoundsReleased_5yr_sum <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Cancer, max(as.numeric(row[c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")]), na.rm = TRUE), 0)
})

raw$Cancer_weighted_5yr_sum <- apply(raw[, c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")], MARGIN = 1, FUN = function(x) {
  max_value <- max(x, na.rm = TRUE)  # Get the maximum value
  chemical <- raw$Chemical[which.max(x)]  # Get the corresponding 'Chemical' value
  weight <- Cancer_weights$Weight[Cancer_weights$Chemical.Name == chemical]  # Lookup the weight based on 'Chemical' value
  max_value * weight  # Multiply maximum value with weight
})

#DevNeuro chemicals only
DevNeu <- c("1,2-Dichloroethane", "1,2-Dibromoethane (Ethylene dibromide)", "1,2-Dichloropropane", "1,3-Butadiene", "1,4-Dioxane", "1-Bromopropane", "Dibutyl phthalate", "Di(2-ethylhexyl) phthalate", "N-Methyl-2-pyrrolidone", "Tetrachloroethylene", "Trichloroethylene", "Hexabromocyclododecane")

raw$DevNeu_PoundsReleased_5yr_min <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% DevNeu, min(as.numeric(row[c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")]), na.rm = TRUE), 0)
})
raw$DevNeu_PoundsReleased_5yr_max <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% DevNeu, max(as.numeric(row[c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")]), na.rm = TRUE), 0)
})

raw$DevNeu_PoundsReleased_5yr_sum <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% DevNeu, max(as.numeric(row[c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")]), na.rm = TRUE), 0)
})


# raw$DevNeu_weighted_5yr_sum <- apply(raw[, c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")], MARGIN = 1, FUN = function(x) {
#   max_value <- max(x, na.rm = TRUE)  # Get the maximum value
#   chemical <- raw$Chemical[which.max(x)]  # Get the corresponding 'Chemical' value
#   weight <- DevNeu_weights$Weight.1[DevNeu_weights$Chemical.Name.1 == chemical]  # Lookup the weight based on 'Chemical' value
#   max_value * weight  # Multiply maximum value with weight
# })

#Asthma chemicals only
Asthma <- c("1,2-Dichloroethane", "1,2-Dibromoethane (Ethylene dibromide)", "Formaldehyde", "Phthalic anhydride")

raw$Asthma_PoundsReleased_5yr_min <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Asthma, min(as.numeric(row[c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")]), na.rm = TRUE), 0)
})
raw$Asthma_PoundsReleased_5yr_max <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Asthma, max(as.numeric(row[c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")]), na.rm = TRUE), 0)
})

raw$Asthma_PoundsReleased_5yr_sum <- apply(raw, 1, function(row) {
  ifelse(row["Chemical"] %in% Asthma, max(as.numeric(row[c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")]), na.rm = TRUE), 0)
})

# raw$Asthma_weighted_5yr_sum <- apply(raw[, c("PoundsReleased_2016", "PoundsReleased_2017", "PoundsReleased_2018", "PoundsReleased_2019", "PoundsReleased_2020")], MARGIN = 1, FUN = function(x) {
#   max_value <- max(x, na.rm = TRUE)  # Get the maximum value
#   chemical <- raw$Chemical[which.max(x)]  # Get the corresponding 'Chemical' value
#   weight <- Asthma_weights$Weight.2[Asthma_weights$Chemical.Name.2 == chemical]  # Lookup the weight based on 'Chemical' value
#   max_value * weight  # Multiply maximum value with weight
# })

####################################
#Collapsing data to single facility per row
raw_collapsed <- raw %>%
  group_by(FacilityID) %>%
  summarise(across(PoundsReleased_5yr_min, min, na.rm = TRUE), 
            across(PoundsReleased_5yr_sum, sum, na.rm = TRUE), 
            across(Cancer_PoundsReleased_5yr_min, min, na.rm = TRUE), 
            across(Cancer_PoundsReleased_5yr_sum, sum, na.rm = TRUE), 
            across(DevNeu_PoundsReleased_5yr_min, min, na.rm = TRUE), 
            across(DevNeu_PoundsReleased_5yr_sum, sum, na.rm = TRUE), 
            across(Asthma_PoundsReleased_5yr_min, min, na.rm = TRUE), 
            across(Asthma_PoundsReleased_5yr_sum, sum, na.rm = TRUE),
            across(Cancer_weighted_5yr_sum, sum, na.rm = TRUE),
            #across(DevNeu_weighted_5yr_sum, sum, na.rm = TRUE),
            #across(Asthma_weighted_5yr_sum, sum, na.rm = TRUE),
            Chemical = toString(unique(Chemical)),
            across(everything(), ~ if(is.numeric(.)) max(., na.rm = TRUE) else first(.)))


#Renaming some mismatched demographic columns
raw_collapsed <- raw_collapsed %>%
  rename(housing_units_county = housing_unitsE_county, avg_median_income_county = medincomeE_county, avg_median_house_value_county = median_house_valueE_county)

####################################
#Spatial buffer calcs

# Convert 'raw_collapsed' data frame to an sf object
raw_collapsed_sf <- st_as_sf(raw_collapsed, coords = c("Longitude", "Latitude"), crs = st_crs(4326),remove=FALSE)

sum_val = 0
raw_collapsed_sf$`10km_Pounds_sum`=0
raw_collapsed_sf$`10km_Pounds_min`=0
raw_collapsed_sf$`10km_Pounds_max`=0
raw_collapsed_sf$`10km_Cancer_Pounds_sum`=0
raw_collapsed_sf$`10km_Cancer_Pounds_min`=0
raw_collapsed_sf$`10km_Cancer_Pounds_max`=0
raw_collapsed_sf$`10km_DevNeu_Pounds_sum`=0
raw_collapsed_sf$`10km_DevNeu_Pounds_min`=0
raw_collapsed_sf$`10km_DevNeu_Pounds_max`=0
raw_collapsed_sf$`10km_Asthma_Pounds_sum`=0
raw_collapsed_sf$`10km_Asthma_Pounds_min`=0
raw_collapsed_sf$`10km_Asthma_Pounds_max`=0


raw_collapsed_sf <- raw_collapsed_sf %>%
  mutate(`10km_facnum` = lengths(st_within(st_geometry(.), st_buffer(st_geometry(.), dist = 10000))))

#Init progress bar for buffer spatial calcs
n_rows <- nrow(raw_collapsed_sf)
progress_bar <- txtProgressBar(min = 0, max = n_rows, style = 3)

#All facility buffer calcs
for (i in seq_len(n_rows)) {
  geom <- st_geometry(raw_collapsed_sf)[i]
  points_within_radius <- raw_collapsed_sf[unlist(st_within(raw_collapsed_sf, st_buffer(geom, dist = 10000))), ]
  sum_sum <- sum(points_within_radius$PoundsReleased_5yr_sum, na.rm = TRUE)
  sum_min <- sum(points_within_radius$PoundsReleased_5yr_min, na.rm = TRUE)
  sum_max <- sum(points_within_radius$PoundsReleased_5yr_max, na.rm = TRUE)
  raw_collapsed_sf$`10km_Pounds_sum`[i] <- sum_sum
  raw_collapsed_sf$`10km_Pounds_min`[i] <- sum_min
  raw_collapsed_sf$`10km_Pounds_max`[i] <- sum_max
  setTxtProgressBar(progress_bar, i)
}

#Cancer risk buffer calcs
sum_val = 0
for (i in seq_len(n_rows)) {
  geom <- st_geometry(raw_collapsed_sf)[i]
  points_within_radius <- raw_collapsed_sf[unlist(st_within(raw_collapsed_sf, st_buffer(geom, dist = 10000))), ]
  sum_sum <- sum(points_within_radius$Cancer_PoundsReleased_5yr_sum, na.rm = TRUE)
  sum_min <- sum(points_within_radius$Cancer_PoundsReleased_5yr_min, na.rm = TRUE)
  sum_max <- sum(points_within_radius$Cancer_PoundsReleased_5yr_max, na.rm = TRUE)
  raw_collapsed_sf$`10km_Cancer_Pounds_sum`[i] <- sum_sum
  raw_collapsed_sf$`10km_Cancer_Pounds_min`[i] <- sum_min
  raw_collapsed_sf$`10km_Cancer_Pounds_max`[i] <- sum_max
  setTxtProgressBar(progress_bar, i)
}

#DevNeu risk buffer calcs
sum_val = 0
for (i in seq_len(n_rows)) {
  geom <- st_geometry(raw_collapsed_sf)[i]
  points_within_radius <- raw_collapsed_sf[unlist(st_within(raw_collapsed_sf, st_buffer(geom, dist = 10000))), ]
  sum_sum <- sum(points_within_radius$DevNeu_PoundsReleased_5yr_sum, na.rm = TRUE)
  sum_min <- sum(points_within_radius$DevNeu_PoundsReleased_5yr_min, na.rm = TRUE)
  sum_max <- sum(points_within_radius$DevNeu_PoundsReleased_5yr_max, na.rm = TRUE)
  raw_collapsed_sf$`10km_DevNeu_Pounds_sum`[i] <- sum_sum
  raw_collapsed_sf$`10km_DevNeu_Pounds_min`[i] <- sum_min
  raw_collapsed_sf$`10km_DevNeu_Pounds_max`[i] <- sum_max
  setTxtProgressBar(progress_bar, i)
}

#Asthma risk buffer calcs
sum_val = 0
for (i in seq_len(n_rows)) {
  geom <- st_geometry(raw_collapsed_sf)[i]
  points_within_radius <- raw_collapsed_sf[unlist(st_within(raw_collapsed_sf, st_buffer(geom, dist = 10000))), ]
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
  mutate(DevNeu_Pounds_5yr_perc = percent_rank(DevNeu_PoundsReleased_5yr_max) * 100) 
raw_collapsed <- raw_collapsed %>%
  mutate(Asthma_Pounds_5yr_perc = percent_rank(Asthma_PoundsReleased_5yr_max) * 100) 

#Calculating number of health risks facility contributes to
raw_collapsed$Health_Risk_Count <- 0
for (i in 1:nrow(raw_collapsed)) {
  if (raw_collapsed$Cancer_PoundsReleased_5yr_sum[i] > 0)
    raw_collapsed$Health_Risk_Count[i] <- raw_collapsed$Health_Risk_Count[i] + 1
  
  if (raw_collapsed$DevNeu_PoundsReleased_5yr_sum[i] > 0)
    raw_collapsed$Health_Risk_Count[i] <- raw_collapsed$Health_Risk_Count[i] + 1
  
  if (raw_collapsed$Asthma_PoundsReleased_5yr_sum[i] > 0)
    raw_collapsed$Health_Risk_Count[i] <- raw_collapsed$Health_Risk_Count[i] + 1
}


####################################
#Cleanup & Export
final= raw_collapsed %>% select(FacilityID,FacilityName,Street,City,County,State,ZIPCode,FIPS,Longitude,Latitude,Chemical,PoundsReleased_2016,PoundsReleased_2017,PoundsReleased_2018,PoundsReleased_2019,PoundsReleased_2020,PoundsReleased_5yr_min,PoundsReleased_5yr_sum,PoundsReleased_5yr_max,Pounds_5yr_perc,Cancer_PoundsReleased_5yr_min,Cancer_PoundsReleased_5yr_sum,Cancer_PoundsReleased_5yr_max,Cancer_Pounds_5yr_perc,Cancer_weighted_5yr_sum,DevNeu_PoundsReleased_5yr_min,DevNeu_PoundsReleased_5yr_sum,DevNeu_PoundsReleased_5yr_max,DevNeu_Pounds_5yr_perc,DevNeu_weighted_5yr_sum,Asthma_PoundsReleased_5yr_min,Asthma_PoundsReleased_5yr_sum,Asthma_PoundsReleased_5yr_max,Asthma_Pounds_5yr_perc,Asthma_weighted_5yr_sum,Score_2016,Score_2017,Score_2018,Score_2019,Score_2020,Hazard_2016,Hazard_2017,Hazard_2018,Hazard_2019,Hazard_2020,population_10km,WhtPercent_10km,NWPercent_10km,HispPercent_10km,BlkPercent_10km,AsianPercent_10km,AmerIndPercent_10km,Under5Percent_10km,ReprodFemPercent_10km,Over64Percent_10km,EduPercent_10km,housing_units_10km,VacPercent_10km,OwnOccPercent_10km,avg_median_income_10km,avg_median_house_value_10km,populationE_county,WhtPercent_county,NWPercent_county,HispPercent_county,BlkPercent_county,AsianPercent_county,AmerIndPercent_county,Under5Percent_county,ReprodFemPercent_county,Over64Percent_county,EduPercent_county,housing_units_county,VacPercent_county,OwnOccPercent_county,avg_median_income_county,avg_median_house_value_county,WhtPercent_change,NWPercent_change,HispPercent_change,BlkPercent_change,AsianPercent_change,AmerIndPercent_change,Under5Percent_change,ReprodFemPercent_change,Over64Percent_change,EduPercent_change,NAICS,'10km_Pounds_sum','10km_Pounds_min','10km_Pounds_max','10km_Cancer_Pounds_sum','10km_Cancer_Pounds_min','10km_Cancer_Pounds_max','10km_DevNeu_Pounds_sum','10km_DevNeu_Pounds_min','10km_DevNeu_Pounds_max','10km_Asthma_Pounds_sum','10km_Asthma_Pounds_min','10km_Asthma_Pounds_max',Health_Risk_Count)

#Export table
write.xlsx(st_drop_geometry(final), file = "data/TSCA_merged.xlsx", rowNames = FALSE)

#Export shapefile
gdb_path <- "Z:/OCE Dropbox/Jeremy Proville/EDF/TSCA Mapping/TSCA Platform/TSCA_facilities.gpkg"
st_write(final, gdb_path, driver = "GPKG", layer_options = "OVERWRITE=yes",append=FALSE)

###################################################################
#QC & Old code
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
  #export to new exports folder when ready
}

######CVI
# read in shapefile
tracts <- st_read("Z:/OCE Dropbox/Jeremy Proville/EDF/Climate Health Vulnerability Index - GIS/Climate Vulnerability Index/QGIS database/2010 Tracts/2010tracts.shp")

# read in csv file
cvi_tsca <- read.csv("data/CVI_TSCA.csv", colClasses = c(FIPS = "character"))
library(stringr)
cvi_tsca$FIPS <- str_pad(cvi_tsca$FIPS, width = 11, side = "left", pad = "0")


# join data frames based on FIPS field
tracts_cvi <- left_join(tracts, cvi_tsca, by = c("GEOID10" = "FIPS"))
st_write(tracts_cvi, "data/TSCA_CVI.shp", driver = "ESRI Shapefile", quiet=FALSE)

# check output
head(tracts_cvi)


#filtering/QC
test2 = raw %>% 
  filter(FacilityID == "01028SDDKR82DEE") %>% select(everything())


# Count rows with 0 value in Hazard
# and >0 value in Poundsreleased
raw_collapsed %>% 
  filter(PoundsReleased_5yr_sum > 0) %>% 
  summarize(num_rows = sum(Hazard_2016 == 0 & Hazard_2017 == 0 & Hazard_2018 == 0 & Hazard_2019 == 0 & Hazard_2020 == 0))


raw_collapsed %>% 
  filter(PoundsReleased_5yr_sum > 0) %>% 
  summarize(num_rows = sum(Score_2016 == 0 & Score_2017 == 0 & Score_2018 == 0 & Score_2019 == 0 & Score_2020 == 0))




# Create a map of the United States
us_map <- ggplot() +
  geom_polygon(data = map_data("state"), aes(x = long, y = lat, group = group), fill = "white", color = "black")

# Add points from 'final' data frame to the map, colored by '10km_facnum'
us_map <- us_map +
  geom_point(data = raw_collapsed_sf, aes(x = Longitude, y = Latitude, color = `10km_pounds_sum`)) +
  scale_color_gradient(low = "blue", high = "red") +
  labs(title = "Points Colored by '10km_pounds_sum'") +
  theme_minimal()

# Display the map
print(us_map)


# raw=format(raw,scientific=FALSE)

#pull out numeric & character only columns
# numcols <- unlist(lapply(raw, is.numeric), use.names = FALSE)
# chrcols <- unlist(lapply(raw, is.character), use.names = FALSE)
# intcols <- unlist(lapply(raw, is.integer), use.names = FALSE) #n.b int cols count as numeric 

