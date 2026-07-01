-- ============================================================
-- County-Level Socioeconomic Correlates of Violent Crime
-- Capstone Project SQL Script
--
-- Author: Michael Davis
-- Platform: Google BigQuery / BigQuery ML
--
-- Description:
-- Principal SQL queries used to validate, clean, enrich, and analyze
-- the county-level analytical dataset for the capstone project.
-- Some raw dataset uploads were completed through the BigQuery UI.
-- ============================================================


-- ============================================================
-- 01. RAW TABLE VALIDATION
-- ============================================================

-- Count rows in the external NIBRS incident table.
SELECT
    COUNT(*) AS incident_rows
FROM `capstone-ii-499303.nibrs.ext_incident_raw`;

-- Inspect the first ten rows of the 2024 county analysis table.
SELECT *
FROM `capstone-ii-499303.nibrs.county_analysis_2024_v1`
LIMIT 10;

-- Review schema for the final master table.
SELECT
    column_name,
    data_type,
    ordinal_position
FROM `capstone-ii-499303.nibrs.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'county_analysis_master'
ORDER BY ordinal_position;


-- ============================================================
-- 02. U.S. RELIGION CENSUS CLEANING
-- ============================================================

-- Clean county summary data from the U.S. Religion Census.
CREATE OR REPLACE TABLE
`capstone-ii-499303.nibrs.usrc_2020_county_summaries_clean`
AS
SELECT
    SAFE_CAST(county_fips AS INT64) AS county_fips,
    state_name,
    county_name,
    county_population_2020,
    congregations,
    adherents,
    congregations_per_100000,
    adherents_pct_of_total_population,
    population_rank,
    congregations_rank,
    adherents_rank,
    congregations_per_100000_rank,
    adherents_pct_of_total_population_rank
FROM `capstone-ii-499303.nibrs.usrc_2020_county_summaries_raw`
WHERE SAFE_CAST(county_fips AS INT64) IS NOT NULL;

-- Validate cleaned U.S. Religion Census county table.
SELECT
    COUNT(*) AS counties,
    MIN(county_fips) AS min_fips,
    MAX(county_fips) AS max_fips
FROM `capstone-ii-499303.nibrs.usrc_2020_county_summaries_clean`;

-- Clean denomination-by-county detail table.
CREATE OR REPLACE TABLE
`capstone-ii-499303.nibrs.usrc_2020_group_by_county_detail_clean`
AS
SELECT
    SAFE_CAST(county_fips AS INT64) AS county_fips,
    state_name,
    county_name,
    SAFE_CAST(group_code AS INT64) AS group_code,
    group_name,
    SAFE_CAST(REPLACE(congregations, ',', '') AS INT64) AS congregations,
    SAFE_CAST(REPLACE(adherents, ',', '') AS INT64) AS adherents,
    SAFE_CAST(REPLACE(adherents_pct_of_total_adherents, '%', '') AS FLOAT64) / 100
        AS adherents_pct_of_total_adherents,
    SAFE_CAST(REPLACE(adherents_pct_of_total_population, '%', '') AS FLOAT64) / 100
        AS adherents_pct_of_total_population
FROM `capstone-ii-499303.nibrs.usrc_2020_group_by_county_detail_raw`
WHERE SAFE_CAST(county_fips AS INT64) IS NOT NULL;

-- Validate denomination detail table.
SELECT
    COUNT(*) AS denomination_rows,
    COUNT(DISTINCT county_fips) AS counties,
    COUNT(DISTINCT group_code) AS denominations
FROM `capstone-ii-499303.nibrs.usrc_2020_group_by_county_detail_clean`;


-- ============================================================
-- 03. COUNTY LAND AREA AND POPULATION DENSITY
-- ============================================================

-- Join Census/TIGER county land area into the master table and create population density.
CREATE OR REPLACE TABLE `capstone-ii-499303.nibrs.county_analysis_master` AS
SELECT
    c.*,
    a.land_sq_miles,
    a.water_sq_miles,
    a.INTPTLAT AS latitude,
    a.INTPTLON AS longitude,
    SAFE_DIVIDE(c.population, a.land_sq_miles) AS population_density
FROM `capstone-ii-499303.nibrs.county_analysis_2024_v1` c
LEFT JOIN `capstone-ii-499303.nibrs.county_land_area_2024` a
    ON c.county_fips = a.county_fips;

-- Validate land area join.
SELECT
    COUNT(*) AS analysis_rows,
    COUNT(a.county_fips) AS matched_rows
FROM `capstone-ii-499303.nibrs.county_analysis_2024_v1` c
LEFT JOIN `capstone-ii-499303.nibrs.county_land_area_2024` a
    ON c.county_fips = a.county_fips;

-- Identify county records that did not match the 2024 land area file.
SELECT
    c.county_fips,
    c.state_abbr,
    c.county_name
FROM `capstone-ii-499303.nibrs.county_analysis_2024_v1` c
LEFT JOIN `capstone-ii-499303.nibrs.county_land_area_2024` a
    ON c.county_fips = a.county_fips
WHERE a.county_fips IS NULL
ORDER BY c.state_abbr, c.county_name;

-- Inspect highest-density counties.
SELECT
    county_name,
    population,
    land_sq_miles,
    population_density
FROM `capstone-ii-499303.nibrs.county_analysis_master`
WHERE population_density IS NOT NULL
ORDER BY population_density DESC
LIMIT 20;


-- ============================================================
-- 04. EDUCATION FEATURE ENGINEERING
-- ============================================================

-- Add bachelor's degree or higher rate using NHGIS/ACS variables.
CREATE OR REPLACE TABLE `capstone-ii-499303.nibrs.county_analysis_master` AS
SELECT
    c.*,
    SAFE_DIVIDE(
        n.AUQ8E022 + n.AUQ8E023 + n.AUQ8E024 + n.AUQ8E025,
        n.AUQ8E001
    ) AS bachelors_or_higher_rate
FROM `capstone-ii-499303.nibrs.county_analysis_master` c
LEFT JOIN `capstone-ii-499303.capstone.nhgis0001_ds272_20245_county` n
    ON c.county_fips = n.TL_GEO_ID;

-- Add percentage version of bachelor's degree or higher.
CREATE OR REPLACE TABLE `capstone-ii-499303.nibrs.county_analysis_master` AS
SELECT
    c.*,
    c.bachelors_or_higher_rate * 100 AS bachelors_or_higher_pct
FROM `capstone-ii-499303.nibrs.county_analysis_master` c;

-- Inspect counties with highest bachelor's degree attainment.
SELECT
    county_name,
    bachelors_or_higher_rate,
    bachelors_or_higher_pct
FROM `capstone-ii-499303.nibrs.county_analysis_master`
WHERE bachelors_or_higher_rate IS NOT NULL
ORDER BY bachelors_or_higher_rate DESC
LIMIT 25;


-- ============================================================
-- 05. RELIGIOSITY FEATURE ENGINEERING
-- ============================================================

-- Join U.S. Religion Census county summary values.
CREATE OR REPLACE TABLE `capstone-ii-499303.nibrs.county_analysis_master` AS
SELECT
    c.*,
    r.congregations AS usrc_congregations,
    r.adherents AS usrc_adherents,
    r.congregations_per_100000 AS usrc_congregations_per_100k,
    r.adherents_pct_of_total_population AS usrc_adherents_rate,
    r.adherents_pct_of_total_population * 100 AS usrc_adherents_pct
FROM `capstone-ii-499303.nibrs.county_analysis_master` c
LEFT JOIN `capstone-ii-499303.nibrs.usrc_2020_county_summaries_clean` r
    ON c.county_fips = r.county_fips;

-- Identify counties where reported adherents exceed 100 percent of population.
SELECT
    COUNT(*) AS total_rows,
    COUNTIF(usrc_adherents_pct IS NOT NULL) AS rows_with_usrc,
    COUNTIF(usrc_adherents_pct > 100) AS rows_over_100_pct
FROM `capstone-ii-499303.nibrs.county_analysis_master`;

-- Create capped religiosity variable and flag counties over 100 percent.
CREATE OR REPLACE TABLE `capstone-ii-499303.nibrs.county_analysis_master` AS
SELECT
    c.*,
    LEAST(c.usrc_adherents_pct, 100) AS usrc_adherents_pct_capped,
    c.usrc_adherents_pct > 100 AS usrc_over_100_flag
FROM `capstone-ii-499303.nibrs.county_analysis_master` c;


-- ============================================================
-- 06. CDC PLACES CLEANING
-- ============================================================

-- Inspect PLACES schema.
SELECT
    column_name,
    data_type
FROM `capstone-ii-499303.nibrs.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'places_2022_raw'
ORDER BY ordinal_position;

-- Identify available PLACES measures.
SELECT DISTINCT
    MeasureId,
    Measure,
    Category
FROM `capstone-ii-499303.nibrs.places_2022_raw`
ORDER BY Category, Measure;

-- Pivot selected PLACES measures into one row per county.
CREATE OR REPLACE TABLE `capstone-ii-499303.nibrs.places_2022_clean` AS
SELECT
    LocationID AS county_fips,
    MAX(IF(MeasureId = 'BINGE', Data_Value, NULL)) AS binge_drinking_pct,
    MAX(IF(MeasureId = 'CSMOKING', Data_Value, NULL)) AS smoking_pct,
    MAX(IF(MeasureId = 'DEPRESSION', Data_Value, NULL)) AS depression_pct,
    MAX(IF(MeasureId = 'MHLTH', Data_Value, NULL)) AS frequent_mental_distress_pct,
    MAX(IF(MeasureId = 'ISOLATION', Data_Value, NULL)) AS social_isolation_pct,
    MAX(IF(MeasureId = 'FOODINSECU', Data_Value, NULL)) AS food_insecurity_pct,
    MAX(IF(MeasureId = 'OBESITY', Data_Value, NULL)) AS obesity_pct,
    MAX(IF(MeasureId = 'LPA', Data_Value, NULL)) AS physical_inactivity_pct,
    MAX(IF(MeasureId = 'SLEEP', Data_Value, NULL)) AS short_sleep_pct
FROM `capstone-ii-499303.nibrs.places_2022_raw`
GROUP BY county_fips;


-- ============================================================
-- 07. COUNTY HEALTH RANKINGS FEATURE ENGINEERING
-- ============================================================

-- Create county-only County Health Rankings table.
CREATE OR REPLACE TABLE
`capstone-ii-499303.nibrs.county_health_rankings_2024`
AS
SELECT *
FROM `capstone-ii-499303.nibrs.county_health_rankings_2024_raw`
WHERE countycode > 0;

-- Verify selected County Health Rankings variables exist.
SELECT
    fipscode,
    v001_rawvalue, v003_rawvalue, v004_rawvalue, v009_rawvalue,
    v011_rawvalue, v014_rawvalue, v021_rawvalue, v023_rawvalue,
    v024_rawvalue, v036_rawvalue, v042_rawvalue, v044_rawvalue,
    v049_rawvalue, v060_rawvalue, v062_rawvalue, v067_rawvalue,
    v069_rawvalue, v070_rawvalue, v082_rawvalue, v083_rawvalue,
    v088_rawvalue, v122_rawvalue, v124_rawvalue, v125_rawvalue,
    v132_rawvalue, v135_rawvalue, v136_rawvalue, v137_rawvalue,
    v138_rawvalue, v139_rawvalue, v140_rawvalue, v143_rawvalue,
    v145_rawvalue, v147_rawvalue, v149_rawvalue, v151_rawvalue,
    v159_rawvalue, v160_rawvalue, v167_rawvalue, v168_rawvalue
FROM `capstone-ii-499303.nibrs.county_health_rankings_2024`
LIMIT 10;

-- Join selected County Health Rankings variables into the master table.
CREATE OR REPLACE TABLE
`capstone-ii-499303.nibrs.county_analysis_master`
AS
SELECT
    c.*,
    h.v001_rawvalue  AS chr_premature_death_rate,
    h.v003_rawvalue  AS chr_uninsured_rate,
    h.v004_rawvalue  AS chr_primary_care_physicians_rate,
    h.v009_rawvalue  AS chr_smoking_rate,
    h.v011_rawvalue  AS chr_obesity_rate,
    h.v014_rawvalue  AS chr_teen_birth_rate,
    h.v021_rawvalue  AS chr_high_school_graduation_rate,
    h.v023_rawvalue  AS chr_unemployment_rate_chr,
    h.v024_rawvalue  AS chr_child_poverty_rate,
    h.v036_rawvalue  AS chr_poor_physical_health_days,
    h.v042_rawvalue  AS chr_poor_mental_health_days,
    h.v044_rawvalue  AS chr_income_inequality,
    h.v049_rawvalue  AS chr_excessive_drinking_rate,
    h.v060_rawvalue  AS chr_diabetes_rate,
    h.v062_rawvalue  AS chr_mental_health_provider_rate,
    h.v067_rawvalue  AS chr_driving_alone_rate,
    h.v069_rawvalue  AS chr_some_college_rate,
    h.v070_rawvalue  AS chr_physical_inactivity_rate,
    h.v082_rawvalue  AS chr_single_parent_household_rate,
    h.v083_rawvalue  AS chr_food_environment_index,
    h.v088_rawvalue  AS chr_dentist_rate,
    h.v122_rawvalue  AS chr_uninsured_children_rate,
    h.v124_rawvalue  AS chr_drinking_water_violations,
    h.v125_rawvalue  AS chr_air_pollution,
    h.v132_rawvalue  AS chr_access_to_exercise_rate,
    h.v135_rawvalue  AS chr_injury_death_rate,
    h.v136_rawvalue  AS chr_severe_housing_rate,
    h.v137_rawvalue  AS chr_long_commute_rate,
    h.v138_rawvalue  AS chr_drug_overdose_death_rate,
    h.v139_rawvalue  AS chr_food_insecurity_rate,
    h.v140_rawvalue  AS chr_social_association_rate,
    h.v143_rawvalue  AS chr_insufficient_sleep_rate,
    h.v145_rawvalue  AS chr_frequent_mental_distress_rate,
    h.v147_rawvalue  AS chr_life_expectancy,
    h.v149_rawvalue  AS chr_disconnected_youth_rate,
    h.v151_rawvalue  AS chr_gender_pay_gap,
    h.v159_rawvalue  AS chr_reading_score,
    h.v160_rawvalue  AS chr_math_score,
    h.v167_rawvalue  AS chr_school_segregation,
    h.v168_rawvalue  AS chr_high_school_completion_rate
FROM `capstone-ii-499303.nibrs.county_analysis_master` c
LEFT JOIN `capstone-ii-499303.nibrs.county_health_rankings_2024` h
    ON c.county_fips = h.fipscode;

-- Validate County Health Rankings join.
SELECT
    COUNT(*) AS counties,
    COUNTIF(chr_life_expectancy IS NOT NULL) AS life_expectancy,
    COUNTIF(chr_drug_overdose_death_rate IS NOT NULL) AS overdose,
    COUNTIF(chr_smoking_rate IS NOT NULL) AS smoking,
    COUNTIF(chr_food_insecurity_rate IS NOT NULL) AS food_insecurity,
    COUNTIF(chr_math_score IS NOT NULL) AS math_scores
FROM `capstone-ii-499303.nibrs.county_analysis_master`;


-- ============================================================
-- 08. MASTER TABLE QUALITY ASSURANCE
-- ============================================================

-- Inspect first ten rows.
SELECT *
FROM `capstone-ii-499303.nibrs.county_analysis_master`
LIMIT 10;

-- Verify row count.
SELECT COUNT(*) AS counties
FROM `capstone-ii-499303.nibrs.county_analysis_master`;

-- Check duplicate county FIPS codes.
SELECT
    county_fips,
    COUNT(*) AS records
FROM `capstone-ii-499303.nibrs.county_analysis_master`
GROUP BY county_fips
HAVING COUNT(*) > 1;

-- Check coverage for key variables.
SELECT
    COUNT(*) AS counties,
    COUNTIF(population IS NOT NULL) AS population,
    COUNTIF(bachelors_or_higher_pct IS NOT NULL) AS education,
    COUNTIF(usrc_adherents_pct IS NOT NULL) AS religiosity,
    COUNTIF(population_density IS NOT NULL) AS density,
    COUNTIF(chr_smoking_rate IS NOT NULL) AS smoking,
    COUNTIF(chr_excessive_drinking_rate IS NOT NULL) AS drinking,
    COUNTIF(chr_drug_overdose_death_rate IS NOT NULL) AS overdose,
    COUNTIF(chr_food_insecurity_rate IS NOT NULL) AS food_insecurity,
    COUNTIF(chr_life_expectancy IS NOT NULL) AS life_expectancy
FROM `capstone-ii-499303.nibrs.county_analysis_master`;

-- Identify counties with zero reported violent crime.
SELECT
    COUNT(*) AS counties_zero,
    AVG(poverty_rate) AS avg_poverty
FROM `capstone-ii-499303.nibrs.county_analysis_master`
WHERE violent_rate_per_100k = 0;

-- Inspect high-poverty counties with zero violent crime to identify likely reporting artifacts.
SELECT
    county_name,
    state_abbr,
    population,
    poverty_rate,
    violent_incidents,
    violent_rate_per_100k
FROM `capstone-ii-499303.nibrs.county_analysis_master`
WHERE poverty_rate > 0.35
ORDER BY poverty_rate DESC
LIMIT 30;


-- ============================================================
-- 09. EXPLORATORY ANALYSIS SUPPORT QUERIES
-- ============================================================

-- Outlier check for property crime rates.
SELECT
    county_name,
    state_abbr,
    population,
    property_incidents,
    property_rate_per_100k
FROM `capstone-ii-499303.nibrs.county_analysis_master`
ORDER BY property_rate_per_100k DESC
LIMIT 20;

-- Spot-check selected well-known counties.
SELECT
    county_name,
    state_abbr,
    population,
    median_household_income,
    bachelors_or_higher_pct,
    population_density,
    violent_rate_per_100k,
    property_rate_per_100k,
    usrc_adherents_pct_capped,
    chr_smoking_rate,
    chr_life_expectancy
FROM `capstone-ii-499303.nibrs.county_analysis_master`
WHERE county_name IN (
    'Los Angeles County',
    'Cook County',
    'Fairfax County',
    'New York County',
    'Salt Lake County'
)
ORDER BY state_abbr;


-- ============================================================
-- 10. PEARSON CORRELATION ANALYSIS
-- ============================================================

-- Pearson correlations between violent crime and selected predictors.
SELECT
    CORR(violent_rate_per_100k, bachelors_or_higher_pct)      AS corr_education,
    CORR(violent_rate_per_100k, median_household_income)      AS corr_income,
    CORR(violent_rate_per_100k, poverty_rate)                 AS corr_poverty,
    CORR(violent_rate_per_100k, population_density)           AS corr_population_density,
    CORR(violent_rate_per_100k, usrc_adherents_pct_capped)    AS corr_religiosity,
    CORR(violent_rate_per_100k, chr_drug_overdose_death_rate) AS corr_overdose,
    CORR(violent_rate_per_100k, food_insecurity_pct)          AS corr_food_insecurity,
    CORR(violent_rate_per_100k, smoking_pct)                  AS corr_smoking
FROM `capstone-ii-499303.nibrs.county_analysis_master`
WHERE
    population >= 10000
    AND violent_rate_per_100k > 0;

-- Pearson correlation using log-transformed population density.
SELECT
    CORR(
        violent_rate_per_100k,
        LOG10(population_density + 1)
    ) AS corr_log_population_density
FROM `capstone-ii-499303.nibrs.county_analysis_master`
WHERE
    population >= 10000
    AND violent_rate_per_100k > 0;


-- ============================================================
-- 11. BIGQUERY ML MULTIPLE LINEAR REGRESSION
-- ============================================================

-- Train linear regression model predicting violent crime rate.
CREATE OR REPLACE MODEL
`capstone-ii-499303.nibrs.violent_crime_regression`
OPTIONS(
    MODEL_TYPE = 'LINEAR_REG',
    INPUT_LABEL_COLS = ['violent_rate_per_100k']
) AS
SELECT
    violent_rate_per_100k,
    bachelors_or_higher_pct,
    median_household_income,
    poverty_rate,
    LOG10(population_density + 1) AS log_population_density,
    usrc_adherents_pct_capped,
    chr_drug_overdose_death_rate,
    food_insecurity_pct,
    smoking_pct
FROM `capstone-ii-499303.nibrs.county_analysis_master`
WHERE
    population >= 10000
    AND violent_rate_per_100k > 0
    AND bachelors_or_higher_pct IS NOT NULL
    AND median_household_income IS NOT NULL
    AND poverty_rate IS NOT NULL
    AND population_density IS NOT NULL
    AND usrc_adherents_pct_capped IS NOT NULL
    AND chr_drug_overdose_death_rate IS NOT NULL
    AND food_insecurity_pct IS NOT NULL
    AND smoking_pct IS NOT NULL;

-- Evaluate regression model.
SELECT *
FROM ML.EVALUATE(
    MODEL `capstone-ii-499303.nibrs.violent_crime_regression`
);

-- Inspect regression coefficients.
SELECT
    processed_input,
    weight,
    category_weights
FROM ML.WEIGHTS(
    MODEL `capstone-ii-499303.nibrs.violent_crime_regression`
)
ORDER BY ABS(weight) DESC;

-- ============================================================
-- END OF SCRIPT
-- ============================================================
