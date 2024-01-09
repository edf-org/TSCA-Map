# Chemical Exposure Action Map by Environmental Defense Fund - *Methodology & Code*

This page contains more detail on the code and methodology underlying EDF's Chemical Exposure Action Map, located at [TBD].

## Introduction
The goal of this project was to assess the potential demographic impacts of facilities releasing 23 of the highest-priority toxic chemicals. This was accomplished by intersecting publicly available demographic data from the American Community Survey (ACS) with publicly available Toxic Release Inventory (TRI) data, which provides the locations of facilities that are required to report toxic chemical releases. From these two data sets we calculated the demographics found within 1, 5, and 10 kilometers (km) of each TRI facility that released chemicals between 2016 and 2020, of interest to the Environmental Defense Fund (EDF). This document describes the methods used in detail.

## Obtaining Census Data
We obtained census data from the 2020 ACS at the block group level for the continental US in 2020 using the getACS function in the tidyCensus package in R. This function allows users to specify the year, spatial scale, and demographic variables that are accessed. Table 1 contains the codes and descriptions of the demographic variables pulled. Data for these variables were obtained at three different spatial scales, including block group, census tract, and county. Census tract and county level data were obtained in order to provide a reference point for comparing the demographics within a given distance of a TRI reporting facility with that of the census tract or county that the TRI facility is located in. 

In some cases the raw data was summed to make more informative categories, including females of reproductive age (15-49), people aged 65+, children under 5, and people without a high school diploma. All population variables were divided by the total population in order to obtain a percentage. We also pulled economic variables including the median income and median housing price in each block group, tract, and county, as well as the number of owner occupied, vacant, and total housing units. 

## Risk-Screening Environmental Indicators Data
The Environmental Protection Agency’s Risk-Screening Environmental Indicators (RSEI) database incorporates information tracked by the EPA via the TRI program. It contains data on the releases of federally managed toxic chemicals that may cause harm to human health or the environment. The RSEI database combines the TRI information on the amount of toxic chemicals released or transferred from facilities as well as additional factors such as the chemical’s fate and transport through the environment, each chemical’s relative toxicity, and potential human exposure to model the risk associated with different chemical releases. We downloaded version 23.10 of the public release data for this project. Additional information about the data contained in each table of the RSEI database can be found here: https://www.epa.gov/rsei/rsei-data-dictionary-aggregated-grid-cell-geographic-microdata

## Identifying TRI Facilities Releasing Chemicals of Interest
The TRI program currently tracks 787 chemicals across 33 chemical categories. To narrow the scope of the project, EDF provided a list of 39 "Chemicals of Interest". We cross-referenced this list with the data provided in the Chems table (found in the file chemical_data_rsei_v2310.csv on the RSEI website), which provides information on all of the chemicals tracked in the RSEI database, and found data available for 25 of the chemicals on the list. 

Next, our goal was to find all reported releases for those 25 chemicals between 2016 and 2020 and sum them (and their associated risk scores) to get a yearly amount for each TRI facility. Because the RSEI data is stored in a number of different tables, it was necessary to identify the crosswalks between tables in order merge the necessary information into a single output file. This was achieved in a series of “join” steps, in which the desired columns were selected from each RSEI table to create a new table. This abbreviated table was then merged with others. 

First, a subset of columns was selected from ‘facility_data_rsei_v2310.csv’ to create a Facility table that included location information.  Similarly, a subset of columns with desired information was selected from ‘submission_data_rsei_v2310.csv’ to create a new "Submission" table. The "Facility" and "Submission" tables were then merged in order to link information on each TRI facility such as location, NAICS code, etc, to each submitted TRI report, which contains info on the year, chemical, and facility for each reported release (there are multiple releases reported per submission number). Because data on the actual poundage of chemicals released is found in ‘release_data_rsei_v2310.csv’,  the columns for Submission Number, Release Number, Media, and Pounds Released were selected from this table to create a new "Release" table. The Release table was then merged with the info from the Facility and Submission tables. 

Finally, the RSEI model hazard scores are stored in ‘elements_data_rsei_v2310.csv’, where there can be multiple hazard scores per chemical release. For each chemical release we summed the pounds, Score, Non-Cancer Score, Cancer Score, Hazard Score, Cancer Hazard Score, and Non-Cancer Hazard Score, and linked this total score back to the Release table to get a single score per release across each score type. These were then linked to a submission and merged to obtain a large table in which each row/column was a chemical release and its associated hazard scores by a given facility in a given year. We filtered this table to contain only releases made in years 2016-2020, and then summed each release and associated scores by chemical number and year to obtain the total amount of each chemical of interest released by each facility in each year between 2016 and 2020, as well as the modeled scores. This information can be found in the file "UpdatedRSEIByChemical_2016to2020.csv".

## Aerial Apportionment of Demographics near TRI Facilities 
Spatial operations were conducted using the sf package in R, and all data sets were converted to spatial objects using the "st_as_sf” function.  

TRI facility location data is provided in units of degrees in the North American Datum of 1983 (NAD83; https://epsg.io/4269) coordinate system, which is the system used by the federal government. For spatial analyses involving distances, such as determining the boundaries of concentric circles with radii specified in kilometers, it is necessary is to create a projected copy of the data in which latitude and longitude are converted to metric distances. To do this, TRI facilities locations were pulled from the filtered RSEI data. Any entries with NAs in the "Latitude" and "Longitude" columns were removed, as those were located outside the continental US. Facility locations were then transformed using the “st_transform” function in the sf package in R to the World Geodetic System (WGS84; https://epsg.io/3857), which a commonly used metric projection system in meters. All three sets of census data were also projected from NAD83 to WGS84.

After converting all data sets to metric projections, we used the “st_buffer” function to create a 1km buffer around each TRI facility location. Buffers are polygons representing the area within a given distance of a geometric feature. Because we are treating TRI locations as points, the buffer created is a concentric circle with a radius of 1km. Buffers are polygons representing the area within a given distance of a geometric feature: regardless of whether the input is a point, line or polygon, the output is a polygon. The buffer polygons centered on the TRI facilities were overlaid on the census block group polygons using the “st_intersection” function to determine which block groups had area that fell within the buffer. We then used the function “st_area” to determine the amount of area of each block group that fell within the buffer and converted this to a percentage of the total block group area. The same operations were repeated for 5 and 10 km buffers.

To calculate the number of people within each buffer we assumed that the people counted within each block group in the ACS were evenly distributed across the entire block group. We multiplied the percentage of each block group that fell within the buffer by the number of people in each variable and added up those numbers across all the block groups near each facility to get the total number of people in each demographic that may be subject to releases by a given facility at that distance. While this assumption is obviously a rough approximation and a source of error, we did not have the resources to use cutting edge techniques such as dasymetric mapping with remotely sensed datasets (e.g. Worldpop or Landscan) to reduce this source of uncertainty. The number of people within each demographic variable were converted to percentages, and the tract and county ACS data was used to determine demographic percentages within the tract and county that each facility was found in for comparison purposes. 

This produced a data table summarizing the percent of each demography found within 1, 5, and 10 km of each TRI facility in the continental US in 2020. This was merged with the RSEI data above so that users could determine, for any given facility-chemical combination between 2016 and 2020, the number of people of different demographics potentially impacted at each distance as well as the modeled risk/hazard scores associated with that chemical release. These data can be found in the file “DemographicImpactsofTRI.csv” (also saved as a .rds object).

For more information and an R package encapsulating the bulk of these areal apportionment operations and code, please visit: https://github.com/SarahValencia/ArealApportionment  
Note that these methods have been generalized for widespread use as an R library.

## Processing for Display in EDF’s Chemical Exposure Action Map
Data output in the “DemographicImpactsofTRI.csv” file were then processed further in the “TSCA mapping analysis.R” script to stage it for display in EDF’s Chemical Exposure Action Map. Each chemical of interest was assigned to 1 or multiple health risk outcomes of interest, based on a literature review: cancer, early-life harms (developmental toxicity), and asthma. In addition to these categorizations, each chemical was assigned a weighting factor (as denoted in tab 3 of the “TSCA Fenceline Map Chem Hazard Data Extraction.xlsx" spreadsheet). Cancer chemicals were weighted based on the International Agency for Research on Cancer (IARC) classifications. Developmental (early-life harm) toxicants were weighted based on hazard scores (outlined in EPA’s TSCA Work Plan Chemicals: Methods Document) that were assigned based their acute no observed adverse effect levels (NOAELs) derived from the Agency for Toxic Substances and Disease Registry (ATSDR) Toxicological Profiles and EPA’s Integrated Risk Information System (IRIS) assessments. Asthma chemicals were weighted based on log-transformed Reference Concentrations (RfCs) from EPA’s IRIS assessments. These weighted factors roughly capture the relative degree to which the toxicity of a chemical contributes to a certain health outcome, amongst the full set of chemicals that are linked to it. These weightings are used in assigning ‘Weighted Risk Levels’ of Lower, Higher or Highest on the map pages relating to Cancer, Early-Life Harms, and Asthma.

Chemical releases by facility and other data are then summarized such that the dataset contains a single entry per facility. Each entry delineates the following:
•	A list of all the chemicals released (2016-2020);
•	The annual minima, maxima, and the sum of (annual maxima) pounds of chemicals released during 2016-2020;
•	A percentile rank and weighted risk level estimated according to the sum of pounds released;
•	The same metrics as above but subsetted only to chemicals linked to each health risk of interest (cancer, early-life harms, and asthma);
•	A variable denoting a count of how many of the three health risks of interest the chemicals released at a facility are linked to;
•	Demographic metrics obtained from the prior steps, for the 10 km buffer around facilities and county-wide values to provide a representative control group for comparison, in terms of roughly gauging over/under-representation of vulnerable populations in proximity of facilities;
•	Estimates of the number of other facilities within a 10km radius, and sums of each facility-specific sum of (annual maxima) pounds of chemicals released during 2016-2020. These are calculated as metrics provided in the action alerts to policymakers, and aim to characterize the cumulative nature of chemical releases.

Data are then exported and uploaded to ESRI’s ArcGIS online for display. 



*Table 1. Variables pulled using GetACS command from tidyCensus package in R.*
| **Variable Name** | **Description**                                                                              | **Category**              |
| ----------------- | -------------------------------------------------------------------------------------------- | ------------------------- |
| B01001_001        | Estimate!!Total:                                                                             | SEX BY AGE                |
| B01001_003        | Estimate!!Total:!!Male:!!Under 5 years                                                       | SEX BY AGE                |
| B01001_020        | Estimate!!Total:!!Male:!!65 and 66 years                                                     | SEX BY AGE                |
| B01001_021        | Estimate!!Total:!!Male:!!67 to 69 years                                                      | SEX BY AGE                |
| B01001_022        | Estimate!!Total:!!Male:!!70 to 74 years                                                      | SEX BY AGE                |
| B01001_023        | Estimate!!Total:!!Male:!!75 to 79 years                                                      | SEX BY AGE                |
| B01001_024        | Estimate!!Total:!!Male:!!80 to 84 years                                                      | SEX BY AGE                |
| B01001_025        | Estimate!!Total:!!Male:!!85 years and over                                                   | SEX BY AGE                |
| B01001_027        | Estimate!!Total:!!Female:!!Under 5 years                                                     | SEX BY AGE                |
| B01001_030        | Estimate!!Total:!!Female:!!15 to 17 years                                                    | SEX BY AGE                |
| B01001_031        | Estimate!!Total:!!Female:!!18 and 19 years                                                   | SEX BY AGE                |
| B01001_032        | Estimate!!Total:!!Female:!!20 years                                                          | SEX BY AGE                |
| B01001_033        | Estimate!!Total:!!Female:!!21 years                                                          | SEX BY AGE                |
| B01001_034        | Estimate!!Total:!!Female:!!22 to 24 years                                                    | SEX BY AGE                |
| B01001_035        | Estimate!!Total:!!Female:!!25 to 29 years                                                    | SEX BY AGE                |
| B01001_036        | Estimate!!Total:!!Female:!!30 to 34 years                                                    | SEX BY AGE                |
| B01001_037        | Estimate!!Total:!!Female:!!35 to 39 years                                                    | SEX BY AGE                |
| B01001_038        | Estimate!!Total:!!Female:!!40 to 44 years                                                    | SEX BY AGE                |
| B01001_039        | Estimate!!Total:!!Female:!!45 to 49 years                                                    | SEX BY AGE                |
| B01001_044        | Estimate!!Total:!!Female:!!65 and 66 years                                                   | SEX BY AGE                |
| B01001_045        | Estimate!!Total:!!Female:!!67 to 69 years                                                    | SEX BY AGE                |
| B01001_046        | Estimate!!Total:!!Female:!!70 to 74 years                                                    | SEX BY AGE                |
| B01001_047        | Estimate!!Total:!!Female:!!75 to 79 years                                                    | SEX BY AGE                |
| B01001_048        | Estimate!!Total:!!Female:!!80 to 84 years                                                    | SEX BY AGE                |
| B01001_049        | Estimate!!Total:!!Female:!!85 years and over                                                 | SEX BY AGE                |
| B02001_002        | Estimate!!Total:!!White alone                                                                | RACE                      |
| B02001_003        | Estimate!!Total:!!Black or African American alone                                            | RACE                      |
| B02001_004        | Estimate!!Total:!!American Indian and Alaska Native alone                                    | RACE                      |
| B02001_005        | Estimate!!Total:!!Asian alone                                                                | RACE                      |
| B02001_006        | Estimate!!Total:!!Native Hawaiian and Other Pacific Islander alone                           | RACE                      |
| B02001_007        | Estimate!!Total:!!Some other race alone                                                      | RACE                      |
| B02001_008        | Estimate!!Total:!!Two or more races:                                                         | RACE                      |
| B03003_003        | Estimate!!Total:!!Hispanic or Latino                                                         | HISPANIC OR LATINO ORIGIN |
| B15003_001        | Estimate!!Total:                                                                             | EDUCATIONAL ATTAINMENT    |
| B15003_017        | Estimate!!Total:!!Regular high school diploma                                                | EDUCATIONAL ATTAINMENT    |
| B15003_018        | Estimate!!Total:!!GED or alternative credential                                              | EDUCATIONAL ATTAINMENT    |
| B15003_019        | Estimate!!Total:!!Some college, less than 1 year                                             | EDUCATIONAL ATTAINMENT    |
| B15003_020        | Estimate!!Total:!!Some college, 1 or more years, no degree                                   | EDUCATIONAL ATTAINMENT    |
| B15003_021        | Estimate!!Total:!!Associate's degree                                                         | EDUCATIONAL ATTAINMENT    |
| B15003_022        | Estimate!!Total:!!Bachelor's degree                                                          | EDUCATIONAL ATTAINMENT    |
| B15003_023        | Estimate!!Total:!!Master's degree                                                            | EDUCATIONAL ATTAINMENT    |
| B15003_024        | Estimate!!Total:!!Professional school degree                                                 | EDUCATIONAL ATTAINMENT    |
| B15003_025        | Estimate!!Total:!!Doctorate degree                                                           | EDUCATIONAL ATTAINMENT    |
| B19013_001        | Estimate!!Median household income in the past 12 months (in 2019 inflation-adjusted dollars) | MEDIAN HOUSEHOLD INCOME   |
| B25001_001        | Estimate!!Total                                                                              | HOUSING UNITS             |
| B25002_002        | Estimate!!Total:!!Occupied                                                                   | OCCUPANCY STATUS          |
| B25002_003        | Estimate!!Total:!!Vacant                                                                     | OCCUPANCY STATUS          |
| B25077_001        | Estimate!!Median value (dollars)                                                             | MEDIAN VALUE (DOLLARS)    |






