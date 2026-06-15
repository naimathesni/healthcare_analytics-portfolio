-- Project 2: Healthcare Claims & ERA SQL Analysis
-- Script 05: Claims KPI Queries
-- SQL dialect: MySQL
-- Purpose: Calculate core claims, payment, denial, rejection, and revenue-cycle KPIs

USE healthcare_claims_era;


-- ============================================================
-- Section 1: Overall claim status summary
-- Business question:
-- How many claims are paid, denied, rejected, pending, or submitted?
-- ============================================================

SELECT
    claim_status,
    COUNT(*) AS claim_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM claims), 2) AS percent_of_total_claims,
    ROUND(SUM(billed_amount), 2) AS total_billed_amount,
    ROUND(SUM(COALESCE(allowed_amount, 0)), 2) AS total_allowed_amount,
    ROUND(AVG(billed_amount), 2) AS avg_billed_amount
FROM claims
GROUP BY claim_status
ORDER BY claim_count DESC;


-- Expected claim counts:
-- Rejected = 525
-- Pending = 338
-- Paid = 262
-- Denied = 188
-- Submitted = 187


-- ============================================================
-- Section 2: Executive claims KPI card
-- Business question:
-- What are the top-level claims KPIs?
-- ============================================================

SELECT
    COUNT(*) AS total_claims,

    SUM(CASE WHEN claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
    SUM(CASE WHEN claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

    ROUND(SUM(CASE WHEN claim_status = 'Paid' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS paid_rate_percent,
    ROUND(SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent,
    ROUND(SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,
    ROUND(SUM(CASE WHEN claim_status = 'Pending' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pending_rate_percent,

    ROUND(SUM(billed_amount), 2) AS total_billed_amount,
    ROUND(SUM(COALESCE(allowed_amount, 0)), 2) AS total_allowed_amount,
    ROUND(AVG(billed_amount), 2) AS avg_billed_amount
FROM claims;


-- Expected high-level values:
-- total_claims = 1500
-- paid_claims = 262
-- denied_claims = 188
-- rejected_claims = 525
-- pending_claims = 338
-- submitted_claims = 187
-- paid_rate_percent = 17.47
-- denial_rate_percent = 12.53
-- rejection_rate_percent = 35.00
-- pending_rate_percent = 22.53
-- total_billed_amount = 1105200.00


-- ============================================================
-- Section 3: Financial summary from claims and ERA
-- Business question:
-- What is the overall billed, allowed, paid, adjusted, and patient responsibility amount?
-- ============================================================

SELECT
    COUNT(DISTINCT c.claim_id) AS total_claims,
    COUNT(DISTINCT er.era_id) AS total_era_records,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount,
    ROUND(SUM(COALESCE(c.allowed_amount, 0)), 2) AS total_allowed_amount,

    ROUND(SUM(COALESCE(er.paid_amount, 0)), 2) AS total_paid_amount,
    ROUND(SUM(COALESCE(er.adjustment_amount, 0)), 2) AS total_adjustment_amount,
    ROUND(SUM(COALESCE(er.patient_responsibility, 0)), 2) AS total_patient_responsibility,

    ROUND(AVG(c.billed_amount), 2) AS avg_billed_amount,
    ROUND(AVG(CASE WHEN er.paid_amount IS NOT NULL THEN er.paid_amount END), 2) AS avg_paid_amount_for_era_claims
FROM claims c
LEFT JOIN era er
    ON c.claim_id = er.claim_id;


-- Expected:
-- total_claims = 1500
-- total_era_records = 450
-- total_billed_amount = 1105200.00
-- total_allowed_amount = 176723.24
-- total_paid_amount = 99910.59


-- ============================================================
-- Section 4: Claims grouped by claim type
-- Business question:
-- Are professional or institutional claims driving more volume or issues?
-- ============================================================

SELECT
    claim_type,
    COUNT(*) AS total_claims,

    SUM(CASE WHEN claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
    SUM(CASE WHEN claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

    ROUND(SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent,
    ROUND(SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,

    ROUND(SUM(billed_amount), 2) AS total_billed_amount,
    ROUND(AVG(billed_amount), 2) AS avg_billed_amount
FROM claims
GROUP BY claim_type
ORDER BY total_claims DESC;


-- ============================================================
-- Section 5: Claims grouped by claim source
-- Business question:
-- Which claim source has the highest rejected or denied claim rate?
-- ============================================================

SELECT
    claim_source,
    COUNT(*) AS total_claims,

    SUM(CASE WHEN claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
    SUM(CASE WHEN claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

    ROUND(SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent,
    ROUND(SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,

    ROUND(SUM(billed_amount), 2) AS total_billed_amount
FROM claims
GROUP BY claim_source
ORDER BY rejected_claims DESC;


-- ============================================================
-- Section 6: Monthly claim volume and billed amount
-- Business question:
-- How does claim volume and billed amount trend by month?
-- ============================================================

SELECT
    DATE_FORMAT(claim_submit_date, '%Y-%m') AS submit_month,
    COUNT(*) AS total_claims,

    SUM(CASE WHEN claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
    SUM(CASE WHEN claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

    ROUND(SUM(billed_amount), 2) AS total_billed_amount,
    ROUND(AVG(billed_amount), 2) AS avg_billed_amount
FROM claims
GROUP BY DATE_FORMAT(claim_submit_date, '%Y-%m')
ORDER BY submit_month;


-- ============================================================
-- Section 7: Claims with missing allowed amount by status
-- Business question:
-- Which claim statuses usually do not have allowed amounts yet?
-- ============================================================

SELECT
    claim_status,
    COUNT(*) AS total_claims,
    SUM(CASE WHEN allowed_amount IS NULL THEN 1 ELSE 0 END) AS claims_missing_allowed_amount,
    ROUND(SUM(CASE WHEN allowed_amount IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS missing_allowed_percent
FROM claims
GROUP BY claim_status
ORDER BY claims_missing_allowed_amount DESC;


-- Expected:
-- Submitted, Pending, and Rejected claims should have missing allowed amounts.
-- Paid and Denied claims should have allowed amounts.


-- ============================================================
-- Section 8: Rejected and denied claims combined
-- Business question:
-- How much claim volume is failing through rejection or denial?
-- ============================================================

SELECT
    COUNT(*) AS total_problem_claims,
    SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

    ROUND(SUM(billed_amount), 2) AS total_problem_billed_amount,
    ROUND(AVG(billed_amount), 2) AS avg_problem_billed_amount
FROM claims
WHERE claim_status IN ('Rejected', 'Denied');


-- Expected:
-- total_problem_claims = 713
-- rejected_claims = 525
-- denied_claims = 188


-- ============================================================
-- Section 9: Open/unresolved claims
-- Business question:
-- How many claims are still unresolved or not fully processed?
-- ============================================================

SELECT
    COUNT(*) AS unresolved_claims,
    ROUND(SUM(billed_amount), 2) AS unresolved_billed_amount,
    ROUND(AVG(billed_amount), 2) AS avg_unresolved_billed_amount
FROM claims
WHERE claim_status IN ('Submitted', 'Pending', 'Rejected');


-- Expected:
-- unresolved_claims = Submitted + Pending + Rejected
-- unresolved_claims = 1050


-- ============================================================
-- Section 10: Denial financial summary
-- Business question:
-- What is the total financial impact of denied claims?
-- ============================================================

SELECT
    COUNT(*) AS total_denials,
    ROUND(SUM(denied_amount), 2) AS total_denied_amount,
    ROUND(AVG(denied_amount), 2) AS avg_denied_amount,
    ROUND(MIN(denied_amount), 2) AS min_denied_amount,
    ROUND(MAX(denied_amount), 2) AS max_denied_amount
FROM denials;


-- Expected:
-- total_denials = 188


-- ============================================================
-- Section 11: Preventable denial summary
-- Business question:
-- How many denials may be preventable?
-- ============================================================

SELECT
    preventable_flag,
    COUNT(*) AS denial_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM denials), 2) AS percent_of_denials,
    ROUND(SUM(denied_amount), 2) AS denied_amount
FROM denials
GROUP BY preventable_flag
ORDER BY denial_count DESC;


-- ============================================================
-- Section 12: Denials by category
-- Business question:
-- Which denial categories are most common and most expensive?
-- ============================================================

SELECT
    denial_category,
    COUNT(*) AS denial_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM denials), 2) AS percent_of_denials,
    ROUND(SUM(denied_amount), 2) AS total_denied_amount,
    ROUND(AVG(denied_amount), 2) AS avg_denied_amount
FROM denials
GROUP BY denial_category
ORDER BY denial_count DESC;


-- Expected top denial category:
-- Enrollment/Configuration


-- ============================================================
-- Section 13: ERA payment summary
-- Business question:
-- What payment activity appears in ERA records?
-- ============================================================

SELECT
    COUNT(*) AS total_era_records,
    ROUND(SUM(paid_amount), 2) AS total_paid_amount,
    ROUND(SUM(adjustment_amount), 2) AS total_adjustment_amount,
    ROUND(SUM(patient_responsibility), 2) AS total_patient_responsibility,

    ROUND(AVG(paid_amount), 2) AS avg_paid_amount,
    ROUND(AVG(adjustment_amount), 2) AS avg_adjustment_amount,
    ROUND(AVG(patient_responsibility), 2) AS avg_patient_responsibility
FROM era;


-- Expected:
-- total_era_records = 450
-- total_paid_amount = 99910.59


-- ============================================================
-- Section 14: ERA status summary
-- Business question:
-- Are ERA records posted or still pending review?
-- ============================================================

SELECT
    era_status,
    COUNT(*) AS era_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM era), 2) AS percent_of_era_records,
    ROUND(SUM(paid_amount), 2) AS paid_amount,
    ROUND(SUM(adjustment_amount), 2) AS adjustment_amount
FROM era
GROUP BY era_status
ORDER BY era_count DESC;


-- ============================================================
-- Section 15: KPI summary for portfolio documentation
-- Business question:
-- What are the final KPI values to document from this script?
-- ============================================================

SELECT
    'Claims KPI Summary' AS report_name,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
    SUM(CASE WHEN claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

    ROUND(SUM(CASE WHEN claim_status = 'Paid' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS paid_rate_percent,
    ROUND(SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent,
    ROUND(SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,

    ROUND(SUM(billed_amount), 2) AS total_billed_amount,
    ROUND(AVG(billed_amount), 2) AS avg_billed_amount
FROM claims;



-- ============================================================
-- Analyst Notes
-- ============================================================

-- Most important KPI:
-- Rejection rate is high at 35.00%, which means many claims are failing before successful payment or denial processing.

-- Business interpretation:
-- Rejected claims represent an earlier revenue-cycle failure than denied claims because they may not be fully accepted for payer adjudication.

-- Follow-up analysis needed:
-- Join claims to enrollment, payer, and provider tables to determine whether rejected claims are related to enrollment readiness, NPI mismatch, payer setup, or clearinghouse configuration issues.