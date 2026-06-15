-- ============================================================
-- Project: Healthcare Claims & ERA SQL Analysis
-- Script: 12_business_questions.sql
-- Topic: Business question-driven SQL analysis
-- SQL dialect: MySQL
-- Purpose:
--   Answer practical healthcare revenue-cycle business questions
--   using claims, ERA, denial, payer, provider, and enrollment data.
-- ============================================================

USE healthcare_claims_era;


-- ============================================================
-- Question 1:
-- What are the overall claims, ERA, denial, and enrollment impact KPIs?
-- Business purpose:
-- Provide an executive summary of claim outcomes, payments, denials,
-- ERA coverage, and enrollment-related risk.
-- ============================================================

WITH claim_kpis AS (
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

        ROUND(SUM(billed_amount), 2) AS total_billed_amount
    FROM claims
),

era_kpis AS (
    SELECT
        COUNT(*) AS total_era_records,
        COUNT(DISTINCT claim_id) AS claims_with_era,
        ROUND(SUM(paid_amount), 2) AS total_paid_amount,
        ROUND(SUM(adjustment_amount), 2) AS total_adjustment_amount
    FROM era
),

denial_kpis AS (
    SELECT
        COUNT(*) AS total_denials,
        ROUND(SUM(denied_amount), 2) AS total_denied_amount,

        SUM(CASE WHEN preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials,

        SUM(CASE WHEN denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) AS enrollment_configuration_denials
    FROM denials
),

enrollment_kpis AS (
    SELECT
        SUM(CASE WHEN e.action_required_flag = 'Yes' THEN 1 ELSE 0 END) AS claims_tied_to_action_required_enrollment,

        SUM(
            CASE
                WHEN e.enrollment_type IN ('Claims', 'Claims and ERA')
                  AND e.claims_ready_flag <> 'Ready'
                THEN 1
                ELSE 0
            END
        ) AS claims_submitted_while_not_claims_ready,

        SUM(CASE WHEN e.npi_match_status = 'NPI Mismatch' THEN 1 ELSE 0 END) AS claims_tied_to_npi_mismatch
    FROM claims c
    INNER JOIN enrollment e
        ON c.enrollment_id = e.enrollment_id
)

SELECT
    ck.total_claims,
    ck.paid_claims,
    ck.denied_claims,
    ck.rejected_claims,
    ck.pending_claims,
    ck.submitted_claims,
    ck.paid_rate_percent,
    ck.denial_rate_percent,
    ck.rejection_rate_percent,
    ck.total_billed_amount,

    ek.total_era_records,
    ek.claims_with_era,
    ck.total_claims - ek.claims_with_era AS claims_without_era,
    ek.total_paid_amount,
    ek.total_adjustment_amount,

    dk.total_denials,
    dk.total_denied_amount,
    dk.preventable_denials,
    dk.enrollment_configuration_denials,

    enk.claims_tied_to_action_required_enrollment,
    enk.claims_submitted_while_not_claims_ready,
    enk.claims_tied_to_npi_mismatch
FROM claim_kpis ck
CROSS JOIN era_kpis ek
CROSS JOIN denial_kpis dk
CROSS JOIN enrollment_kpis enk;


-- ============================================================
-- Question 2:
-- Which payer has the highest rejection rate?
-- Business purpose:
-- Identify payers where claims are most likely to fail before
-- successful adjudication.
-- ============================================================

WITH payer_claims AS (
    SELECT
        p.payer_name,
        p.payer_type,

        COUNT(*) AS total_claims,

        SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,

        ROUND(
            SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
            2
        ) AS rejection_rate_percent,

        ROUND(SUM(CASE WHEN c.claim_status = 'Rejected' THEN c.billed_amount ELSE 0 END), 2) AS rejected_billed_amount
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
        rejected_billed_amount,

        RANK() OVER (
            ORDER BY rejection_rate_percent DESC, rejected_claims DESC
        ) AS rejection_rate_rank
    FROM payer_claims
)

SELECT
    payer_name,
    payer_type,
    total_claims,
    rejected_claims,
    rejection_rate_percent,
    rejected_billed_amount,
    rejection_rate_rank
FROM ranked_payers
ORDER BY rejection_rate_rank, payer_name;


-- ============================================================
-- Question 3:
-- Which payer has the highest denial rate?
-- Business purpose:
-- Identify payers where accepted claims are most often denied.
-- ============================================================

WITH payer_claims AS (
    SELECT
        p.payer_name,
        p.payer_type,

        COUNT(*) AS total_claims,

        SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

        ROUND(
            SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
            2
        ) AS denial_rate_percent,

        ROUND(SUM(CASE WHEN c.claim_status = 'Denied' THEN c.billed_amount ELSE 0 END), 2) AS denied_billed_amount
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
        denied_claims,
        denial_rate_percent,
        denied_billed_amount,

        RANK() OVER (
            ORDER BY denial_rate_percent DESC, denied_claims DESC
        ) AS denial_rate_rank
    FROM payer_claims
)

SELECT
    payer_name,
    payer_type,
    total_claims,
    denied_claims,
    denial_rate_percent,
    denied_billed_amount,
    denial_rate_rank
FROM ranked_payers
ORDER BY denial_rate_rank, payer_name;


-- ============================================================
-- Question 4:
-- Which payer has the longest average ERA lag?
-- Business purpose:
-- Identify payer-level remittance turnaround delays.
-- ============================================================

WITH payer_era_lag AS (
    SELECT
        p.payer_name,
        p.payer_type,

        COUNT(*) AS era_records,

        ROUND(AVG(DATEDIFF(er.era_date, c.claim_submit_date)), 2) AS avg_era_lag_days,
        MIN(DATEDIFF(er.era_date, c.claim_submit_date)) AS min_era_lag_days,
        MAX(DATEDIFF(er.era_date, c.claim_submit_date)) AS max_era_lag_days,

        ROUND(SUM(er.paid_amount), 2) AS total_paid_amount
    FROM era er
    INNER JOIN claims c
        ON er.claim_id = c.claim_id
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
        era_records,
        avg_era_lag_days,
        min_era_lag_days,
        max_era_lag_days,
        total_paid_amount,

        RANK() OVER (
            ORDER BY avg_era_lag_days DESC
        ) AS era_lag_rank
    FROM payer_era_lag
)

SELECT
    payer_name,
    payer_type,
    era_records,
    avg_era_lag_days,
    min_era_lag_days,
    max_era_lag_days,
    total_paid_amount,
    era_lag_rank
FROM ranked_payers
ORDER BY era_lag_rank, payer_name;


-- ============================================================
-- Question 5:
-- Which denial category has the greatest financial impact?
-- Business purpose:
-- Prioritize denial categories by denied dollars, not only volume.
-- ============================================================

WITH denial_category_summary AS (
    SELECT
        denial_category,

        COUNT(*) AS denial_count,
        ROUND(SUM(denied_amount), 2) AS total_denied_amount,
        ROUND(AVG(denied_amount), 2) AS avg_denied_amount,

        SUM(CASE WHEN preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials
    FROM denials
    GROUP BY denial_category
),

ranked_categories AS (
    SELECT
        denial_category,
        denial_count,
        total_denied_amount,
        avg_denied_amount,
        preventable_denials,

        ROUND(
            denial_count * 100.0 / SUM(denial_count) OVER (),
            2
        ) AS percent_of_total_denials,

        ROUND(
            total_denied_amount * 100.0 / SUM(total_denied_amount) OVER (),
            2
        ) AS percent_of_total_denied_amount,

        RANK() OVER (
            ORDER BY total_denied_amount DESC
        ) AS denied_amount_rank
    FROM denial_category_summary
)

SELECT
    denial_category,
    denial_count,
    total_denied_amount,
    avg_denied_amount,
    preventable_denials,
    percent_of_total_denials,
    percent_of_total_denied_amount,
    denied_amount_rank
FROM ranked_categories
ORDER BY denied_amount_rank;


-- ============================================================
-- Question 6:
-- How many claims have no ERA, and which statuses explain that?
-- Business purpose:
-- Separate expected missing ERA situations from potential ERA follow-up risk.
-- Join logic:
-- LEFT JOIN + WHERE er.claim_id IS NULL is used to find claims missing ERA.
-- ============================================================

SELECT
    c.claim_status,

    COUNT(*) AS claims_without_era,

    ROUND(
        COUNT(*) * 100.0 / (
            SELECT COUNT(*)
            FROM claims c2
            LEFT JOIN era er2
                ON c2.claim_id = er2.claim_id
            WHERE er2.claim_id IS NULL
        ),
        2
    ) AS percent_of_claims_without_era,

    ROUND(SUM(c.billed_amount), 2) AS billed_amount_without_era
FROM claims c
LEFT JOIN era er
    ON c.claim_id = er.claim_id
WHERE er.claim_id IS NULL
GROUP BY c.claim_status
ORDER BY claims_without_era DESC;


-- ============================================================
-- Question 7:
-- Which enrollment blocker reasons are tied to the most rejected or denied claims?
-- Business purpose:
-- Identify operational root causes behind claim issues.
-- ============================================================

SELECT
    e.blocker_reason,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

    ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount,

    ROUND(
        SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS rejection_rate_percent,

    ROUND(
        SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS denial_rate_percent
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
GROUP BY e.blocker_reason
ORDER BY issue_billed_amount DESC, rejected_claims DESC, denied_claims DESC;


-- ============================================================
-- Question 8:
-- Which claims were submitted while enrollment was not claims-ready?
-- Business purpose:
-- Identify pre-submission readiness risk that can block revenue flow.
-- ============================================================

SELECT
    c.claim_id,
    c.claim_submit_date,
    c.claim_status,
    c.billed_amount,

    p.payer_name,
    p.payer_type,

    pr.practice_name,
    pr.specialty,
    pr.state,

    e.enrollment_id,
    e.enrollment_type,
    e.current_status AS enrollment_status,
    e.claims_ready_flag,
    e.blocker_reason,
    e.npi_match_status,
    e.clearinghouse_portal_updated,
    e.clearinghouse_configuration_status
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
INNER JOIN payer p
    ON c.payer_id = p.payer_id
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
WHERE e.enrollment_type IN ('Claims', 'Claims and ERA')
  AND e.claims_ready_flag <> 'Ready'
ORDER BY c.billed_amount DESC, c.claim_submit_date
LIMIT 100;


-- ============================================================
-- Question 9:
-- Do NPI mismatch records have higher rejection or denial exposure?
-- Business purpose:
-- Evaluate provider identifier risk across claims.
-- ============================================================

SELECT
    e.npi_match_status,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
    SUM(CASE WHEN c.claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

    ROUND(
        SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS rejection_rate_percent,

    ROUND(
        SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS denial_rate_percent,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount,
    ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
GROUP BY e.npi_match_status
ORDER BY issue_billed_amount DESC;


-- ============================================================
-- Question 10:
-- Which payer and blocker combinations create the highest issue billed amount?
-- Business purpose:
-- Prioritize specific payer/setup issue combinations for operations.
-- ============================================================

WITH payer_blocker_issues AS (
    SELECT
        p.payer_name,
        p.payer_type,
        e.blocker_reason,

        COUNT(*) AS total_claims,

        SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
        SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

        ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount
    FROM claims c
    INNER JOIN payer p
        ON c.payer_id = p.payer_id
    INNER JOIN enrollment e
        ON c.enrollment_id = e.enrollment_id
    WHERE e.blocker_reason <> 'No blocker'
    GROUP BY
        p.payer_name,
        p.payer_type,
        e.blocker_reason
),

ranked_issues AS (
    SELECT
        payer_name,
        payer_type,
        blocker_reason,
        total_claims,
        rejected_claims,
        denied_claims,
        issue_billed_amount,

        RANK() OVER (
            ORDER BY issue_billed_amount DESC, rejected_claims DESC, denied_claims DESC
        ) AS payer_blocker_priority_rank
    FROM payer_blocker_issues
)

SELECT
    payer_name,
    payer_type,
    blocker_reason,
    total_claims,
    rejected_claims,
    denied_claims,
    issue_billed_amount,
    payer_blocker_priority_rank
FROM ranked_issues
ORDER BY payer_blocker_priority_rank
LIMIT 25;


-- ============================================================
-- Question 11:
-- Which practices have the highest rejected/denied billed amount?
-- Business purpose:
-- Identify practices that may need operational support or workflow review.
-- ============================================================

WITH practice_issue_summary AS (
    SELECT
        pr.practice_name,
        pr.specialty,
        pr.state,

        COUNT(*) AS total_claims,

        SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
        SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

        ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount,

        ROUND(
            SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
            2
        ) AS issue_claim_rate_percent
    FROM claims c
    INNER JOIN provider pr
        ON c.provider_id = pr.provider_id
    GROUP BY
        pr.practice_name,
        pr.specialty,
        pr.state
),

ranked_practices AS (
    SELECT
        practice_name,
        specialty,
        state,
        total_claims,
        rejected_claims,
        denied_claims,
        issue_billed_amount,
        issue_claim_rate_percent,

        RANK() OVER (
            ORDER BY issue_billed_amount DESC
        ) AS issue_billed_amount_rank
    FROM practice_issue_summary
)

SELECT
    practice_name,
    specialty,
    state,
    total_claims,
    rejected_claims,
    denied_claims,
    issue_billed_amount,
    issue_claim_rate_percent,
    issue_billed_amount_rank
FROM ranked_practices
ORDER BY issue_billed_amount_rank
LIMIT 25;


-- ============================================================
-- Question 12:
-- Which payers should operations prioritize overall?
-- Business purpose:
-- Combine rejection, denial, ERA, denied amount, and enrollment readiness
-- into one operational prioritization view.
-- ============================================================

WITH claim_summary AS (
    SELECT
        payer_id,

        COUNT(*) AS total_claims,
        SUM(CASE WHEN claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
        SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

        ROUND(SUM(CASE WHEN claim_status IN ('Rejected', 'Denied') THEN billed_amount ELSE 0 END), 2) AS issue_billed_amount
    FROM claims
    GROUP BY payer_id
),

era_summary AS (
    SELECT
        c.payer_id,

        ROUND(AVG(DATEDIFF(er.era_date, c.claim_submit_date)), 2) AS avg_era_lag_days,

        SUM(
            CASE
                WHEN DATEDIFF(er.era_date, c.claim_submit_date) > 21 THEN 1
                ELSE 0
            END
        ) AS era_records_over_21_days
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

payer_priority AS (
    SELECT
        p.payer_name,
        p.payer_type,

        COALESCE(cs.total_claims, 0) AS total_claims,
        COALESCE(cs.rejected_claims, 0) AS rejected_claims,
        COALESCE(cs.denied_claims, 0) AS denied_claims,
        COALESCE(cs.issue_billed_amount, 0) AS issue_billed_amount,

        COALESCE(es.avg_era_lag_days, 0) AS avg_era_lag_days,
        COALESCE(es.era_records_over_21_days, 0) AS era_records_over_21_days,

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
),

scored_payers AS (
    SELECT
        payer_name,
        payer_type,

        total_claims,
        rejected_claims,
        denied_claims,
        issue_billed_amount,

        avg_era_lag_days,
        era_records_over_21_days,

        total_denials,
        preventable_denials,
        enrollment_configuration_denials,
        total_denied_amount,

        action_required_enrollment_records,
        claims_not_ready_records,
        npi_mismatch_records,

        ROUND(
            (
                rejected_claims * 2.0
                + denied_claims * 1.5
                + preventable_denials * 1.5
                + enrollment_configuration_denials * 2.5
                + era_records_over_21_days * 1.0
                + action_required_enrollment_records * 1.0
                + claims_not_ready_records * 1.5
                + npi_mismatch_records * 2.0
                + total_denied_amount / 1000
                + issue_billed_amount / 2000
            ),
            2
        ) AS operational_priority_score
    FROM payer_priority
)

SELECT
    payer_name,
    payer_type,

    total_claims,
    rejected_claims,
    denied_claims,
    issue_billed_amount,

    avg_era_lag_days,
    era_records_over_21_days,

    total_denials,
    preventable_denials,
    enrollment_configuration_denials,
    total_denied_amount,

    action_required_enrollment_records,
    claims_not_ready_records,
    npi_mismatch_records,

    operational_priority_score,

    RANK() OVER (
        ORDER BY operational_priority_score DESC
    ) AS operational_priority_rank
FROM scored_payers
ORDER BY operational_priority_rank;


-- ============================================================
-- Question 13:
-- What recommendations should operations take based on the analysis?
-- Business purpose:
-- Convert SQL findings into business recommendations.
-- ============================================================

SELECT
    1 AS recommendation_priority,
    'Add claims-readiness validation before claim submission' AS recommendation,
    'Claims submitted while claims_ready_flag is not Ready create rejection and denial risk.' AS rationale

UNION ALL

SELECT
    2,
    'Validate credentialed NPI against enrolled NPI before payer submission',
    'NPI mismatch records can create provider identifier-related claim and enrollment risk.'

UNION ALL

SELECT
    3,
    'Prioritize clearinghouse portal and configuration checkpoints',
    'Clearinghouse gaps can block claims flow and ERA routing.'

UNION ALL

SELECT
    4,
    'Monitor payer-level rejection rate and denied amount together',
    'A payer with high rejection volume and high denied dollars should be prioritized over volume alone.'

UNION ALL

SELECT
    5,
    'Review claims without ERA by claim status and payer',
    'Submitted, pending, and rejected claims may not have ERA yet, but payer-level patterns can reveal follow-up needs.'

UNION ALL

SELECT
    6,
    'Track claims readiness and ERA readiness separately',
    'A record may be ready for claims submission but not fully ready for ERA receipt or payment posting.';


-- ============================================================
-- Analyst Notes
-- ============================================================

-- Key interpretation:
-- The most useful SQL analysis connects claim outcomes to payer,
-- provider, enrollment readiness, denial category, and ERA status.

-- Most important business distinction:
-- Claim rejection is an early revenue-cycle failure.
-- If a claim rejects before adjudication, payment and ERA flow are delayed before denial management even begins.

-- Strongest operational focus:
-- Claims submitted while claims_ready_flag <> 'Ready' should be reviewed first,
-- especially when tied to NPI mismatch, clearinghouse setup gaps, payer routing issues,
-- or government payer enrollment requirements.

-- Portfolio takeaway:
-- This script demonstrates business-question-driven SQL analysis,
-- not just technical querying.

-- My observation:
-- The biggest operational risk is not one metric alone, it is the combination of high rejection volume, enrollment blockers, prevenatable denails, and ERA Lag

-- Follow-up question:
-- which payer enrollment workflow should operations standardize first to reduce claim rejection and ERA follow-up risk?