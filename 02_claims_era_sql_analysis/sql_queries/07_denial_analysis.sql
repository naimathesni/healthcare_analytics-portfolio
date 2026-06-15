-- ============================================================
-- Project: Healthcare Claims & ERA SQL Analysis
-- Script: 07_denial_analysis.sql
-- Topic: Denial root-cause, payer, provider, and preventable denial analysis
-- SQL dialect: MySQL
-- Purpose:
--   Analyze denied claims by category, payer, provider, enrollment blocker,
--   preventability, denied amount, and operational priority.
-- ============================================================

USE healthcare_claims_era;


-- ============================================================
-- Section 1: Overall denial KPI summary
-- Business question:
-- What is the overall denial volume and financial impact?
-- ============================================================

SELECT
    COUNT(*) AS total_denials,
    ROUND(SUM(denied_amount), 2) AS total_denied_amount,
    ROUND(AVG(denied_amount), 2) AS avg_denied_amount,
    ROUND(MIN(denied_amount), 2) AS min_denied_amount,
    ROUND(MAX(denied_amount), 2) AS max_denied_amount,

    SUM(CASE WHEN preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials,
    SUM(CASE WHEN preventable_flag = 'No' THEN 1 ELSE 0 END) AS non_preventable_denials,

    ROUND(
        SUM(CASE WHEN preventable_flag = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS preventable_denial_percent
FROM denials;


-- Expected:
-- total_denials = 188
-- preventable_denials = 151
-- non_preventable_denials = 37


-- ============================================================
-- Section 2: Denials by category
-- Business question:
-- Which denial categories are most common and most expensive?
-- ============================================================

SELECT
    denial_category,
    COUNT(*) AS denial_count,

    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM denials), 2) AS percent_of_denials,

    ROUND(SUM(denied_amount), 2) AS total_denied_amount,
    ROUND(AVG(denied_amount), 2) AS avg_denied_amount,

    SUM(CASE WHEN preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials,
    ROUND(
        SUM(CASE WHEN preventable_flag = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS preventable_percent_within_category
FROM denials
GROUP BY denial_category
ORDER BY denial_count DESC, total_denied_amount DESC;


-- Expected category counts:
-- Enrollment/Configuration = 75
-- Timely Filing = 26
-- Eligibility = 25
-- Coding = 25
-- Duplicate = 13
-- Authorization = 12
-- Medical Necessity = 12


-- ============================================================
-- Section 3: Preventable vs non-preventable denial summary
-- Business question:
-- How much denial volume and denied amount may be preventable?
-- ============================================================

SELECT
    preventable_flag,
    COUNT(*) AS denial_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM denials), 2) AS percent_of_denials,
    ROUND(SUM(denied_amount), 2) AS total_denied_amount,
    ROUND(AVG(denied_amount), 2) AS avg_denied_amount
FROM denials
GROUP BY preventable_flag
ORDER BY denial_count DESC;


-- ============================================================
-- Section 4: Denial trend by month
-- Business question:
-- How are denials trending over time?
-- ============================================================

SELECT
    DATE_FORMAT(denial_date, '%Y-%m') AS denial_month,

    COUNT(*) AS total_denials,
    SUM(CASE WHEN preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials,
    SUM(CASE WHEN denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) AS enrollment_configuration_denials,

    ROUND(SUM(denied_amount), 2) AS total_denied_amount,
    ROUND(AVG(denied_amount), 2) AS avg_denied_amount
FROM denials
GROUP BY DATE_FORMAT(denial_date, '%Y-%m')
ORDER BY denial_month;


-- ============================================================
-- Section 5: Claim denial rate by payer
-- Business question:
-- Which payers have the highest denial rate?
-- Note:
-- This uses the claims table because denial rate needs all claims as the denominator.
-- ============================================================

SELECT
    p.payer_name,
    p.payer_type,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

    ROUND(
        SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS denial_rate_percent,

    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,

    ROUND(
        SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS rejection_rate_percent,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount,
    ROUND(SUM(CASE WHEN c.claim_status = 'Denied' THEN c.billed_amount ELSE 0 END), 2) AS denied_billed_amount
FROM claims c
INNER JOIN payer p
    ON c.payer_id = p.payer_id
GROUP BY
    p.payer_name,
    p.payer_type
ORDER BY denial_rate_percent DESC, denied_claims DESC;


-- ============================================================
-- Section 6: Denied amount by payer
-- Business question:
-- Which payers have the highest denied financial impact?
-- ============================================================

SELECT
    p.payer_name,
    p.payer_type,

    COUNT(*) AS denial_count,
    ROUND(SUM(d.denied_amount), 2) AS total_denied_amount,
    ROUND(AVG(d.denied_amount), 2) AS avg_denied_amount,

    SUM(CASE WHEN d.preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials,
    SUM(CASE WHEN d.denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) AS enrollment_configuration_denials
FROM denials d
INNER JOIN claims c
    ON d.claim_id = c.claim_id
INNER JOIN payer p
    ON c.payer_id = p.payer_id
GROUP BY
    p.payer_name,
    p.payer_type
ORDER BY total_denied_amount DESC, denial_count DESC;


-- ============================================================
-- Section 7: Denial category by payer
-- Business question:
-- Which denial categories are most common for each payer?
-- ============================================================

SELECT
    p.payer_name,
    p.payer_type,
    d.denial_category,

    COUNT(*) AS denial_count,
    ROUND(SUM(d.denied_amount), 2) AS total_denied_amount,
    ROUND(AVG(d.denied_amount), 2) AS avg_denied_amount
FROM denials d
INNER JOIN claims c
    ON d.claim_id = c.claim_id
INNER JOIN payer p
    ON c.payer_id = p.payer_id
GROUP BY
    p.payer_name,
    p.payer_type,
    d.denial_category
ORDER BY
    p.payer_name,
    denial_count DESC,
    total_denied_amount DESC;


-- ============================================================
-- Section 8: Denials by provider/practice
-- Business question:
-- Which practices or specialties have the most denials?
-- ============================================================

SELECT
    pr.practice_name,
    pr.specialty,
    pr.state,

    COUNT(*) AS denial_count,
    ROUND(SUM(d.denied_amount), 2) AS total_denied_amount,
    ROUND(AVG(d.denied_amount), 2) AS avg_denied_amount,

    SUM(CASE WHEN d.preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials,
    SUM(CASE WHEN d.denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) AS enrollment_configuration_denials
FROM denials d
INNER JOIN claims c
    ON d.claim_id = c.claim_id
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
GROUP BY
    pr.practice_name,
    pr.specialty,
    pr.state
ORDER BY denial_count DESC, total_denied_amount DESC
LIMIT 25;


-- ============================================================
-- Section 9: Denials by specialty
-- Business question:
-- Which specialties have the highest denial volume and denied amount?
-- ============================================================

SELECT
    pr.specialty,

    COUNT(*) AS denial_count,
    ROUND(SUM(d.denied_amount), 2) AS total_denied_amount,
    ROUND(AVG(d.denied_amount), 2) AS avg_denied_amount,

    SUM(CASE WHEN d.preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials,
    SUM(CASE WHEN d.denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) AS enrollment_configuration_denials
FROM denials d
INNER JOIN claims c
    ON d.claim_id = c.claim_id
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
GROUP BY pr.specialty
ORDER BY total_denied_amount DESC, denial_count DESC;


-- ============================================================
-- Section 10: Enrollment/configuration denials by blocker reason
-- Business question:
-- Which enrollment blockers are tied to enrollment/configuration denials?
-- ============================================================

SELECT
    e.blocker_reason,
    e.npi_match_status,
    e.claims_ready_flag,
    e.era_ready_flag,

    COUNT(*) AS enrollment_configuration_denials,
    ROUND(SUM(d.denied_amount), 2) AS total_denied_amount,
    ROUND(AVG(d.denied_amount), 2) AS avg_denied_amount
FROM denials d
INNER JOIN claims c
    ON d.claim_id = c.claim_id
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
WHERE d.denial_category = 'Enrollment/Configuration'
GROUP BY
    e.blocker_reason,
    e.npi_match_status,
    e.claims_ready_flag,
    e.era_ready_flag
ORDER BY enrollment_configuration_denials DESC, total_denied_amount DESC;


-- ============================================================
-- Section 11: All denials by enrollment blocker reason
-- Business question:
-- Which enrollment readiness blockers appear most often on denied claims?
-- ============================================================

SELECT
    e.blocker_reason,

    COUNT(*) AS denial_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM denials), 2) AS percent_of_denials,

    ROUND(SUM(d.denied_amount), 2) AS total_denied_amount,
    ROUND(AVG(d.denied_amount), 2) AS avg_denied_amount,

    SUM(CASE WHEN d.preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials,
    SUM(CASE WHEN d.denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) AS enrollment_configuration_denials
FROM denials d
INNER JOIN claims c
    ON d.claim_id = c.claim_id
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
GROUP BY e.blocker_reason
ORDER BY denial_count DESC, total_denied_amount DESC;


-- ============================================================
-- Section 12: Denials grouped by operational issue category
-- Business question:
-- Which operational issue groups drive denial volume?
-- ============================================================

SELECT
    CASE
        WHEN e.blocker_reason IN (
            'Individual NPI used instead of group NPI',
            'Credentialed NPI mismatch',
            'Incorrect PTAN/provider number'
        ) THEN 'Provider Identifier Issue'

        WHEN e.blocker_reason = 'Clearinghouse portal not updated'
            THEN 'Clearinghouse Configuration Gap'

        WHEN e.blocker_reason IN (
            'Wrong payer ID',
            'Old payer ID used'
        ) THEN 'Payer Routing Issue'

        WHEN e.blocker_reason IN (
            'Medicare additional enrollment missing',
            'Medicaid additional enrollment missing'
        ) THEN 'Government Payer Enrollment Issue'

        WHEN e.blocker_reason = 'Credentialing not completed'
            THEN 'Credentialing Issue'

        WHEN e.blocker_reason = 'Missing payer approval'
            THEN 'Payer Approval Pending'

        WHEN e.blocker_reason = 'ERA setup not completed'
            THEN 'ERA Setup Issue'

        WHEN e.blocker_reason = 'No blocker'
            THEN 'No Enrollment Blocker'

        ELSE 'Other'
    END AS operational_issue_category,

    COUNT(*) AS denial_count,
    ROUND(SUM(d.denied_amount), 2) AS total_denied_amount,
    ROUND(AVG(d.denied_amount), 2) AS avg_denied_amount,

    SUM(CASE WHEN d.preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials,
    SUM(CASE WHEN d.denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) AS enrollment_configuration_denials
FROM denials d
INNER JOIN claims c
    ON d.claim_id = c.claim_id
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
GROUP BY operational_issue_category
ORDER BY denial_count DESC, total_denied_amount DESC;


-- ============================================================
-- Section 13: High-dollar denials with payer, provider, and enrollment context
-- Business question:
-- Which high-dollar denials should be reviewed first?
-- ============================================================

SELECT
    d.denial_id,
    d.denial_category,
    d.denial_reason,
    d.denied_amount,
    d.preventable_flag,

    c.claim_id,
    c.claim_submit_date,
    c.billed_amount,

    p.payer_name,
    p.payer_type,

    pr.practice_name,
    pr.specialty,
    pr.state,

    e.enrollment_type,
    e.current_status AS enrollment_status,
    e.blocker_reason,
    e.npi_match_status,
    e.claims_ready_flag,
    e.era_ready_flag
FROM denials d
INNER JOIN claims c
    ON d.claim_id = c.claim_id
INNER JOIN payer p
    ON c.payer_id = p.payer_id
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
ORDER BY d.denied_amount DESC
LIMIT 50;


-- ============================================================
-- Section 14: High-dollar preventable denials
-- Business question:
-- Which preventable denials have the highest dollar impact?
-- ============================================================

SELECT
    d.denial_id,
    d.denial_category,
    d.denial_reason,
    d.denied_amount,

    c.claim_id,
    c.claim_submit_date,
    c.billed_amount,

    p.payer_name,
    pr.practice_name,
    pr.specialty,

    e.blocker_reason,
    e.claims_ready_flag,
    e.npi_match_status
FROM denials d
INNER JOIN claims c
    ON d.claim_id = c.claim_id
INNER JOIN payer p
    ON c.payer_id = p.payer_id
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
WHERE d.preventable_flag = 'Yes'
ORDER BY d.denied_amount DESC
LIMIT 50;


-- ============================================================
-- Section 15: Denied amount as a percentage of billed amount
-- Business question:
-- Which denied claims represent the largest percentage of billed amount?
-- ============================================================

SELECT
    d.denial_id,
    c.claim_id,

    c.billed_amount,
    d.denied_amount,

    ROUND(d.denied_amount * 100.0 / NULLIF(c.billed_amount, 0), 2) AS denied_percent_of_billed,

    d.denial_category,
    d.denial_reason,
    d.preventable_flag,

    p.payer_name,
    pr.practice_name,

    e.blocker_reason
FROM denials d
INNER JOIN claims c
    ON d.claim_id = c.claim_id
INNER JOIN payer p
    ON c.payer_id = p.payer_id
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
ORDER BY denied_percent_of_billed DESC, d.denied_amount DESC
LIMIT 50;


-- ============================================================
-- Section 16: Denial rate by claim source and claim type
-- Business question:
-- Are certain claim sources or claim types more likely to deny?
-- Note:
-- This uses claims as the base table because denial rate needs all claims as denominator.
-- ============================================================

SELECT
    c.claim_source,
    c.claim_type,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

    ROUND(
        SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS denial_rate_percent,

    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,

    ROUND(
        SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS rejection_rate_percent,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount
FROM claims c
GROUP BY
    c.claim_source,
    c.claim_type
ORDER BY denial_rate_percent DESC, rejected_claims DESC;


-- ============================================================
-- Section 17: Payer denial prioritization matrix
-- Business question:
-- Which payers operations should  prioritize based on denial volume,
-- preventability, enrollment/configuration denials, and denied amount?
-- ============================================================

SELECT
    p.payer_name,
    p.payer_type,

    COUNT(*) AS total_denials,
    SUM(CASE WHEN d.preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials,
    SUM(CASE WHEN d.denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) AS enrollment_configuration_denials,

    ROUND(SUM(d.denied_amount), 2) AS total_denied_amount,

    ROUND(
        (
            COUNT(*) * 1.0
            + SUM(CASE WHEN d.preventable_flag = 'Yes' THEN 1 ELSE 0 END) * 1.5
            + SUM(CASE WHEN d.denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) * 2.0
            + SUM(d.denied_amount) / 1000
        ),
        2
    ) AS operational_priority_score
FROM denials d
INNER JOIN claims c
    ON d.claim_id = c.claim_id
INNER JOIN payer p
    ON c.payer_id = p.payer_id
GROUP BY
    p.payer_name,
    p.payer_type
ORDER BY operational_priority_score DESC;


-- ============================================================
-- Section 18: Denial KPI summary for documentation
-- Business question:
-- What denial KPIs should be documented in the project README?
-- ============================================================

SELECT
    'Denial KPI Summary' AS report_name,

    COUNT(*) AS total_denials,
    ROUND(SUM(denied_amount), 2) AS total_denied_amount,

    SUM(CASE WHEN preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials,
    ROUND(
        SUM(CASE WHEN preventable_flag = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS preventable_denial_percent,

    SUM(CASE WHEN denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) AS enrollment_configuration_denials,
    ROUND(
        SUM(CASE WHEN denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS enrollment_configuration_denial_percent,

    ROUND(AVG(denied_amount), 2) AS avg_denied_amount
FROM denials;


-- ============================================================
-- Analyst Notes
-- ============================================================

-- Key interpretation:
-- Denial analysis should not stop at denial category counts.
-- A useful revenue-cycle analysis connects denials to payer, provider,
-- enrollment readiness, NPI match status, clearinghouse setup, and preventability.

-- Most important denial category to watch:
-- Enrollment/Configuration, because it is directly tied to payer setup,
-- provider identifiers, claims enrollment, ERA readiness, and clearinghouse configuration.

-- Operational takeaway:
-- Preventable denials and enrollment/configuration denials should be prioritized
-- because they may be reduced through better pre-claim validation, payer setup checks,
-- NPI/PTAN validation, and clearinghouse readiness controls.


-- My observation:
-- Enrollment/Configuration is the largest denial category, which suggest setup and readiness issues may be contributing to avoidable revenue-cycle loss.

-- Follow-up question:
-- Which payer and blocker reason combination is driving the highest denied amount?