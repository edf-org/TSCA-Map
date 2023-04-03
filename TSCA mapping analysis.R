rm(list = ls())
library(readxl)
library(maps)
library(ggplot2)
library(sf)
#library(dplyr)
#library(PerformanceAnalytics)

raw=read.csv("data/DemographicImpactsofTRI.csv")

#pull out numeric & character only columns
numcols <- unlist(lapply(raw, is.numeric), use.names = FALSE)
chrcols <- unlist(lapply(raw, is.character), use.names = FALSE)
intcols <- unlist(lapply(raw, is.integer), use.names = FALSE) #n.b int cols count as numeric 

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


#EXPORTING
# Convert 'raw' data frame to an sf object
raw_sf <- st_as_sf(raw, coords = c("Longitude", "Latitude"), crs = st_crs(4326))

# Export the sf object as a shapefile
st_write(raw_sf, "data/TSCAfacilities.shp")
