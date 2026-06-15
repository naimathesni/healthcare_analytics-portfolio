-- ============================================================
-- Project: Healthcare Claims & ERA SQL Analysis
-- Script: 10_cte_payer_performance.sql
-- Topic: CTE-based payer performance analysis
-- SQL dialect: MySQL
-- Purpose:
--   Use Common Table Expressions to build payer-level performance
--   metrics across claims, ERA, denials, and enrollment readiness.
-- ============================================================

USE healthcare_claims_era;


-- ============================================================
-- Section 1: Basic payer claim summary using a CTE
-- Business question:
-- What is the claim status distribution by payer?
-- ============================================================

WITH claim_summary AS (
    SELECT
        payer_id,

        COUNT(*) AS total_claims,

        SUM(CASE WHEN claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
        SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
        SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
        SUM(CASE WHEN claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
        SUM(CASE WHEN claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

        ROUND(SUM(billed_amount), 2) AS total_billed_amount,
        ROUND(SUM(COALESCE(allowed_amount, 0)), 2) AS total_allowed_amount
    FROM claims
    GROUP BY payer_id
)

SELECT
    p.payer_name,
    p.payer_type,

    cs.total_claims,
    cs.paid_claims,
    cs.denied_claims,
    cs.rejected_claims,
    cs.pending_claims,
    cs.submitted_claims,

    ROUND(cs.paid_claims * 100.0 / NULLIF(cs.total_claims, 0), 2) AS paid_rate_percent,
    ROUND(cs.denied_claims * 100.0 / NULLIF(cs.total_claims, 0), 2) AS denial_rate_percent,
    ROUND(cs.rejected_claims * 100.0 / NULLIF(cs.total_claims, 0), 2) AS rejection_rate_percent,

    cs.total_billed_amount,
    cs.total_allowed_amount
FROM claim_summary cs
INNER JOIN payer p
    ON cs.payer_id = p.payer_id
ORDER BY cs.rejected_claims DESC, cs.denied_claims DESC;


-- ============================================================
-- Section 2: Full payer performance summary using multiple CTEs
-- Business question:
-- Which payers have the highest claim volume, rejection rate,
-- denial rate, ERA lag, and enrollment-related risk?
-- ============================================================

WITH claim_summary AS (
    SELECT
        payer_id,

        COUNT(*) AS total_claims,

        SUM(CASE WHEN claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
        SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
        SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
        SUM(CASE WHEN claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
        SUM(CASE WHEN claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

        ROUND(SUM(billed_amount), 2) AS total_billed_amount,
        ROUND(SUM(COALESCE(allowed_amount, 0)), 2) AS total_allowed_amount
    FROM claims
    GROUP BY payer_id
),

era_summary AS (
    SELECT
        c.payer_id,

        COUNT(DISTINCT er.era_id) AS era_records,
        COUNT(DISTINCT er.claim_id) AS claims_with_era,

        ROUND(SUM(er.paid_amount), 2) AS total_paid_amount,
        ROUND(SUM(er.adjustment_amount), 2) AS total_adjustment_amount,
        ROUND(SUM(er.patient_responsibility), 2) AS total_patient_responsibility,

        ROUND(AVG(DATEDIFF(er.era_date, c.claim_submit_date)), 2) AS avg_era_lag_days,
        MIN(DATEDIFF(er.era_date, c.claim_submit_date)) AS min_era_lag_days,
        MAX(DATEDIFF(er.era_date, c.claim_submit_date)) AS max_era_lag_days
    FROM era er
    INNER JOIN claims c
        ON er.claim_id = c.claim_id
    GROUP BY c.payer_id
),

denial_summary AS (
    SELECT
        c.payer_id,

        COUNT(*) AS total_denials,

        SUM(CASE WHEN d.preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials,

        SUM(CASE WHEN d.denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) AS enrollment_configuration_denials,

        ROUND(SUM(d.denied_amount), 2) AS total_denied_amount,
        ROUND(AVG(d.denied_amount), 2) AS avg_denied_amount
    FROM denials d
    INNER JOIN claims c
        ON d.claim_id = c.claim_id
    GROUP BY c.payer_id
),

enrollment_summary AS (
    SELECT
        payer_id,

        COUNT(*) AS enrollment_records,

        SUM(CASE WHEN current_status = 'Ready' THEN 1 ELSE 0 END) AS ready_enrollment_records,
        SUM(CASE WHEN current_status = 'Pending' THEN 1 ELSE 0 END) AS pending_enrollment_records,
        SUM(CASE WHEN current_status = 'Blocked' THEN 1 ELSE 0 END) AS blocked_enrollment_records,

        SUM(CASE WHEN action_required_flag = 'Yes' THEN 1 ELSE 0 END) AS action_required_enrollment_records,

        SUM(CASE WHEN claims_ready_flag = 'Not Ready' THEN 1 ELSE 0 END) AS claims_not_ready_records,
        SUM(CASE WHEN era_ready_flag = 'Not Ready' THEN 1 ELSE 0 END) AS era_not_ready_records,

        SUM(CASE WHEN npi_match_status = 'NPI Mismatch' THEN 1 ELSE 0 END) AS npi_mismatch_records,

        SUM(
            CASE
                WHEN clearinghouse_portal_updated = 'No'
                  OR clearinghouse_configuration_status <> 'Completed'
                  OR blocker_reason = 'Clearinghouse portal not updated'
                THEN 1
                ELSE 0
            END
        ) AS clearinghouse_gap_records
    FROM enrollment
    GROUP BY payer_id
)

SELECT
    p.payer_name,
    p.payer_type,

    cs.total_claims,
    cs.paid_claims,
    cs.denied_claims,
    cs.rejected_claims,
    cs.pending_claims,
    cs.submitted_claims,

    ROUND(cs.paid_claims * 100.0 / NULLIF(cs.total_claims, 0), 2) AS paid_rate_percent,
    ROUND(cs.denied_claims * 100.0 / NULLIF(cs.total_claims, 0), 2) AS denial_rate_percent,
    ROUND(cs.rejected_claims * 100.0 / NULLIF(cs.total_claims, 0), 2) AS rejection_rate_percent,

    cs.total_billed_amount,
    cs.total_allowed_amount,

    COALESCE(es.era_records, 0) AS era_records,
    COALESCE(es.claims_with_era, 0) AS claims_with_era,
    cs.total_claims - COALESCE(es.claims_with_era, 0) AS claims_without_era,

    ROUND(COALESCE(es.claims_with_era, 0) * 100.0 / NULLIF(cs.total_claims, 0), 2) AS era_coverage_percent,

    COALESCE(es.total_paid_amount, 0) AS total_paid_amount,
    COALESCE(es.total_adjustment_amount, 0) AS total_adjustment_amount,
    COALESCE(es.total_patient_responsibility, 0) AS total_patient_responsibility,
    es.avg_era_lag_days,
    es.min_era_lag_days,
    es.max_era_lag_days,

    COALESCE(ds.total_denials, 0) AS total_denials,
    COALESCE(ds.preventable_denials, 0) AS preventable_denials,
    COALESCE(ds.enrollment_configuration_denials, 0) AS enrollment_configuration_denials,
    COALESCE(ds.total_denied_amount, 0) AS total_denied_amount,
    COALESCE(ds.avg_denied_amount, 0) AS avg_denied_amount,

    COALESCE(en.enrollment_records, 0) AS enrollment_records,
    COALESCE(en.ready_enrollment_records, 0) AS ready_enrollment_records,
    COALESCE(en.pending_enrollment_records, 0) AS pending_enrollment_records,
    COALESCE(en.blocked_enrollment_records, 0) AS blocked_enrollment_records,
    COALESCE(en.action_required_enrollment_records, 0) AS action_required_enrollment_records,
    COALESCE(en.claims_not_ready_records, 0) AS claims_not_ready_records,
    COALESCE(en.era_not_ready_records, 0) AS era_not_ready_records,
    COALESCE(en.npi_mismatch_records, 0) AS npi_mismatch_records,
    COALESCE(en.clearinghouse_gap_records, 0) AS clearinghouse_gap_records
FROM payer p
LEFT JOIN claim_summary cs
    ON p.payer_id = cs.payer_id
LEFT JOIN era_summary es
    ON p.payer_id = es.payer_id
LEFT JOIN denial_summary ds
    ON p.payer_id = ds.payer_id
LEFT JOIN enrollment_summary en
    ON p.payer_id = en.payer_id
ORDER BY
    cs.rejected_claims DESC,
    ds.total_denials DESC,
    es.avg_era_lag_days DESC;


-- ============================================================
-- Section 3: Payer performance score using CTEs
-- Business question:
-- Which payers should operations prioritize first?
-- Logic:
-- Higher score means more operational risk based on rejections,
-- denials, ERA lag, enrollment blockers, and denied amount.
-- ============================================================

WITH claim_summary AS (
    SELECT
        payer_id,
        COUNT(*) AS total_claims,
        SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
        SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
        ROUND(SUM(CASE WHEN claim_status IN ('Denied', 'Rejected') THEN billed_amount ELSE 0 END), 2) AS issue_billed_amount
    FROM claims
    GROUP BY payer_id
),

era_summary AS (
    SELECT
        c.payer_id,
        ROUND(AVG(DATEDIFF(er.era_date, c.claim_submit_date)), 2) AS avg_era_lag_days
    FROM era er
    INNER JOIN claims c
        ON er.claim_id = c.claim_id
    GROUP BY c.payer_id
),

denial_summary AS (
    SELECT
        c.payer_id,
        COUNT(*) AS total_denials,
        SUM(CASE WHEN d.preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials,
        SUM(CASE WHEN d.denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) AS enrollment_configuration_denials,
        ROUND(SUM(d.denied_amount), 2) AS total_denied_amount
    FROM denials d
    INNER JOIN claims c
        ON d.claim_id = c.claim_id
    GROUP BY c.payer_id
),

enrollment_summary AS (
    SELECT
        payer_id,
        SUM(CASE WHEN action_required_flag = 'Yes' THEN 1 ELSE 0 END) AS action_required_enrollment_records,
        SUM(CASE WHEN claims_ready_flag = 'Not Ready' THEN 1 ELSE 0 END) AS claims_not_ready_records,
        SUM(CASE WHEN npi_match_status = 'NPI Mismatch' THEN 1 ELSE 0 END) AS npi_mismatch_records
    FROM enrollment
    GROUP BY payer_id
),

payer_metrics AS (
    SELECT
        p.payer_name,
        p.payer_type,

        COALESCE(cs.total_claims, 0) AS total_claims,
        COALESCE(cs.denied_claims, 0) AS denied_claims,
        COALESCE(cs.rejected_claims, 0) AS rejected_claims,
        COALESCE(cs.issue_billed_amount, 0) AS issue_billed_amount,

        COALESCE(es.avg_era_lag_days, 0) AS avg_era_lag_days,

        COALESCE(ds.total_denials, 0) AS total_denials,
        COALESCE(ds.preventable_denials, 0) AS preventable_denials,
        COALESCE(ds.enrollment_configuration_denials, 0) AS enrollment_configuration_denials,
        COALESCE(ds.total_denied_amount, 0) AS total_denied_amount,

        COALESCE(en.action_required_enrollment_records, 0) AS action_required_enrollment_records,
        COALESCE(en.claims_not_ready_records, 0) AS claims_not_ready_records,
        COALESCE(en.npi_mismatch_records, 0) AS npi_mismatch_records
    FROM payer p
    LEFT JOIN claim_summary cs
        ON p.payer_id = cs.payer_id
    LEFT JOIN era_summary es
        ON p.payer_id = es.payer_id
    LEFT JOIN denial_summary ds
        ON p.payer_id = ds.payer_id
    LEFT JOIN enrollment_summary en
        ON p.payer_id = en.payer_id
)

SELECT
    payer_name,
    payer_type,

    total_claims,
    rejected_claims,
    denied_claims,
    total_denials,
    preventable_denials,
    enrollment_configuration_denials,
    action_required_enrollment_records,
    claims_not_ready_records,
    npi_mismatch_records,
    avg_era_lag_days,
    issue_billed_amount,
    total_denied_amount,

    ROUND(
        (
            rejected_claims * 2.0
            + denied_claims * 1.5
            + enrollment_configuration_denials * 2.5
            + preventable_denials * 1.5
            + action_required_enrollment_records * 1.0
            + claims_not_ready_records * 1.5
            + npi_mismatch_records * 2.0
            + avg_era_lag_days * 0.5
            + total_denied_amount / 1000
        ),
        2
    ) AS payer_operational_priority_score
FROM payer_metrics
ORDER BY payer_operational_priority_score DESC;


-- ============================================================
-- Section 4: Claims readiness impact by payer using CTEs
-- Business question:
-- Which payers have the most claims submitted while enrollment was not claims-ready?
-- ============================================================

WITH not_ready_claims AS (
    SELECT
        c.claim_id,
        c.payer_id,
        c.claim_status,
        c.billed_amount,
        e.claims_ready_flag,
        e.current_status AS enrollment_status,
        e.blocker_reason
    FROM claims c
    INNER JOIN enrollment e
        ON c.enrollment_id = e.enrollment_id
    WHERE e.enrollment_type IN ('Claims', 'Claims and ERA')
      AND e.claims_ready_flag <> 'Ready'
),

payer_not_ready_summary AS (
    SELECT
        payer_id,

        COUNT(*) AS claims_submitted_while_not_ready,

        SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
        SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
        SUM(CASE WHEN claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
        SUM(CASE WHEN claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

        ROUND(SUM(billed_amount), 2) AS billed_amount_at_risk
    FROM not_ready_claims
    GROUP BY payer_id
)

SELECT
    p.payer_name,
    p.payer_type,

    nrs.claims_submitted_while_not_ready,
    nrs.rejected_claims,
    nrs.denied_claims,
    nrs.pending_claims,
    nrs.submitted_claims,

    ROUND(nrs.rejected_claims * 100.0 / NULLIF(nrs.claims_submitted_while_not_ready, 0), 2) AS rejection_rate_within_not_ready_claims,
    ROUND(nrs.denied_claims * 100.0 / NULLIF(nrs.claims_submitted_while_not_ready, 0), 2) AS denial_rate_within_not_ready_claims,

    nrs.billed_amount_at_risk
FROM payer_not_ready_summary nrs
INNER JOIN payer p
    ON nrs.payer_id = p.payer_id
ORDER BY nrs.billed_amount_at_risk DESC, nrs.rejected_claims DESC;


-- ============================================================
-- Section 5: Top blocker reasons by payer using CTEs
-- Business question:
-- Which enrollment blockers are driving claim issues for each payer?
-- ============================================================

WITH claim_issue_base AS (
    SELECT
        c.claim_id,
        c.payer_id,
        c.claim_status,
        c.billed_amount,
        e.blocker_reason
    FROM claims c
    INNER JOIN enrollment e
        ON c.enrollment_id = e.enrollment_id
    WHERE c.claim_status IN ('Rejected', 'Denied')
      AND e.blocker_reason <> 'No blocker'
),

blocker_summary AS (
    SELECT
        payer_id,
        blocker_reason,

        COUNT(*) AS issue_claims,
        SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
        SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
        ROUND(SUM(billed_amount), 2) AS issue_billed_amount
    FROM claim_issue_base
    GROUP BY
        payer_id,
        blocker_reason
)

SELECT
    p.payer_name,
    p.payer_type,
    bs.blocker_reason,

    bs.issue_claims,
    bs.rejected_claims,
    bs.denied_claims,
    bs.issue_billed_amount
FROM blocker_summary bs
INNER JOIN payer p
    ON bs.payer_id = p.payer_id
ORDER BY
    p.payer_name,
    bs.issue_claims DESC,
    bs.issue_billed_amount DESC;


-- ============================================================
-- Section 6: Payer ERA performance using CTEs
-- Business question:
-- Which payers have weak ERA coverage or high average ERA lag?
-- ============================================================

WITH claim_counts AS (
    SELECT
        payer_id,
        COUNT(*) AS total_claims
    FROM claims
    GROUP BY payer_id
),

era_counts AS (
    SELECT
        c.payer_id,

        COUNT(DISTINCT er.era_id) AS era_records,
        COUNT(DISTINCT er.claim_id) AS claims_with_era,

        ROUND(AVG(DATEDIFF(er.era_date, c.claim_submit_date)), 2) AS avg_era_lag_days,

        SUM(CASE WHEN DATEDIFF(er.era_date, c.claim_submit_date) > 21 THEN 1 ELSE 0 END) AS era_records_over_21_days,

        ROUND(SUM(er.paid_amount), 2) AS total_paid_amount
    FROM era er
    INNER JOIN claims c
        ON er.claim_id = c.claim_id
    GROUP BY c.payer_id
)

SELECT
    p.payer_name,
    p.payer_type,

    cc.total_claims,
    COALESCE(ec.claims_with_era, 0) AS claims_with_era,
    cc.total_claims - COALESCE(ec.claims_with_era, 0) AS claims_without_era,

    ROUND(COALESCE(ec.claims_with_era, 0) * 100.0 / NULLIF(cc.total_claims, 0), 2) AS era_coverage_percent,

    COALESCE(ec.avg_era_lag_days, 0) AS avg_era_lag_days,
    COALESCE(ec.era_records_over_21_days, 0) AS era_records_over_21_days,
    COALESCE(ec.total_paid_amount, 0) AS total_paid_amount
FROM claim_counts cc
INNER JOIN payer p
    ON cc.payer_id = p.payer_id
LEFT JOIN era_counts ec
    ON cc.payer_id = ec.payer_id
ORDER BY
    era_coverage_percent ASC,
    avg_era_lag_days DESC,
    claims_without_era DESC;


-- ============================================================
-- Section 7: Payer performance KPI summary for documentation
-- Business question:
-- What payer-level metrics should be documented in the README?
-- ============================================================

WITH claim_summary AS (
    SELECT
        payer_id,

        COUNT(*) AS total_claims,
        SUM(CASE WHEN claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
        SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
        SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,

        ROUND(SUM(billed_amount), 2) AS total_billed_amount
    FROM claims
    GROUP BY payer_id
),

era_summary AS (
    SELECT
        c.payer_id,
        COUNT(DISTINCT er.era_id) AS era_records,
        ROUND(SUM(er.paid_amount), 2) AS total_paid_amount,
        ROUND(AVG(DATEDIFF(er.era_date, c.claim_submit_date)), 2) AS avg_era_lag_days
    FROM era er
    INNER JOIN claims c
        ON er.claim_id = c.claim_id
    GROUP BY c.payer_id
),

denial_summary AS (
    SELECT
        c.payer_id,
        COUNT(*) AS total_denials,
        SUM(CASE WHEN d.denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) AS enrollment_configuration_denials,
        ROUND(SUM(d.denied_amount), 2) AS total_denied_amount
    FROM denials d
    INNER JOIN claims c
        ON d.claim_id = c.claim_id
    GROUP BY c.payer_id
),

enrollment_summary AS (
    SELECT
        payer_id,
        COUNT(*) AS enrollment_records,
        SUM(CASE WHEN action_required_flag = 'Yes' THEN 1 ELSE 0 END) AS action_required_enrollment_records
    FROM enrollment
    GROUP BY payer_id
)

SELECT
    p.payer_name,
    p.payer_type,

    cs.total_claims,
    cs.paid_claims,
    cs.denied_claims,
    cs.rejected_claims,

    ROUND(cs.denied_claims * 100.0 / NULLIF(cs.total_claims, 0), 2) AS denial_rate_percent,
    ROUND(cs.rejected_claims * 100.0 / NULLIF(cs.total_claims, 0), 2) AS rejection_rate_percent,

    cs.total_billed_amount,

    COALESCE(es.era_records, 0) AS era_records,
    COALESCE(es.total_paid_amount, 0) AS total_paid_amount,
    COALESCE(es.avg_era_lag_days, 0) AS avg_era_lag_days,

    COALESCE(ds.total_denials, 0) AS total_denials,
    COALESCE(ds.enrollment_configuration_denials, 0) AS enrollment_configuration_denials,
    COALESCE(ds.total_denied_amount, 0) AS total_denied_amount,

    COALESCE(en.enrollment_records, 0) AS enrollment_records,
    COALESCE(en.action_required_enrollment_records, 0) AS action_required_enrollment_records
FROM payer p
LEFT JOIN claim_summary cs
    ON p.payer_id = cs.payer_id
LEFT JOIN era_summary es
    ON p.payer_id = es.payer_id
LEFT JOIN denial_summary ds
    ON p.payer_id = ds.payer_id
LEFT JOIN enrollment_summary en
    ON p.payer_id = en.payer_id
ORDER BY cs.rejected_claims DESC, cs.denied_claims DESC;


-- ============================================================
-- Analyst Notes
-- ============================================================

-- Key interpretation:
-- CTEs make payer performance analysis easier to read by separating
-- claim metrics, ERA metrics, denial metrics, and enrollment metrics
-- before joining them into one final payer-level view.

-- Most important CTE pattern:
-- Build one CTE per business area:
--   1. claim_summary
--   2. era_summary
--   3. denial_summary
--   4. enrollment_summary
-- Then combine them by payer_id in the final SELECT.

-- Operational takeaway:
-- A payer should not be judged only by denial rate.
-- A better payer performance view includes rejection rate, ERA lag,
-- claims without ERA, denied amount, preventable denials, and enrollment readiness issues.

-- My observation:
-- Payer Performance is better understood when claims, ERA, denails, and enrollment readiness are combined instead of reveiwed seperately

-- Follow-up question:
-- which payer has the worst combination of rejection rate, ERA lag, and acion required enrollment records?