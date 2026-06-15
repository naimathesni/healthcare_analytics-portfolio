-- ============================================================
-- Project: Healthcare Claims & ERA SQL Analysis
-- Script: 11_window_functions.sql
-- Topic: Window functions for ranking, running totals, percent of total, and trend analysis
-- SQL dialect: MySQL
-- Purpose:
--   Use ROW_NUMBER, RANK, DENSE_RANK, SUM OVER, AVG OVER,
--   COUNT OVER, and LAG to analyze payer, provider, denial,
--   ERA, and enrollment performance.
-- ============================================================

USE healthcare_claims_era;


-- ============================================================
-- Section 1: Rank payers by total claims
-- Business question:
-- Which payers have the highest claim volume?
-- ============================================================

WITH payer_claims AS (
    SELECT
        p.payer_name,
        p.payer_type,
        COUNT(*) AS total_claims,
        ROUND(SUM(c.billed_amount), 2) AS total_billed_amount
    FROM claims c
    INNER JOIN payer p
        ON c.payer_id = p.payer_id
    GROUP BY
        p.payer_name,
        p.payer_type
)

SELECT
    payer_name,
    payer_type,
    total_claims,
    total_billed_amount,

    RANK() OVER (
        ORDER BY total_claims DESC
    ) AS claim_volume_rank,

    DENSE_RANK() OVER (
        ORDER BY total_claims DESC
    ) AS dense_claim_volume_rank
FROM payer_claims
ORDER BY claim_volume_rank;


-- ============================================================
-- Section 2: Rank payers by rejection rate
-- Business question:
-- Which payers have the highest rejection rate?
-- ============================================================

WITH payer_claim_summary AS (
    SELECT
        p.payer_name,
        p.payer_type,

        COUNT(*) AS total_claims,

        SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,

        ROUND(
            SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
            2
        ) AS rejection_rate_percent
    FROM claims c
    INNER JOIN payer p
        ON c.payer_id = p.payer_id
    GROUP BY
        p.payer_name,
        p.payer_type
)

SELECT
    payer_name,
    payer_type,
    total_claims,
    rejected_claims,
    rejection_rate_percent,

    RANK() OVER (
        ORDER BY rejection_rate_percent DESC
    ) AS rejection_rate_rank
FROM payer_claim_summary
ORDER BY rejection_rate_rank, payer_name;


-- ============================================================
-- Section 3: Top 3 payers by rejection rate
-- Business question:
-- Which payers should be reviewed first for claim rejection issues?
-- ============================================================

WITH payer_claim_summary AS (
    SELECT
        p.payer_name,
        p.payer_type,

        COUNT(*) AS total_claims,

        SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,

        ROUND(
            SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
            2
        ) AS rejection_rate_percent
    FROM claims c
    INNER JOIN payer p
        ON c.payer_id = p.payer_id
    GROUP BY
        p.payer_name,
        p.payer_type
),

ranked_payers AS (
    SELECT
        payer_name,
        payer_type,
        total_claims,
        rejected_claims,
        rejection_rate_percent,

        RANK() OVER (
            ORDER BY rejection_rate_percent DESC
        ) AS rejection_rate_rank
    FROM payer_claim_summary
)

SELECT
    payer_name,
    payer_type,
    total_claims,
    rejected_claims,
    rejection_rate_percent,
    rejection_rate_rank
FROM ranked_payers
WHERE rejection_rate_rank <= 3
ORDER BY rejection_rate_rank, payer_name;


-- ============================================================
-- Section 4: Rank providers/practices by rejected claims
-- Business question:
-- Which practices have the most rejected claims?
-- ============================================================

WITH provider_claim_summary AS (
    SELECT
        pr.practice_name,
        pr.specialty,
        pr.state,

        COUNT(*) AS total_claims,

        SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
        SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

        ROUND(SUM(c.billed_amount), 2) AS total_billed_amount
    FROM claims c
    INNER JOIN provider pr
        ON c.provider_id = pr.provider_id
    GROUP BY
        pr.practice_name,
        pr.specialty,
        pr.state
)

SELECT
    practice_name,
    specialty,
    state,
    total_claims,
    rejected_claims,
    denied_claims,
    total_billed_amount,

    RANK() OVER (
        ORDER BY rejected_claims DESC
    ) AS rejected_claim_rank,

    RANK() OVER (
        ORDER BY total_billed_amount DESC
    ) AS billed_amount_rank
FROM provider_claim_summary
ORDER BY rejected_claim_rank, billed_amount_rank
LIMIT 25;


-- ============================================================
-- Section 5: Rank denial categories by count and denied amount
-- Business question:
-- Which denial categories are most common and which have the highest financial impact?
-- ============================================================

WITH denial_category_summary AS (
    SELECT
        denial_category,

        COUNT(*) AS denial_count,
        ROUND(SUM(denied_amount), 2) AS total_denied_amount,
        ROUND(AVG(denied_amount), 2) AS avg_denied_amount
    FROM denials
    GROUP BY denial_category
)

SELECT
    denial_category,
    denial_count,
    total_denied_amount,
    avg_denied_amount,

    RANK() OVER (
        ORDER BY denial_count DESC
    ) AS denial_count_rank,

    RANK() OVER (
        ORDER BY total_denied_amount DESC
    ) AS denied_amount_rank
FROM denial_category_summary
ORDER BY denial_count_rank, denied_amount_rank;


-- ============================================================
-- Section 6: Denial category share of total denials
-- Business question:
-- What percent of total denials does each denial category represent?
-- ============================================================

WITH denial_category_summary AS (
    SELECT
        denial_category,
        COUNT(*) AS denial_count,
        ROUND(SUM(denied_amount), 2) AS total_denied_amount
    FROM denials
    GROUP BY denial_category
)

SELECT
    denial_category,
    denial_count,
    total_denied_amount,

    SUM(denial_count) OVER () AS all_denials,

    ROUND(
        denial_count * 100.0 / SUM(denial_count) OVER (),
        2
    ) AS percent_of_total_denials,

    ROUND(
        total_denied_amount * 100.0 / SUM(total_denied_amount) OVER (),
        2
    ) AS percent_of_total_denied_amount
FROM denial_category_summary
ORDER BY denial_count DESC;


-- ============================================================
-- Section 7: Rank payers within each denial category
-- Business question:
-- For each denial category, which payers contribute the most denials?
-- ============================================================

WITH payer_denial_category AS (
    SELECT
        d.denial_category,
        p.payer_name,
        p.payer_type,

        COUNT(*) AS denial_count,
        ROUND(SUM(d.denied_amount), 2) AS total_denied_amount
    FROM denials d
    INNER JOIN claims c
        ON d.claim_id = c.claim_id
    INNER JOIN payer p
        ON c.payer_id = p.payer_id
    GROUP BY
        d.denial_category,
        p.payer_name,
        p.payer_type
),

ranked_payer_denials AS (
    SELECT
        denial_category,
        payer_name,
        payer_type,
        denial_count,
        total_denied_amount,

        RANK() OVER (
            PARTITION BY denial_category
            ORDER BY denial_count DESC, total_denied_amount DESC
        ) AS payer_rank_within_denial_category
    FROM payer_denial_category
)

SELECT
    denial_category,
    payer_name,
    payer_type,
    denial_count,
    total_denied_amount,
    payer_rank_within_denial_category
FROM ranked_payer_denials
WHERE payer_rank_within_denial_category <= 3
ORDER BY
    denial_category,
    payer_rank_within_denial_category;


-- ============================================================
-- Section 8: Top 3 highest billed claims per payer
-- Business question:
-- What are the highest-dollar claims for each payer?
-- Window function:
-- ROW_NUMBER is used because we want exactly 3 claims per payer.
-- ============================================================

WITH ranked_claims AS (
    SELECT
        c.claim_id,
        c.claim_status,
        c.claim_submit_date,
        c.billed_amount,

        p.payer_name,
        p.payer_type,

        pr.practice_name,
        pr.specialty,

        ROW_NUMBER() OVER (
            PARTITION BY p.payer_name
            ORDER BY c.billed_amount DESC, c.claim_id
        ) AS claim_rank_within_payer
    FROM claims c
    INNER JOIN payer p
        ON c.payer_id = p.payer_id
    INNER JOIN provider pr
        ON c.provider_id = pr.provider_id
)

SELECT
    payer_name,
    payer_type,
    claim_rank_within_payer,
    claim_id,
    claim_status,
    claim_submit_date,
    practice_name,
    specialty,
    billed_amount
FROM ranked_claims
WHERE claim_rank_within_payer <= 3
ORDER BY
    payer_name,
    claim_rank_within_payer;


-- ============================================================
-- Section 9: Top 3 denied claims per payer by denied amount
-- Business question:
-- Which high-dollar denials should each payer review?
-- ============================================================

WITH ranked_denials AS (
    SELECT
        d.denial_id,
        d.denial_category,
        d.denial_reason,
        d.denied_amount,
        d.preventable_flag,

        c.claim_id,
        c.claim_submit_date,

        p.payer_name,
        p.payer_type,

        pr.practice_name,
        pr.specialty,

        ROW_NUMBER() OVER (
            PARTITION BY p.payer_name
            ORDER BY d.denied_amount DESC, d.denial_id
        ) AS denial_rank_within_payer
    FROM denials d
    INNER JOIN claims c
        ON d.claim_id = c.claim_id
    INNER JOIN payer p
        ON c.payer_id = p.payer_id
    INNER JOIN provider pr
        ON c.provider_id = pr.provider_id
)

SELECT
    payer_name,
    payer_type,
    denial_rank_within_payer,
    denial_id,
    claim_id,
    claim_submit_date,
    practice_name,
    specialty,
    denial_category,
    denial_reason,
    denied_amount,
    preventable_flag
FROM ranked_denials
WHERE denial_rank_within_payer <= 3
ORDER BY
    payer_name,
    denial_rank_within_payer;


-- ============================================================
-- Section 10: Top ERA payment records per payer
-- Business question:
-- Which claims generated the highest ERA paid amounts by payer?
-- ============================================================

WITH ranked_era_payments AS (
    SELECT
        er.era_id,
        er.claim_id,
        er.era_date,
        er.paid_amount,
        er.adjustment_amount,
        er.patient_responsibility,

        p.payer_name,
        p.payer_type,

        pr.practice_name,
        pr.specialty,

        ROW_NUMBER() OVER (
            PARTITION BY p.payer_name
            ORDER BY er.paid_amount DESC, er.era_id
        ) AS payment_rank_within_payer
    FROM era er
    INNER JOIN claims c
        ON er.claim_id = c.claim_id
    INNER JOIN payer p
        ON c.payer_id = p.payer_id
    INNER JOIN provider pr
        ON c.provider_id = pr.provider_id
)

SELECT
    payer_name,
    payer_type,
    payment_rank_within_payer,
    era_id,
    claim_id,
    era_date,
    practice_name,
    specialty,
    paid_amount,
    adjustment_amount,
    patient_responsibility
FROM ranked_era_payments
WHERE payment_rank_within_payer <= 3
ORDER BY
    payer_name,
    payment_rank_within_payer;


-- ============================================================
-- Section 11: Monthly claim volume with running total
-- Business question:
-- How does claim volume accumulate over time?
-- ============================================================

WITH monthly_claims AS (
    SELECT
        DATE_FORMAT(claim_submit_date, '%Y-%m') AS submit_month,

        COUNT(*) AS monthly_claims,
        ROUND(SUM(billed_amount), 2) AS monthly_billed_amount
    FROM claims
    GROUP BY DATE_FORMAT(claim_submit_date, '%Y-%m')
)

SELECT
    submit_month,
    monthly_claims,
    monthly_billed_amount,

    SUM(monthly_claims) OVER (
        ORDER BY submit_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_claim_count,

    ROUND(
        SUM(monthly_billed_amount) OVER (
            ORDER BY submit_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS running_billed_amount
FROM monthly_claims
ORDER BY submit_month;


-- ============================================================
-- Section 12: Month-over-month claim volume change
-- Business question:
-- Is claim volume increasing or decreasing month over month?
-- ============================================================

WITH monthly_claims AS (
    SELECT
        DATE_FORMAT(claim_submit_date, '%Y-%m') AS submit_month,
        COUNT(*) AS monthly_claims,
        ROUND(SUM(billed_amount), 2) AS monthly_billed_amount
    FROM claims
    GROUP BY DATE_FORMAT(claim_submit_date, '%Y-%m')
),

monthly_with_lag AS (
    SELECT
        submit_month,
        monthly_claims,
        monthly_billed_amount,

        LAG(monthly_claims) OVER (
            ORDER BY submit_month
        ) AS prior_month_claims,

        LAG(monthly_billed_amount) OVER (
            ORDER BY submit_month
        ) AS prior_month_billed_amount
    FROM monthly_claims
)

SELECT
    submit_month,
    monthly_claims,
    prior_month_claims,

    monthly_claims - prior_month_claims AS claim_volume_change,

    ROUND(
        (monthly_claims - prior_month_claims) * 100.0 / NULLIF(prior_month_claims, 0),
        2
    ) AS claim_volume_change_percent,

    monthly_billed_amount,
    prior_month_billed_amount,

    ROUND(monthly_billed_amount - prior_month_billed_amount, 2) AS billed_amount_change
FROM monthly_with_lag
ORDER BY submit_month;


-- ============================================================
-- Section 13: Monthly denial volume with running total
-- Business question:
-- How do denials accumulate over time?
-- ============================================================

WITH monthly_denials AS (
    SELECT
        DATE_FORMAT(denial_date, '%Y-%m') AS denial_month,

        COUNT(*) AS monthly_denials,
        ROUND(SUM(denied_amount), 2) AS monthly_denied_amount
    FROM denials
    GROUP BY DATE_FORMAT(denial_date, '%Y-%m')
)

SELECT
    denial_month,
    monthly_denials,
    monthly_denied_amount,

    SUM(monthly_denials) OVER (
        ORDER BY denial_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_denial_count,

    ROUND(
        SUM(monthly_denied_amount) OVER (
            ORDER BY denial_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS running_denied_amount
FROM monthly_denials
ORDER BY denial_month;


-- ============================================================
-- Section 14: Monthly ERA paid amount with running total
-- Business question:
-- How does paid amount accumulate by ERA month?
-- ============================================================

WITH monthly_era AS (
    SELECT
        DATE_FORMAT(era_date, '%Y-%m') AS era_month,

        COUNT(*) AS era_records,
        ROUND(SUM(paid_amount), 2) AS monthly_paid_amount,
        ROUND(SUM(adjustment_amount), 2) AS monthly_adjustment_amount
    FROM era
    GROUP BY DATE_FORMAT(era_date, '%Y-%m')
)

SELECT
    era_month,
    era_records,
    monthly_paid_amount,
    monthly_adjustment_amount,

    ROUND(
        SUM(monthly_paid_amount) OVER (
            ORDER BY era_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS running_paid_amount,

    ROUND(
        SUM(monthly_adjustment_amount) OVER (
            ORDER BY era_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS running_adjustment_amount
FROM monthly_era
ORDER BY era_month;


-- ============================================================
-- Section 15: Payer share of total rejected billed amount
-- Business question:
-- Which payers represent the largest share of rejected dollars?
-- ============================================================

WITH rejected_by_payer AS (
    SELECT
        p.payer_name,
        p.payer_type,

        COUNT(*) AS rejected_claims,
        ROUND(SUM(c.billed_amount), 2) AS rejected_billed_amount
    FROM claims c
    INNER JOIN payer p
        ON c.payer_id = p.payer_id
    WHERE c.claim_status = 'Rejected'
    GROUP BY
        p.payer_name,
        p.payer_type
)

SELECT
    payer_name,
    payer_type,
    rejected_claims,
    rejected_billed_amount,

    ROUND(
        rejected_billed_amount * 100.0 / SUM(rejected_billed_amount) OVER (),
        2
    ) AS percent_of_total_rejected_billed_amount,

    RANK() OVER (
        ORDER BY rejected_billed_amount DESC
    ) AS rejected_billed_amount_rank
FROM rejected_by_payer
ORDER BY rejected_billed_amount_rank;


-- ============================================================
-- Section 16: Payer share of total denied amount
-- Business question:
-- Which payers represent the largest share of denied dollars?
-- ============================================================

WITH denied_by_payer AS (
    SELECT
        p.payer_name,
        p.payer_type,

        COUNT(*) AS denial_count,
        ROUND(SUM(d.denied_amount), 2) AS total_denied_amount
    FROM denials d
    INNER JOIN claims c
        ON d.claim_id = c.claim_id
    INNER JOIN payer p
        ON c.payer_id = p.payer_id
    GROUP BY
        p.payer_name,
        p.payer_type
)

SELECT
    payer_name,
    payer_type,
    denial_count,
    total_denied_amount,

    ROUND(
        total_denied_amount * 100.0 / SUM(total_denied_amount) OVER (),
        2
    ) AS percent_of_total_denied_amount,

    RANK() OVER (
        ORDER BY total_denied_amount DESC
    ) AS denied_amount_rank
FROM denied_by_payer
ORDER BY denied_amount_rank;


-- ============================================================
-- Section 17: Rank enrollment blockers by rejected claims
-- Business question:
-- Which enrollment blockers are most associated with claim rejections?
-- ============================================================

WITH blocker_claim_summary AS (
    SELECT
        e.blocker_reason,

        COUNT(*) AS total_claims,

        SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
        SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

        ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount
    FROM claims c
    INNER JOIN enrollment e
        ON c.enrollment_id = e.enrollment_id
    WHERE e.blocker_reason <> 'No blocker'
    GROUP BY e.blocker_reason
)

SELECT
    blocker_reason,
    total_claims,
    rejected_claims,
    denied_claims,
    issue_billed_amount,

    RANK() OVER (
        ORDER BY rejected_claims DESC
    ) AS rejected_claim_rank,

    RANK() OVER (
        ORDER BY issue_billed_amount DESC
    ) AS issue_billed_amount_rank
FROM blocker_claim_summary
ORDER BY rejected_claim_rank, issue_billed_amount_rank;


-- ============================================================
-- Section 18: Top blocker per payer by issue billed amount
-- Business question:
-- What is the highest financial-risk blocker for each payer?
-- ============================================================

WITH blocker_payer_summary AS (
    SELECT
        p.payer_name,
        p.payer_type,
        e.blocker_reason,

        COUNT(*) AS issue_claims,
        ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount
    FROM claims c
    INNER JOIN payer p
        ON c.payer_id = p.payer_id
    INNER JOIN enrollment e
        ON c.enrollment_id = e.enrollment_id
    WHERE e.blocker_reason <> 'No blocker'
      AND c.claim_status IN ('Rejected', 'Denied')
    GROUP BY
        p.payer_name,
        p.payer_type,
        e.blocker_reason
),

ranked_blockers AS (
    SELECT
        payer_name,
        payer_type,
        blocker_reason,
        issue_claims,
        issue_billed_amount,

        ROW_NUMBER() OVER (
            PARTITION BY payer_name
            ORDER BY issue_billed_amount DESC, issue_claims DESC
        ) AS blocker_rank_within_payer
    FROM blocker_payer_summary
)

SELECT
    payer_name,
    payer_type,
    blocker_reason,
    issue_claims,
    issue_billed_amount,
    blocker_rank_within_payer
FROM ranked_blockers
WHERE blocker_rank_within_payer = 1
ORDER BY issue_billed_amount DESC;


-- ============================================================
-- Section 19: Provider risk rank within each specialty
-- Business question:
-- Within each specialty, which practices have the highest issue billed amount?
-- ============================================================

WITH provider_issue_summary AS (
    SELECT
        pr.specialty,
        pr.practice_name,
        pr.state,

        COUNT(*) AS total_claims,
        SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
        SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

        ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount
    FROM claims c
    INNER JOIN provider pr
        ON c.provider_id = pr.provider_id
    GROUP BY
        pr.specialty,
        pr.practice_name,
        pr.state
),

ranked_provider_risk AS (
    SELECT
        specialty,
        practice_name,
        state,
        total_claims,
        rejected_claims,
        denied_claims,
        issue_billed_amount,

        RANK() OVER (
            PARTITION BY specialty
            ORDER BY issue_billed_amount DESC
        ) AS risk_rank_within_specialty
    FROM provider_issue_summary
)

SELECT
    specialty,
    practice_name,
    state,
    total_claims,
    rejected_claims,
    denied_claims,
    issue_billed_amount,
    risk_rank_within_specialty
FROM ranked_provider_risk
WHERE risk_rank_within_specialty <= 3
ORDER BY
    specialty,
    risk_rank_within_specialty;


-- ============================================================
-- Section 20: Window function KPI summary for documentation
-- Business question:
-- Which ranked outputs are useful for README/project screenshots?
-- ============================================================

WITH payer_issue_summary AS (
    SELECT
        p.payer_name,
        p.payer_type,

        COUNT(*) AS total_claims,
        SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
        SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
        ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount
    FROM claims c
    INNER JOIN payer p
        ON c.payer_id = p.payer_id
    GROUP BY
        p.payer_name,
        p.payer_type
),

ranked_payers AS (
    SELECT
        payer_name,
        payer_type,
        total_claims,
        rejected_claims,
        denied_claims,
        issue_billed_amount,

        RANK() OVER (
            ORDER BY issue_billed_amount DESC
        ) AS issue_billed_amount_rank
    FROM payer_issue_summary
)

SELECT
    'Window Function Summary' AS report_name,
    payer_name,
    payer_type,
    total_claims,
    rejected_claims,
    denied_claims,
    issue_billed_amount,
    issue_billed_amount_rank
FROM ranked_payers
WHERE issue_billed_amount_rank <= 5
ORDER BY issue_billed_amount_rank;


-- ============================================================
-- Analyst Notes
-- ============================================================

-- Key interpretation:
-- Window functions allow ranking and trend analysis without losing detail.
-- They are especially useful for Top-N analysis, payer rankings,
-- provider rankings, percent-of-total calculations, and running totals.

-- Important distinction:
-- GROUP BY collapses data into one row per group.
-- Window functions can calculate ranks, totals, and comparisons across rows
-- while preserving useful detail.

-- Portfolio takeaway:
-- This script demonstrates intermediate SQL skill by using RANK,
-- DENSE_RANK, ROW_NUMBER, SUM OVER, LAG, and PARTITION BY.

-- My observation:
-- Window functions make it easier to identify the highest-risk payer, provider, and blocker combinations without losing business context.

-- Follow-up question:
-- Which ranked payer or blocker should be prioritized first if operations can only address one issue category this month?