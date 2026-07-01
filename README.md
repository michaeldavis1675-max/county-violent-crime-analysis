# County-Level Socioeconomic Correlates of Violent Crime in the United States

**Technologies:** SQL • Google BigQuery • Python • Power BI • BigQuery ML • GitHub

**Dataset Size:** 53+ million FBI crime records integrated with five national public datasets

**Study Area:** 3,200+ U.S. counties

**Status:** Complete (Version 1.0)

## Overview

This project examines county-level socioeconomic factors associated with violent crime across the United States using publicly available datasets from multiple federal and nonprofit organizations.

The project integrates over **53 million FBI National Incident-Based Reporting System (NIBRS) crime records** with demographic, socioeconomic, public health, and religiosity data to create a unified county-level analytical dataset. The analysis was conducted using **Google BigQuery, SQL, Python, and Power BI**.

Rather than focusing on a single explanatory variable, this project evaluates multiple county-level characteristics simultaneously to better understand their relationships with violent crime.

---

# Research Questions

This project investigated the following questions:

- Is educational attainment associated with violent crime?
- Is household income associated with violent crime?
- Is poverty associated with violent crime?
- Does population density influence violent crime?
- Is religiosity associated with violent crime?
- Are food insecurity and other measures of socioeconomic distress associated with violent crime?
- Are health-related variables such as smoking prevalence and drug overdose mortality associated with violent crime?

---

# Why County-Level Analysis?

Many crime studies compare states or nations.

This project instead uses **county-level data** because counties generally provide a more localized socioeconomic context while remaining large enough for high-quality public data to be available nationwide.

Using counties increased the sample size from approximately **50 state-level observations to more than 3,200 counties**, substantially improving statistical power and geographic resolution.

---

# Data Sources

The project combines data from:

- FBI National Incident-Based Reporting System (NIBRS)
- U.S. Census Bureau American Community Survey (ACS)
- County Health Rankings & Roadmaps
- CDC PLACES
- U.S. Religion Census

---

# Tools Used

- Google BigQuery
- SQL
- BigQuery ML
- Python
- Google Colab
- Power BI
- GitHub

---

# Data Engineering

Major preparation steps included:

- Importing more than **53 million crime records**
- Cleaning and standardizing county identifiers
- Joining multiple national datasets
- Engineering county-level variables
- Calculating violent crime rates per 100,000 residents
- Building a unified analytical master table

---

# Exploratory Data Analysis

The project includes:

- SQL exploration
- Python analysis
- Scatterplots
- Trend line analysis
- Pearson correlations
- Multiple linear regression
- Interactive Power BI dashboard

---

# Key Findings

- No individual county-level socioeconomic variable emerged as a strong standalone predictor of violent crime.
- Food insecurity and poverty demonstrated the strongest positive associations.
- Median household income demonstrated a modest negative association.
- Educational attainment, religiosity, smoking prevalence, population density, and drug overdose mortality exhibited comparatively weak individual relationships.
- Multiple regression explained approximately **8%** of county-level variation in violent crime, suggesting that violent crime is influenced by numerous interacting economic, demographic, institutional, and social factors.

---

# Repository Contents

```text
README.md

Capstone_Report.pdf

Capstone_EDA.ipynb

SQL/
    data_import.sql
    feature_engineering.sql
    analysis.sql

Images/
    Dashboard.png
    Scatterplots/

Documentation/
    Data_Dictionary.pdf
```

---

# Future Research

Potential future expansions include:

- Multi-year longitudinal analysis
- Educational variables
- School funding
- Student-teacher ratios
- School climate
- School disciplinary practices
- Police staffing
- Police funding
- Community policing
- Officer workload
- Family stability
- Social support networks
- Intimate partner violence
- Machine learning models
- Spatial analysis

---

# Skills Demonstrated

- SQL
- BigQuery
- BigQuery ML
- Python
- Data Engineering
- Data Cleaning
- Feature Engineering
- Exploratory Data Analysis
- Statistical Analysis
- Power BI Dashboard Development
- Data Visualization
- Technical Writing
- GitHub Documentation

---

# Artificial Intelligence Acknowledgment

OpenAI ChatGPT was used as a technical assistant for brainstorming research questions, SQL troubleshooting, editing, report organization, and documentation. All data engineering, SQL development, statistical analyses, dashboard creation, interpretation of results, and project conclusions were completed and verified by the project author.

---

# Author

Michael Davis

Data Analytics Portfolio Project

2026
