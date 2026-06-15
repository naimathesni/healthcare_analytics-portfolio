USE healthcare_claims_era;

-- Data Quality Checks


WITH checks AS (
    SELECT 'Row count - payer' AS check_name, 10 AS expected_count, COUNT(*) AS actual_count
    FROM payer

    UNION ALL
    SELECT 'Row count - provider', 40, COUNT(*)
    FROM provider

    UNION ALL
    SELECT 'Row count - enrollment', 400, COUNT(*)
    FROM enrollment

    UNION ALL
    SELECT 'Row count - claims', 1500, COUNT(*)
    FROM claims

    UNION ALL
    SELECT 'Row count - era', 450, COUNT(*)
    FROM era

    UNION ALL
    SELECT 'Row count - denials', 188, COUNT(*)
    FROM denials

    UNION ALL
    SELECT 'Denied claims without denial record', 0, COUNT(*)
    FROM claims c
    LEFT JOIN denials d
        ON c.claim_id = d.claim_id
    WHERE c.claim_status = 'Denied'
      AND d.claim_id IS NULL

    UNION ALL
    SELECT 'Paid/Denied claims without ERA', 0, COUNT(*)
    FROM claims c
    LEFT JOIN era er
        ON c.claim_id = er.claim_id
    WHERE c.claim_status IN ('Paid', 'Denied')
      AND er.claim_id IS NULL

    UNION ALL
    SELECT 'Negative billed amount', 0, COUNT(*)
    FROM claims
    WHERE billed_amount < 0
)

SELECT
    check_name,
    expected_count,
    actual_count,
    CASE
        WHEN expected_count = actual_count THEN 'Pass'
        ELSE 'Check'
    END AS check_status
FROM checks;


-- Claims KPI Summary

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

        ROUND(SUM(billed_amount), 2) AS total_billed_amount,
        ROUND(AVG(billed_amount), 2) AS avg_billed_amount
    FROM claims
)

SELECT 1 AS sort_order, 'Total Claims' AS kpi, FORMAT(total_claims, 0) AS value FROM claim_kpis
UNION ALL
SELECT 2, 'Paid Claims', FORMAT(paid_claims, 0) FROM claim_kpis
UNION ALL
SELECT 3, 'Denied Claims', FORMAT(denied_claims, 0) FROM claim_kpis
UNION ALL
SELECT 4, 'Rejected Claims', FORMAT(rejected_claims, 0) FROM claim_kpis
UNION ALL
SELECT 5, 'Pending Claims', FORMAT(pending_claims, 0) FROM claim_kpis
UNION ALL
SELECT 6, 'Submitted Claims', FORMAT(submitted_claims, 0) FROM claim_kpis
UNION ALL
SELECT 7, 'Paid Rate', CONCAT(paid_rate_percent, '%') FROM claim_kpis
UNION ALL
SELECT 8, 'Denial Rate', CONCAT(denial_rate_percent, '%') FROM claim_kpis
UNION ALL
SELECT 9, 'Rejection Rate', CONCAT(rejection_rate_percent, '%') FROM claim_kpis
UNION ALL
SELECT 10, 'Total Billed Amount', CONCAT('$', FORMAT(total_billed_amount, 2)) FROM claim_kpis
UNION ALL
SELECT 11, 'Average Billed Amount', CONCAT('$', FORMAT(avg_billed_amount, 2)) FROM claim_kpis
ORDER BY sort_order;


-- Denial Category Analysis


SELECT
    denial_category,
    COUNT(*) AS denial_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM denials), 2) AS percent_of_denials,
    ROUND(SUM(denied_amount), 2) AS total_denied_amount,
    ROUND(AVG(denied_amount), 2) AS avg_denied_amount,
    SUM(CASE WHEN preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_denials
FROM denials
GROUP BY denial_category
ORDER BY denial_count DESC, total_denied_amount DESC;


-- ERA Payment Lag Summary

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
    ROUND(AVG(era_lag_days), 2) AS avg_era_lag_days,
    MIN(era_lag_days) AS min_era_lag_days,
    MAX(era_lag_days) AS max_era_lag_days,

    SUM(CASE WHEN era_lag_days > 21 THEN 1 ELSE 0 END) AS era_records_over_21_days
FROM era_claims;


-- Payer Performance Summary

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
    COALESCE(ds.total_denied_amount, 0) AS total_denied_amount
FROM payer p
LEFT JOIN claim_summary cs
    ON p.payer_id = cs.payer_id
LEFT JOIN era_summary es
    ON p.payer_id = es.payer_id
LEFT JOIN denial_summary ds
    ON p.payer_id = ds.payer_id
ORDER BY cs.rejected_claims DESC, cs.denied_claims DESC;

-- Enrollment Impact Summary

SELECT
    'Enrollment Impact KPI Summary' AS report_name,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN e.action_required_flag = 'Yes' THEN 1 ELSE 0 END) AS claims_tied_to_action_required_enrollment,

    SUM(
        CASE
            WHEN e.enrollment_type IN ('Claims', 'Claims and ERA')
              AND e.claims_ready_flag <> 'Ready'
            THEN 1
            ELSE 0
        END
    ) AS claims_submitted_while_not_claims_ready,

    SUM(CASE WHEN e.npi_match_status = 'NPI Mismatch' THEN 1 ELSE 0 END) AS claims_tied_to_npi_mismatch,

    SUM(
        CASE
            WHEN e.clearinghouse_portal_updated = 'No'
              OR e.clearinghouse_configuration_status <> 'Completed'
              OR e.blocker_reason = 'Clearinghouse portal not updated'
            THEN 1
            ELSE 0
        END
    ) AS claims_tied_to_clearinghouse_gap,

    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS total_rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS total_denied_claims,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id;


-- Business Recommendations

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