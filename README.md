# Healthcare Analytics Portfolio

This portfolio showcases healthcare analytics projects focused on EDI enrollment, claims enrollment, ERA enrollment, payer setup, clearinghouse readiness, revenue-cycle operations, SQL analysis, Excel dashboards, Power BI, Python, and business analysis.

My background is in healthcare Revenue cycle EDI Enrollment and I would like to share a glimpse of what it is like through these projects.

All datasets in this portfolio are synthetic or public-safe. No real patient, provider, payer, employer, practice, or production data is included.

---

## Projects

### 1. Provider/Payer EDI Enrollment Readiness Dashboard

**Tool:** Microsoft Excel  
**Status:** Complete  
**Focus:** EDI enrollment, ERA enrollment, claims enrollment, clearinghouse configuration, payer setup, NPI/PTAN issues, SLA breaches, and action-required tracking.

This project analyzes 250 synthetic provider/payer enrollment records to identify whether practices are ready for electronic claims submission and ERA receipt through a preferred clearinghouse.

The dashboard tracks readiness gaps caused by:

- Claims enrollment issues
- ERA enrollment issues
- NPI mismatch
- Individual NPI used instead of group NPI
- PTAN/provider number issues
- Clearinghouse portal gaps
- Payer setup issues
- Credentialing or payer approval blockers
- SLA breaches
- Claims-ready and ERA-ready status

**Key KPIs:**

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

**Key takeaway:**  
Most records required action, with clearinghouse portal gaps and NPI-related issues appearing as major blockers. The project recommends stronger NPI validation, clearinghouse update checkpoints, payer follow-up, and separate tracking for claims readiness and ERA readiness.

[View Project](01_enrollment_tracker_excel)

---

### 2. Healthcare Claims & ERA SQL Analysis

**Tool:** MySQL  
**Status:** Complete  
**Focus:** Claims, ERA, denials, payer performance, provider performance, enrollment readiness, NPI/PTAN issues, clearinghouse configuration, and revenue-cycle SQL analysis.

This project uses synthetic healthcare claims, ERA, denial, payer, provider, and enrollment data to analyze claim outcomes, rejection rate, denial categories, ERA/payment lag, payer performance, and enrollment-related operational risk.

The project includes SQL scripts for:

- Database and table creation
- Synthetic data loading
- Data quality checks
- Basic SELECT queries
- Claims KPI analysis
- Multi-table joins
- Denial analysis
- ERA/payment lag analysis
- Enrollment impact analysis
- CTE-based payer performance analysis
- Window functions
- Business-question-driven SQL analysis
- Screenshot-ready portfolio queries

**Dataset size:**

| Table | Row Count |
|---|---:|
| Payers | 10 |
| Providers | 40 |
| Enrollment Records | 400 |
| Claims | 1,500 |
| ERA Records | 450 |
| Denial Records | 188 |

**Key KPIs:**

| KPI | Value |
|---|---:|
| Total Claims | 1,500 |
| Paid Claims | 262 |
| Denied Claims | 188 |
| Rejected Claims | 525 |
| Rejection Rate | 35.00% |
| Denial Rate | 12.53% |
| Total ERA Records | 450 |
| Claims Without ERA | 1,050 |
| Average ERA Lag | 20.16 days |
| Enrollment/Configuration Denials | 75 |

**Key takeaway:**  
Rejected claims were a major revenue-cycle risk, and Enrollment/Configuration was the largest denial category. The analysis showed that payer setup, NPI/PTAN validation, claims enrollment, ERA readiness, and clearinghouse configuration can directly affect claim outcomes and remittance flow.

[View Project](02_claims_era_sql_analysis)

---

### 3. Healthcare Claims, ERA & Denial Analytics Dashboard

**Tool:** Power BI  
**Status:** Complete  
**Focus:** Claims outcomes, rejected claims, denied claims, ERA coverage, payment lag, payer performance, denial categories, enrollment readiness, NPI mismatch, clearinghouse gaps, and provider/practice drilldowns.

This project uses synthetic healthcare revenue-cycle data exported from MySQL to build a multi-page Power BI dashboard for claims, ERA, denials, payer performance, provider performance, and enrollment impact analysis.

The dashboard includes:

- Executive Summary
- Payer Performance
- Denial Analysis
- ERA & Payment Analysis
- Enrollment Impact
- Provider / Practice Drilldown

**Key KPIs:**

| KPI | Value |
|---|---:|
| Total Claims | 1,500 |
| Rejected Claims | 525 |
| Denied Claims | 188 |
| Rejection Rate | 35.00% |
| Denial Rate | 12.53% |
| Total ERA Records | 450 |
| Claims Without ERA | 1,050 |
| Average ERA Lag | 20.16 days |
| Preventable Denials | 151 |
| Claims Submitted While Not Claims-Ready | 900 |

**Key takeaway:**  
The dashboard shows that rejected claims are a major revenue-cycle risk, Enrollment/Configuration is the top denial category, ERA lag should be monitored by payer, and claims readiness should be validated before submission.

[View Project](03_claims_era_powerbi_dashboard)

---

## Data Privacy Note

All projects use synthetic or public-safe data only.

No real patient data, provider data, payer data, employer data, practice data, production data, credentials, passwords, or confidential business data is included.
