# Provider/Payer EDI Enrollment Readiness Dashboard

## Project Overview

This project analyzes provider/payer EDI enrollment readiness for electronic claims submission and ERA receipt through a preferred clearinghouse.

The dashboard tracks claims enrollment, ERA enrollment, credentialing alignment, payer setup, NPI/PTAN issues, clearinghouse configuration, SLA breaches, payer-level blockers, and action-required records.

This project is based on synthetic healthcare operations data inspired by real-world EDI enrollment and revenue-cycle workflows.

---

## Business Problem

Healthcare practices need to be properly configured before they can submit electronic claims and receive electronic remittance advice through a clearinghouse.

Claims and ERA workflows can be delayed or blocked when:

- The provider or group is not credentialed with the payer
- The wrong NPI is enrolled
- Individual NPI is used instead of group NPI
- PTAN or provider number is incorrect
- Medicare/Medicaid additional enrollment is missing
- Clearinghouse portal setup is not updated
- Wrong or outdated payer ID is used
- ERA setup is incomplete

This dashboard helps operations teams identify readiness gaps, aging records, top blockers, payer-level issues, and action-required items.

---

## Project Objective

The objective of this project is to build an Excel-based operational dashboard that helps answer:

1. How many enrollment records are ready, pending, or blocked?
2. How many records require follow-up action?
3. Which records have breached the 21-day SLA?
4. What are the most common enrollment/configuration blockers?
5. Which payers have the highest number of blocked records?
6. How many records are ready for claims submission versus ERA receipt?
7. Which assigned owners have the highest action-required workload?

---

## Dataset

The project uses a synthetic dataset of 250 enrollment/setup records.

One row represents one practice/provider/payer/enrollment setup record.

Main fields include:

- Practice Name
- Provider Name
- Individual NPI
- Group NPI
- Credentialed NPI
- Enrolled NPI
- Tax ID
- Payer Name
- Payer ID
- Payer Type
- PTAN / Provider Number
- Enrollment Type
- Credentialing Status
- Claims Enrollment Status
- ERA Enrollment Status
- Clearinghouse Portal Updated
- Clearinghouse Configuration Status
- Submitted Date
- Approved Date
- Current Status
- Blocker Reason
- Assigned Owner
- Follow-up Date
- Notes

---

## Tools Used

- Microsoft Excel
- Excel Tables
- Excel formulas
- PivotTables
- PivotCharts
- KPI cards
- Dashboard design
- Data quality checks
- Analyst documentation

---

## Workbook Sheets

| Sheet Name | Purpose |
|---|---|
| `raw_enrollment_data` | Original synthetic enrollment dataset |
| `working_clean_data` | Cleaned dataset with calculated fields |
| `data_quality_checks` | Validation checks for record count, missing values, status values, and readiness calculations |
| `KPI Definitions` | Definitions of key metrics used in the dashboard |
| `summary_metrics` | Formula-based KPI and summary calculations |
| `pivot_analysis` | PivotTables used for dashboard charts |
| `dashboard` | Final Excel dashboard |
| `insights_notes` | Business problem, insights, recommendations, assumptions, and project explanation |

---

## Key Calculated Fields

| Field | Purpose |
|---|---|
| Aging Days | Calculates how long an enrollment/setup record has been open or how long it took to complete |
| SLA Status | Flags records as Completed, Within SLA, or SLA Breached |
| NPI Match Status | Compares credentialed NPI against enrolled NPI |
| Provider Identifier Issue Flag | Flags NPI, PTAN, or provider number issues |
| Payer Routing Issue Flag | Flags wrong or outdated payer ID issues |
| Clearinghouse Gap Flag | Flags clearinghouse portal/configuration gaps |
| Government Payer Issue Flag | Flags Medicare/Medicaid-specific enrollment issues |
| Claims Ready Flag | Identifies records ready for electronic claims submission |
| ERA Ready Flag | Identifies records ready for electronic remittance receipt |
| Action Required Flag | Identifies records that need follow-up |

---

## Dashboard KPIs

| KPI | Value |
|---|---:|
| Total Records | 250 |
| Ready | 57 |
| Pending | 91 |
| Blocked | 102 |
| Action Required | 193 |
| SLA Breached | 158 |
| Claims Ready | 48 |
| ERA Ready | 38 |

---

## Dashboard Preview

![Dashboard Overview](screenshots/dashboard_overview.png)

---

## Dashboard Sections

The dashboard includes the following sections:

1. **KPI Cards**  
   Shows total records, ready records, pending records, blocked records, action-required records, SLA breaches, claims-ready records, and ERA-ready records.

2. **Enrollment Readiness Status**  
   Shows the distribution of records by Ready, Pending, and Blocked status.

3. **Top Enrollment Blockers**  
   Identifies the most common root causes preventing enrollment readiness.

4. **Blocked Records by Payer**  
   Shows which payers have the highest number of blocked records.

5. **SLA Breaches by Payer**  
   Shows which payers have the most records beyond the assumed 21-day SLA.

6. **Claims vs ERA Readiness**  
   Compares records ready for claims submission against records ready for ERA receipt.

7. **Action Required by Owner**  
   Shows pending and blocked workload by assigned owner.

8. **Key Insights**  
   Summarizes the main findings from the dashboard.

---

## Key Insights

1. **193 of 250 records require action**, showing that most records are not fully transaction-ready.

2. **158 records are beyond the 21-day SLA**, indicating aging risk in the enrollment workflow.

3. **Clearinghouse portal gaps and individual-vs-group NPI issues are the top blockers.**

4. **Blue Cross, Humana, and Cigna have the highest blocked record counts.**

5. **Claims readiness is higher than ERA readiness**, with 48 claims-ready records compared with 38 ERA-ready records.

---

## Recommendations

1. Validate credentialed NPI against enrolled NPI before submitting claims or ERA enrollment.

2. Add a clearinghouse portal update checkpoint before marking records as ready.

3. Create a Medicare/Medicaid checklist for PTAN, provider number, and additional enrollment requirements.

4. Review SLA-breached records weekly to reduce aging risk.

5. Prioritize follow-up for payers with the highest blocked record counts.

6. Track claims readiness and ERA readiness separately because a record may be claims-ready but not ERA-ready.

---

## Data Quality Checks

Before creating the dashboard, data quality checks were performed for:

- Total record count
- Blank Record IDs
- Blank Practice Names
- Blank Payer Names
- Blank Submitted Dates
- Invalid Current Status values
- NPI mismatch count
- Records over 21 days
- SLA breached records
- Claims ready records
- ERA ready records
- Action required records

These checks helped confirm that the dataset was ready for analysis.

---

## Project Files

| File / Folder | Description |
|---|---|
| `dataset/sample_enrollment_data.xlsx` | Excel workbook containing raw data, cleaned data, pivots, dashboard, and insights |
| `screenshots/dashboard_overview.png` | Screenshot of the final dashboard |
| `screenshots/insights_notes.png` | Screenshot of the insights and recommendations sheet |
| `screenshots/data_quality_checks.png` | Screenshot of the data quality checks |
| `README.md` | Project documentation |

---

## Assumptions

- This project uses synthetic data only.
- No real patient, provider, payer, practice, employer, or production data is included.
- One row represents one practice/provider/payer/enrollment setup record.
- A 21-day SLA was assumed for aging analysis.
- Records marked “No blocker” are treated as not requiring action.
- Claims readiness and ERA readiness are tracked separately because a record may be ready for one workflow but not the other.

---

## Limitations

- The dataset is synthetic and does not represent actual payer or practice performance.
- The SLA threshold of 21 days is assumed for this project.
- The dashboard is built in Excel and is intended for operational analysis and portfolio demonstration.
- The analysis focuses on enrollment readiness and does not include downstream claim payment, denial, or ERA posting data.

---

## Future Improvements

Possible future improvements include:

- Adding claim rejection and denial data
- Connecting enrollment readiness to actual claim submission outcomes
- Tracking ERA receipt and payment posting delays
- Adding monthly trend analysis
- Building the same dashboard in Power BI
- Adding slicers for payer, owner, enrollment type, and SLA status
- Automating refresh with Power Query

---

## Portfolio Summary

Built an Excel-based healthcare EDI enrollment readiness dashboard using 250 synthetic enrollment records to analyze claims enrollment, ERA enrollment, credentialing alignment, payer setup, NPI/PTAN issues, clearinghouse configuration, SLA breaches, payer-level blockers, and action-required records.

This project demonstrates Excel data cleaning, calculated fields, PivotTables, PivotCharts, KPI design, dashboard layout, healthcare operations analysis, and business insight communication.
