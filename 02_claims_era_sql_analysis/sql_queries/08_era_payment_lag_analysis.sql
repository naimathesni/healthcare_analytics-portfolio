-- ============================================================
-- Project: Healthcare Claims & ERA SQL Analysis
-- Script: 08_era_payment_lag_analysis.sql
-- Topic: ERA receipt, payment lag, payment summary, and claims-without-ERA analysis
-- SQL dialect: MySQL
-- Purpose:
--   Analyze electronic remittance activity, payer payment turnaround,
--   claims without ERA records, ERA status, and payment lag risk.
-- ============================================================

USE healthcare_claims_era;


-- ============================================================
-- Section 1: Overall ERA KPI summary
-- Business question:
-- What is the overall ERA volume, payment amount, and payment lag?
-- Join logic:
-- INNER JOIN is used because this section analyzes claims that have ERA records.
-- ============================================================

WITH era_claims AS (
    SELECT
        er.era_id,
        er.claim_id,
        c.claim_status,
        c.claim_submit_date,
        er.era_date,
        DATEDIFF(er.era_date, c.claim_submit_date) AS era_lag_days,
        c.billed_amount,
        c.allowed_amount,
        er.paid_amount,
        er.adjustment_amount,
        er.patient_responsibility,
        er.payment_method,
        er.era_status
    FROM era er
    INNER JOIN claims c
        ON er.claim_id = c.claim_id
)

SELECT
    COUNT(*) AS total_era_records,
    COUNT(DISTINCT claim_id) AS claims_with_era,

    (
        SELECT COUNT(*)
        FROM claims c
        LEFT JOIN era er
            ON c.claim_id = er.claim_id
        WHERE er.claim_id IS NULL
    ) AS claims_without_era,

    ROUND(SUM(paid_amount), 2) AS total_paid_amount,
    ROUND(SUM(adjustment_amount), 2) AS total_adjustment_amount,
    ROUND(SUM(patient_responsibility), 2) AS total_patient_responsibility,

    ROUND(AVG(paid_amount), 2) AS avg_paid_amount,
    ROUND(AVG(adjustment_amount), 2) AS avg_adjustment_amount,

    ROUND(AVG(era_lag_days), 2) AS avg_era_lag_days,
    MIN(era_lag_days) AS min_era_lag_days,
    MAX(era_lag_days) AS max_era_lag_days
FROM era_claims;


-- Expected:
-- total_era_records = 450
-- claims_with_era = 450
-- claims_without_era = 1050
-- total_paid_amount = 99910.59
-- avg_era_lag_days = 20.16
-- min_era_lag_days = 7
-- max_era_lag_days = 34


-- ============================================================
-- Section 2: ERA records by claim status
-- Business question:
-- Are ERA records tied to paid or denied claims?
-- ============================================================

SELECT
    c.claim_status,

    COUNT(*) AS era_records,

    ROUND(SUM(er.paid_amount), 2) AS total_paid_amount,
    ROUND(SUM(er.adjustment_amount), 2) AS total_adjustment_amount,
    ROUND(SUM(er.patient_responsibility), 2) AS total_patient_responsibility,

    ROUND(AVG(DATEDIFF(er.era_date, c.claim_submit_date)), 2) AS avg_era_lag_days
FROM era er
INNER JOIN claims c
    ON er.claim_id = c.claim_id
GROUP BY c.claim_status
ORDER BY era_records DESC;


-- Expected:
-- ERA records should only be tied to Paid and Denied claims in this synthetic dataset.


-- ============================================================
-- Section 3: ERA status summary
-- Business question:
-- Are ERA records posted or still pending review?
-- ============================================================

SELECT
    era_status,

    COUNT(*) AS era_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM era), 2) AS percent_of_era_records,

    ROUND(SUM(paid_amount), 2) AS total_paid_amount,
    ROUND(SUM(adjustment_amount), 2) AS total_adjustment_amount,
    ROUND(SUM(patient_responsibility), 2) AS total_patient_responsibility
FROM era
GROUP BY era_status
ORDER BY era_count DESC;


-- Expected:
-- Posted = 401
-- Pending Review = 49


-- ============================================================
-- Section 4: Payment method summary
-- Business question:
-- What payment methods appear in ERA records?
-- ============================================================

SELECT
    payment_method,

    COUNT(*) AS era_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM era), 2) AS percent_of_era_records,

    ROUND(SUM(paid_amount), 2) AS total_paid_amount,
    ROUND(AVG(paid_amount), 2) AS avg_paid_amount
FROM era
GROUP BY payment_method
ORDER BY era_count DESC;


-- Expected:
-- No Payment = denied claims
-- EFT / Check / Virtual Card = paid claims


-- ============================================================
-- Section 5: ERA lag bucket summary
-- Business question:
-- How many ERA records fall into each turnaround-time bucket?
-- ============================================================

WITH era_lag AS (
    SELECT
        er.era_id,
        er.claim_id,
        DATEDIFF(er.era_date, c.claim_submit_date) AS era_lag_days,
        er.paid_amount,
        er.adjustment_amount
    FROM era er
    INNER JOIN claims c
        ON er.claim_id = c.claim_id
)

SELECT
    CASE
        WHEN era_lag_days <= 7 THEN '0-7 days'
        WHEN era_lag_days <= 14 THEN '8-14 days'
        WHEN era_lag_days <= 21 THEN '15-21 days'
        WHEN era_lag_days <= 30 THEN '22-30 days'
        ELSE '31+ days'
    END AS era_lag_bucket,

    COUNT(*) AS era_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM era), 2) AS percent_of_era_records,

    ROUND(SUM(paid_amount), 2) AS total_paid_amount,
    ROUND(SUM(adjustment_amount), 2) AS total_adjustment_amount,
    ROUND(AVG(era_lag_days), 2) AS avg_lag_within_bucket
FROM era_lag
GROUP BY
    CASE
        WHEN era_lag_days <= 7 THEN '0-7 days'
        WHEN era_lag_days <= 14 THEN '8-14 days'
        WHEN era_lag_days <= 21 THEN '15-21 days'
        WHEN era_lag_days <= 30 THEN '22-30 days'
        ELSE '31+ days'
    END
ORDER BY
    MIN(era_lag_days);


-- Expected:
-- 0-7 days = 21
-- 8-14 days = 109
-- 15-21 days = 120
-- 22-30 days = 136
-- 31+ days = 64


-- ============================================================
-- Section 6: ERA lag by payer
-- Business question:
-- Which payers have the longest average ERA turnaround time?
-- Join logic:
-- INNER JOIN is used because this query analyzes only claims with ERA records.
-- ============================================================

SELECT
    p.payer_name,
    p.payer_type,

    COUNT(*) AS era_records,

    ROUND(AVG(DATEDIFF(er.era_date, c.claim_submit_date)), 2) AS avg_era_lag_days,
    MIN(DATEDIFF(er.era_date, c.claim_submit_date)) AS min_era_lag_days,
    MAX(DATEDIFF(er.era_date, c.claim_submit_date)) AS max_era_lag_days,

    ROUND(SUM(er.paid_amount), 2) AS total_paid_amount,
    ROUND(SUM(er.adjustment_amount), 2) AS total_adjustment_amount,
    ROUND(AVG(er.paid_amount), 2) AS avg_paid_amount
FROM era er
INNER JOIN claims c
    ON er.claim_id = c.claim_id
INNER JOIN payer p
    ON c.payer_id = p.payer_id
GROUP BY
    p.payer_name,
    p.payer_type
ORDER BY avg_era_lag_days DESC, era_records DESC;


-- Analyst note:
-- Payers with no ERA records will not appear in this query.
-- Section 7 shows all payers, including payers with no ERA records.


-- ============================================================
-- Section 7: ERA coverage by payer
-- Business question:
-- Which payers have claims but few or no ERA records?
-- Join logic:
-- LEFT JOIN is used because we want to keep all claims and see whether ERA exists.
-- ============================================================

SELECT
    p.payer_name,
    p.payer_type,

    COUNT(DISTINCT c.claim_id) AS total_claims,
    COUNT(DISTINCT er.era_id) AS claims_with_era,

    COUNT(DISTINCT c.claim_id) - COUNT(DISTINCT er.era_id) AS claims_without_era,

    ROUND(
        COUNT(DISTINCT er.era_id) * 100.0 / COUNT(DISTINCT c.claim_id),
        2
    ) AS era_coverage_percent,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount,
    ROUND(SUM(COALESCE(er.paid_amount, 0)), 2) AS total_paid_amount
FROM claims c
INNER JOIN payer p
    ON c.payer_id = p.payer_id
LEFT JOIN era er
    ON c.claim_id = er.claim_id
GROUP BY
    p.payer_name,
    p.payer_type
ORDER BY era_coverage_percent ASC, claims_without_era DESC;


-- This query intentionally uses LEFT JOIN.
-- It answers: Which claims do not have ERA?


-- ============================================================
-- Section 8: Claims without ERA by claim status
-- Business question:
-- Which claim statuses make up claims without ERA records?
-- Join logic:
-- LEFT JOIN + WHERE er.claim_id IS NULL finds claims missing an ERA match.
-- ============================================================

SELECT
    c.claim_status,

    COUNT(*) AS claims_without_era,
    ROUND(COUNT(*) * 100.0 / (
        SELECT COUNT(*)
        FROM claims c2
        LEFT JOIN era er2
            ON c2.claim_id = er2.claim_id
        WHERE er2.claim_id IS NULL
    ), 2) AS percent_of_claims_without_era,

    ROUND(SUM(c.billed_amount), 2) AS billed_amount_without_era
FROM claims c
LEFT JOIN era er
    ON c.claim_id = er.claim_id
WHERE er.claim_id IS NULL
GROUP BY c.claim_status
ORDER BY claims_without_era DESC;


-- Expected:
-- Claims without ERA should be Submitted, Pending, and Rejected.


-- ============================================================
-- Section 9: Claims without ERA by payer
-- Business question:
-- Which payers have the most claims without ERA records?
-- ============================================================

SELECT
    p.payer_name,
    p.payer_type,

    COUNT(*) AS claims_without_era,
    ROUND(SUM(c.billed_amount), 2) AS billed_amount_without_era
FROM claims c
INNER JOIN payer p
    ON c.payer_id = p.payer_id
LEFT JOIN era er
    ON c.claim_id = er.claim_id
WHERE er.claim_id IS NULL
GROUP BY
    p.payer_name,
    p.payer_type
ORDER BY claims_without_era DESC, billed_amount_without_era DESC;


-- ============================================================
-- Section 10: High-lag ERA records
-- Business question:
-- Which ERA records took more than 21 days after claim submission?
-- ============================================================

SELECT
    er.era_id,
    c.claim_id,
    c.claim_status,
    c.claim_submit_date,
    er.era_date,

    DATEDIFF(er.era_date, c.claim_submit_date) AS era_lag_days,

    p.payer_name,
    p.payer_type,

    pr.practice_name,
    pr.specialty,

    e.enrollment_type,
    e.current_status AS enrollment_status,
    e.blocker_reason,
    e.era_ready_flag,

    c.billed_amount,
    er.paid_amount,
    er.adjustment_amount,
    er.patient_responsibility,
    er.era_status
FROM era er
INNER JOIN claims c
    ON er.claim_id = c.claim_id
INNER JOIN payer p
    ON c.payer_id = p.payer_id
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
WHERE DATEDIFF(er.era_date, c.claim_submit_date) > 21
ORDER BY era_lag_days DESC, er.paid_amount DESC
LIMIT 100;


-- Expected:
-- ERA records over 21 days = 200


-- ============================================================
-- Section 11: ERA lag by enrollment readiness
-- Business question:
-- Are ERA lag patterns different based on enrollment readiness?
-- ============================================================

SELECT
    e.current_status AS enrollment_status,
    e.action_required_flag,
    e.era_ready_flag,

    COUNT(*) AS era_records,

    ROUND(AVG(DATEDIFF(er.era_date, c.claim_submit_date)), 2) AS avg_era_lag_days,
    MIN(DATEDIFF(er.era_date, c.claim_submit_date)) AS min_era_lag_days,
    MAX(DATEDIFF(er.era_date, c.claim_submit_date)) AS max_era_lag_days,

    ROUND(SUM(er.paid_amount), 2) AS total_paid_amount,
    ROUND(SUM(er.adjustment_amount), 2) AS total_adjustment_amount
FROM era er
INNER JOIN claims c
    ON er.claim_id = c.claim_id
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
GROUP BY
    e.current_status,
    e.action_required_flag,
    e.era_ready_flag
ORDER BY avg_era_lag_days DESC, era_records DESC;


-- ============================================================
-- Section 12: ERA lag by enrollment blocker reason
-- Business question:
-- Which enrollment blockers are associated with longer ERA turnaround?
-- ============================================================

SELECT
    e.blocker_reason,

    COUNT(*) AS era_records,

    ROUND(AVG(DATEDIFF(er.era_date, c.claim_submit_date)), 2) AS avg_era_lag_days,
    MIN(DATEDIFF(er.era_date, c.claim_submit_date)) AS min_era_lag_days,
    MAX(DATEDIFF(er.era_date, c.claim_submit_date)) AS max_era_lag_days,

    ROUND(SUM(er.paid_amount), 2) AS total_paid_amount,
    ROUND(SUM(er.adjustment_amount), 2) AS total_adjustment_amount
FROM era er
INNER JOIN claims c
    ON er.claim_id = c.claim_id
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
GROUP BY e.blocker_reason
ORDER BY avg_era_lag_days DESC, era_records DESC;


-- ============================================================
-- Section 13: ERA readiness risk on paid/denied claims
-- Business question:
-- Are there paid or denied claims tied to enrollment records that are not ERA-ready?
-- Why it matters:
-- A record may have claims activity, but ERA readiness issues can still create remittance or posting risk.
-- ============================================================

SELECT
    e.era_ready_flag,
    e.current_status AS enrollment_status,
    e.blocker_reason,

    COUNT(*) AS paid_or_denied_claims,
    COUNT(DISTINCT er.era_id) AS era_records,

    ROUND(SUM(c.billed_amount), 2) AS billed_amount,
    ROUND(SUM(COALESCE(er.paid_amount, 0)), 2) AS paid_amount,
    ROUND(SUM(COALESCE(er.adjustment_amount, 0)), 2) AS adjustment_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
LEFT JOIN era er
    ON c.claim_id = er.claim_id
WHERE c.claim_status IN ('Paid', 'Denied')
GROUP BY
    e.era_ready_flag,
    e.current_status,
    e.blocker_reason
ORDER BY paid_or_denied_claims DESC, billed_amount DESC;


-- ============================================================
-- Section 14: Payment summary by provider/practice
-- Business question:
-- Which practices have the highest ERA paid amount?
-- ============================================================

SELECT
    pr.practice_name,
    pr.specialty,
    pr.state,

    COUNT(DISTINCT er.era_id) AS era_records,

    ROUND(SUM(er.paid_amount), 2) AS total_paid_amount,
    ROUND(SUM(er.adjustment_amount), 2) AS total_adjustment_amount,
    ROUND(SUM(er.patient_responsibility), 2) AS total_patient_responsibility,

    ROUND(AVG(DATEDIFF(er.era_date, c.claim_submit_date)), 2) AS avg_era_lag_days
FROM era er
INNER JOIN claims c
    ON er.claim_id = c.claim_id
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
GROUP BY
    pr.practice_name,
    pr.specialty,
    pr.state
ORDER BY total_paid_amount DESC
LIMIT 25;


-- ============================================================
-- Section 15: Monthly ERA volume and payment trend
-- Business question:
-- How do ERA volume and payment amount trend by ERA month?
-- ============================================================

SELECT
    DATE_FORMAT(er.era_date, '%Y-%m') AS era_month,

    COUNT(*) AS era_records,

    ROUND(SUM(er.paid_amount), 2) AS total_paid_amount,
    ROUND(SUM(er.adjustment_amount), 2) AS total_adjustment_amount,
    ROUND(SUM(er.patient_responsibility), 2) AS total_patient_responsibility,

    ROUND(AVG(DATEDIFF(er.era_date, c.claim_submit_date)), 2) AS avg_era_lag_days
FROM era er
INNER JOIN claims c
    ON er.claim_id = c.claim_id
GROUP BY DATE_FORMAT(er.era_date, '%Y-%m')
ORDER BY era_month;


-- ============================================================
-- Section 16: ERA payment reconciliation check
-- Business question:
-- Are there ERA records where paid + adjustment + patient responsibility
-- does not reconcile to billed amount?
-- Expected result:
-- No rows.
-- ============================================================

SELECT
    er.era_id,
    c.claim_id,
    c.billed_amount,
    er.paid_amount,
    er.adjustment_amount,
    er.patient_responsibility,

    ROUND(
        er.paid_amount + er.adjustment_amount + er.patient_responsibility,
        2
    ) AS era_components_total,

    ROUND(
        (er.paid_amount + er.adjustment_amount + er.patient_responsibility) - c.billed_amount,
        2
    ) AS difference_amount
FROM era er
INNER JOIN claims c
    ON er.claim_id = c.claim_id
WHERE ABS(
    (er.paid_amount + er.adjustment_amount + er.patient_responsibility) - c.billed_amount
) > 0.05;


-- ============================================================
-- Section 17: ERA KPI summary for documentation
-- Business question:
-- What ERA KPIs should be documented in the project README?
-- ============================================================

WITH era_claims AS (
    SELECT
        er.era_id,
        er.claim_id,
        c.claim_submit_date,
        er.era_date,
        DATEDIFF(er.era_date, c.claim_submit_date) AS era_lag_days,
        er.paid_amount,
        er.adjustment_amount,
        er.patient_responsibility
    FROM era er
    INNER JOIN claims c
        ON er.claim_id = c.claim_id
)

SELECT
    'ERA KPI Summary' AS report_name,

    COUNT(*) AS total_era_records,
    COUNT(DISTINCT claim_id) AS claims_with_era,

    (
        SELECT COUNT(*)
        FROM claims c
        LEFT JOIN era er
            ON c.claim_id = er.claim_id
        WHERE er.claim_id IS NULL
    ) AS claims_without_era,

    ROUND(SUM(paid_amount), 2) AS total_paid_amount,
    ROUND(SUM(adjustment_amount), 2) AS total_adjustment_amount,
    ROUND(SUM(patient_responsibility), 2) AS total_patient_responsibility,

    ROUND(AVG(era_lag_days), 2) AS avg_era_lag_days,
    MIN(era_lag_days) AS min_era_lag_days,
    MAX(era_lag_days) AS max_era_lag_days,

    SUM(CASE WHEN era_lag_days > 21 THEN 1 ELSE 0 END) AS era_records_over_21_days,
    ROUND(
        SUM(CASE WHEN era_lag_days > 21 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS percent_era_records_over_21_days
FROM era_claims;


-- ============================================================
-- Analyst Notes
-- ============================================================

-- Key interpretation:
-- ERA analysis should focus on both payment amount and turnaround time.
-- Claims may be submitted successfully, but delayed ERA receipt can still create
-- remittance posting delays and follow-up work.

-- Important join rule used in this script:
-- INNER JOIN is used when analyzing claims that have ERA records.
-- LEFT JOIN + WHERE er.claim_id IS NULL is used only when identifying claims missing ERA.

-- Operational takeaway:
-- Claims without ERA are not always errors; submitted, pending, and rejected claims may not have ERA yet.
-- However, payer-level ERA coverage and high ERA lag should be monitored because they can point to
-- payer processing delays, ERA enrollment gaps, or clearinghouse routing issues.

-- My observation:
-- 200 of 450 ERA records are over 21 days, which suggests remittance turnaround should be monitored by payer and enrollment readiness status

-- Follow-up question:
-- which payer has both high claims-without ERA volume and high average ERA lag