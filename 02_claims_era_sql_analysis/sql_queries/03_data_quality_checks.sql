-- Project 2: Healthcare Claims & ERA SQL Analytics
-- Script 03: Data Quality checks
-- SQL Dialect: MySQL
-- Purpose: Validate row counts, relationships, statuses, dates, and readiness logic before analysis




USE healthcare_claims_era;

-- ============================================================
-- Data Quality Check Report
-- Expected result: every row should show Pass
-- ============================================================

WITH checks AS (

    -- ------------------------------------------------------------
    -- Row count checks
    -- ------------------------------------------------------------

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


    -- ------------------------------------------------------------
    -- Missing primary key checks
    -- ------------------------------------------------------------

    UNION ALL
    SELECT 'Missing payer_id', 0, COUNT(*)
    FROM payer
    WHERE payer_id IS NULL OR TRIM(payer_id) = ''

    UNION ALL
    SELECT 'Missing provider_id', 0, COUNT(*)
    FROM provider
    WHERE provider_id IS NULL OR TRIM(provider_id) = ''

    UNION ALL
    SELECT 'Missing enrollment_id', 0, COUNT(*)
    FROM enrollment
    WHERE enrollment_id IS NULL OR TRIM(enrollment_id) = ''

    UNION ALL
    SELECT 'Missing claim_id', 0, COUNT(*)
    FROM claims
    WHERE claim_id IS NULL OR TRIM(claim_id) = ''

    UNION ALL
    SELECT 'Missing era_id', 0, COUNT(*)
    FROM era
    WHERE era_id IS NULL OR TRIM(era_id) = ''

    UNION ALL
    SELECT 'Missing denial_id', 0, COUNT(*)
    FROM denials
    WHERE denial_id IS NULL OR TRIM(denial_id) = ''


    -- ------------------------------------------------------------
    -- Duplicate primary key checks
    -- These should be impossible because of primary key constraints,
    -- but we still document the check.
    -- ------------------------------------------------------------

    UNION ALL
    SELECT 'Duplicate payer_id', 0, COUNT(*)
    FROM (
        SELECT payer_id
        FROM payer
        GROUP BY payer_id
        HAVING COUNT(*) > 1
    ) d

    UNION ALL
    SELECT 'Duplicate provider_id', 0, COUNT(*)
    FROM (
        SELECT provider_id
        FROM provider
        GROUP BY provider_id
        HAVING COUNT(*) > 1
    ) d

    UNION ALL
    SELECT 'Duplicate enrollment_id', 0, COUNT(*)
    FROM (
        SELECT enrollment_id
        FROM enrollment
        GROUP BY enrollment_id
        HAVING COUNT(*) > 1
    ) d

    UNION ALL
    SELECT 'Duplicate claim_id', 0, COUNT(*)
    FROM (
        SELECT claim_id
        FROM claims
        GROUP BY claim_id
        HAVING COUNT(*) > 1
    ) d

    UNION ALL
    SELECT 'Duplicate era_id', 0, COUNT(*)
    FROM (
        SELECT era_id
        FROM era
        GROUP BY era_id
        HAVING COUNT(*) > 1
    ) d

    UNION ALL
    SELECT 'Duplicate denial_id', 0, COUNT(*)
    FROM (
        SELECT denial_id
        FROM denials
        GROUP BY denial_id
        HAVING COUNT(*) > 1
    ) d


    -- ------------------------------------------------------------
    -- Status validation checks
    -- These should be controlled by ENUM fields, but we still verify.
    -- ------------------------------------------------------------

    UNION ALL
    SELECT 'Invalid claim_status values', 0, COUNT(*)
    FROM claims
    WHERE claim_status NOT IN ('Submitted', 'Paid', 'Denied', 'Rejected', 'Pending')

    UNION ALL
    SELECT 'Invalid current_status values', 0, COUNT(*)
    FROM enrollment
    WHERE current_status NOT IN ('Ready', 'Pending', 'Blocked')

    UNION ALL
    SELECT 'Invalid action_required_flag values', 0, COUNT(*)
    FROM enrollment
    WHERE action_required_flag NOT IN ('Yes', 'No')

    UNION ALL
    SELECT 'Invalid claims_ready_flag values', 0, COUNT(*)
    FROM enrollment
    WHERE claims_ready_flag NOT IN ('Ready', 'Not Ready', 'Not Applicable')

    UNION ALL
    SELECT 'Invalid era_ready_flag values', 0, COUNT(*)
    FROM enrollment
    WHERE era_ready_flag NOT IN ('Ready', 'Not Ready', 'Not Applicable')

    UNION ALL
    SELECT 'Invalid era_status values', 0, COUNT(*)
    FROM era
    WHERE era_status NOT IN ('Received', 'Posted', 'Pending Review', 'Rejected')

    UNION ALL
    SELECT 'Invalid denial_category values', 0, COUNT(*)
    FROM denials
    WHERE denial_category NOT IN (
        'Eligibility',
        'Enrollment/Configuration',
        'Authorization',
        'Coding',
        'Timely Filing',
        'Duplicate',
        'Medical Necessity',
        'Other'
    )


    -- ------------------------------------------------------------
    -- Relationship / orphan record checks
    -- ------------------------------------------------------------

    UNION ALL
    SELECT 'Claims missing valid payer', 0, COUNT(*)
    FROM claims c
    LEFT JOIN payer p
        ON c.payer_id = p.payer_id
    WHERE p.payer_id IS NULL

    UNION ALL
    SELECT 'Claims missing valid provider', 0, COUNT(*)
    FROM claims c
    LEFT JOIN provider pr
        ON c.provider_id = pr.provider_id
    WHERE pr.provider_id IS NULL

    UNION ALL
    SELECT 'Claims missing valid enrollment', 0, COUNT(*)
    FROM claims c
    LEFT JOIN enrollment e
        ON c.enrollment_id = e.enrollment_id
    WHERE c.enrollment_id IS NOT NULL
      AND e.enrollment_id IS NULL

    UNION ALL
    SELECT 'Enrollment missing valid payer', 0, COUNT(*)
    FROM enrollment e
    LEFT JOIN payer p
        ON e.payer_id = p.payer_id
    WHERE p.payer_id IS NULL

    UNION ALL
    SELECT 'Enrollment missing valid provider', 0, COUNT(*)
    FROM enrollment e
    LEFT JOIN provider pr
        ON e.provider_id = pr.provider_id
    WHERE pr.provider_id IS NULL

    UNION ALL
    SELECT 'ERA missing valid claim', 0, COUNT(*)
    FROM era er
    LEFT JOIN claims c
        ON er.claim_id = c.claim_id
    WHERE c.claim_id IS NULL

    UNION ALL
    SELECT 'Denials missing valid claim', 0, COUNT(*)
    FROM denials d
    LEFT JOIN claims c
        ON d.claim_id = c.claim_id
    WHERE c.claim_id IS NULL


    -- ------------------------------------------------------------
    -- Claim / ERA / denial consistency checks
    -- ------------------------------------------------------------

    UNION ALL
    SELECT 'Denied claims without denial record', 0, COUNT(*)
    FROM claims c
    LEFT JOIN denials d
        ON c.claim_id = d.claim_id
    WHERE c.claim_status = 'Denied'
      AND d.claim_id IS NULL

    UNION ALL
    SELECT 'Denial records linked to non-denied claims', 0, COUNT(*)
    FROM denials d
    INNER JOIN claims c
        ON d.claim_id = c.claim_id
    WHERE c.claim_status <> 'Denied'

    UNION ALL
    SELECT 'Paid/Denied claims without ERA', 0, COUNT(*)
    FROM claims c
    LEFT JOIN era er
        ON c.claim_id = er.claim_id
    WHERE c.claim_status IN ('Paid', 'Denied')
      AND er.claim_id IS NULL

    UNION ALL
    SELECT 'ERA records linked to non-paid/non-denied claims', 0, COUNT(*)
    FROM era er
    INNER JOIN claims c
        ON er.claim_id = c.claim_id
    WHERE c.claim_status NOT IN ('Paid', 'Denied')

    UNION ALL
    SELECT 'Claims with multiple ERA records', 0, COUNT(*)
    FROM (
        SELECT claim_id
        FROM era
        GROUP BY claim_id
        HAVING COUNT(*) > 1
    ) d


    -- ------------------------------------------------------------
    -- Financial amount checks
    -- ------------------------------------------------------------

    UNION ALL
    SELECT 'Claims with negative billed amount', 0, COUNT(*)
    FROM claims
    WHERE billed_amount < 0

    UNION ALL
    SELECT 'Claims with negative allowed amount', 0, COUNT(*)
    FROM claims
    WHERE allowed_amount < 0

    UNION ALL
    SELECT 'ERA with negative paid amount', 0, COUNT(*)
    FROM era
    WHERE paid_amount < 0

    UNION ALL
    SELECT 'ERA with negative adjustment amount', 0, COUNT(*)
    FROM era
    WHERE adjustment_amount < 0

    UNION ALL
    SELECT 'ERA with negative patient responsibility', 0, COUNT(*)
    FROM era
    WHERE patient_responsibility < 0

    UNION ALL
    SELECT 'Denials with negative denied amount', 0, COUNT(*)
    FROM denials
    WHERE denied_amount < 0

    UNION ALL
    SELECT 'ERA payment math mismatch', 0, COUNT(*)
    FROM era er
    INNER JOIN claims c
        ON er.claim_id = c.claim_id
    WHERE ABS((er.paid_amount + er.adjustment_amount + er.patient_responsibility) - c.billed_amount) > 0.05


    -- ------------------------------------------------------------
    -- Date logic checks
    -- ------------------------------------------------------------

    UNION ALL
    SELECT 'Claims where service date is after submit date', 0, COUNT(*)
    FROM claims
    WHERE service_date > claim_submit_date

    UNION ALL
    SELECT 'ERA date before claim submit date', 0, COUNT(*)
    FROM era er
    INNER JOIN claims c
        ON er.claim_id = c.claim_id
    WHERE er.era_date < c.claim_submit_date

    UNION ALL
    SELECT 'Denial date before claim submit date', 0, COUNT(*)
    FROM denials d
    INNER JOIN claims c
        ON d.claim_id = c.claim_id
    WHERE d.denial_date < c.claim_submit_date

    UNION ALL
    SELECT 'Enrollment approved before submitted', 0, COUNT(*)
    FROM enrollment
    WHERE approved_date IS NOT NULL
      AND approved_date < submitted_date


    -- ------------------------------------------------------------
    -- Enrollment readiness logic checks
    -- ------------------------------------------------------------

    UNION ALL
    SELECT 'NPI match flag mismatch', 0, COUNT(*)
    FROM enrollment
    WHERE (
            credentialed_npi = enrolled_npi
            AND npi_match_status <> 'NPI Match'
          )
       OR (
            credentialed_npi <> enrolled_npi
            AND npi_match_status <> 'NPI Mismatch'
          )

    UNION ALL
    SELECT 'Action required flag mismatch', 0, COUNT(*)
    FROM enrollment
    WHERE (
            blocker_reason = 'No blocker'
            AND action_required_flag <> 'No'
          )
       OR (
            blocker_reason <> 'No blocker'
            AND action_required_flag <> 'Yes'
          )

    UNION ALL
    SELECT 'Claims ready flag mismatch', 0, COUNT(*)
    FROM enrollment
    WHERE claims_ready_flag <>
        CASE
            WHEN enrollment_type = 'ERA' THEN 'Not Applicable'
            WHEN blocker_reason = 'No blocker' THEN 'Ready'
            ELSE 'Not Ready'
        END

    UNION ALL
    SELECT 'ERA ready flag mismatch', 0, COUNT(*)
    FROM enrollment
    WHERE era_ready_flag <>
        CASE
            WHEN enrollment_type = 'Claims' THEN 'Not Applicable'
            WHEN blocker_reason = 'No blocker' THEN 'Ready'
            ELSE 'Not Ready'
        END
)

SELECT
    check_name,
    expected_count,
    actual_count,
    CASE
        WHEN expected_count = actual_count THEN 'Pass'
        ELSE 'Check'
    END AS check_status
FROM checks
ORDER BY
    CASE
        WHEN expected_count = actual_count THEN 1
        ELSE 0
    END,
    check_name;


-- ============================================================
-- Helpful row count summaries
-- These are not pass/fail checks. They are quick reference summaries.
-- ============================================================

SELECT
    claim_status,
    COUNT(*) AS claim_count
FROM claims
GROUP BY claim_status
ORDER BY claim_count DESC;

SELECT
    denial_category,
    COUNT(*) AS denial_count
FROM denials
GROUP BY denial_category
ORDER BY denial_count DESC;

SELECT
    blocker_reason,
    COUNT(*) AS enrollment_record_count
FROM enrollment
GROUP BY blocker_reason
ORDER BY enrollment_record_count DESC;

SELECT
    payer_name,
    payer_type,
    COUNT(*) AS claim_count
FROM claims c
INNER JOIN payer p
    ON c.payer_id = p.payer_id
GROUP BY
    payer_name,
    payer_type
ORDER BY claim_count DESC;