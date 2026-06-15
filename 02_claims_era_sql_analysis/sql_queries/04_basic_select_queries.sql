
-- Porject 2: Healthcare Claims & ERA SQL Analysis
-- Script 04: Basic SELECT queries
-- SQL dialect: MySQL
-- Purpose: Practice basic data retrieval, filtering, sorting, and table exploration

USE healthcare_claims_era;


-- ============================================================
-- Section 1: Preview core tables
-- Purpose: Quickly understand what each table contains
-- ============================================================

-- 1. Preview payer records
SELECT
    payer_id,
    payer_name,
    payer_type,
    clearinghouse_payer_id,
    active_flag
FROM payer
ORDER BY payer_id;


-- 2. Preview provider records
SELECT
    provider_id,
    provider_name,
    practice_name,
    specialty,
    individual_npi,
    group_npi,
    state
FROM provider
ORDER BY provider_id
LIMIT 20;


-- 3. Preview enrollment records
SELECT
    enrollment_id,
    provider_id,
    payer_id,
    enrollment_type,
    credentialing_status,
    claims_enrollment_status,
    era_enrollment_status,
    current_status,
    blocker_reason,
    action_required_flag,
    claims_ready_flag,
    era_ready_flag
FROM enrollment
ORDER BY enrollment_id
LIMIT 25;


-- 4. Preview claim records
SELECT
    claim_id,
    provider_id,
    payer_id,
    enrollment_id,
    claim_type,
    service_date,
    claim_submit_date,
    claim_status,
    billed_amount,
    allowed_amount,
    claim_source
FROM claims
ORDER BY claim_id
LIMIT 25;


-- 5. Preview ERA records
SELECT
    era_id,
    claim_id,
    era_date,
    paid_amount,
    adjustment_amount,
    patient_responsibility,
    payment_method,
    era_status
FROM era
ORDER BY era_id
LIMIT 25;


-- 6. Preview denial records
SELECT
    denial_id,
    claim_id,
    denial_code,
    denial_category,
    denial_reason,
    denied_amount,
    denial_date,
    preventable_flag
FROM denials
ORDER BY denial_id
LIMIT 25;


-- ============================================================
-- Section 2: Filter claims by status
-- Purpose: Find claims by operational status
-- ============================================================

-- 7. View paid claims
SELECT
    claim_id,
    provider_id,
    payer_id,
    claim_submit_date,
    claim_status,
    billed_amount,
    allowed_amount
FROM claims
WHERE claim_status = 'Paid'
ORDER BY claim_submit_date
LIMIT 25;


-- 8. View denied claims
SELECT
    claim_id,
    provider_id,
    payer_id,
    claim_submit_date,
    claim_status,
    billed_amount,
    allowed_amount
FROM claims
WHERE claim_status = 'Denied'
ORDER BY claim_submit_date
LIMIT 25;


-- 9. View rejected claims
SELECT
    claim_id,
    provider_id,
    payer_id,
    claim_submit_date,
    claim_status,
    billed_amount
FROM claims
WHERE claim_status = 'Rejected'
ORDER BY claim_submit_date
LIMIT 25;


-- 10. View claims still not finalized
SELECT
    claim_id,
    provider_id,
    payer_id,
    claim_submit_date,
    claim_status,
    billed_amount
FROM claims
WHERE claim_status IN ('Submitted', 'Pending')
ORDER BY claim_submit_date
LIMIT 25;


-- ============================================================
-- Section 3: Filter claims by date
-- Purpose: Find claims submitted in specific time windows
-- ============================================================

-- 11. Claims submitted in January 2026
SELECT
    claim_id,
    provider_id,
    payer_id,
    service_date,
    claim_submit_date,
    claim_status,
    billed_amount
FROM claims
WHERE claim_submit_date BETWEEN '2026-01-01' AND '2026-01-31'
ORDER BY claim_submit_date;


-- 12. Claims submitted after March 1, 2026
SELECT
    claim_id,
    provider_id,
    payer_id,
    service_date,
    claim_submit_date,
    claim_status,
    billed_amount
FROM claims
WHERE claim_submit_date >= '2026-03-01'
ORDER BY claim_submit_date
LIMIT 50;


-- 13. Claims where service date and submit date are different
SELECT
    claim_id,
    service_date,
    claim_submit_date,
    DATEDIFF(claim_submit_date, service_date) AS days_from_service_to_submit,
    claim_status,
    billed_amount
FROM claims
WHERE service_date <> claim_submit_date
ORDER BY days_from_service_to_submit DESC
LIMIT 25;


-- ============================================================
-- Section 4: Filter high-dollar claims
-- Purpose: Identify claims with larger billed amounts
-- ============================================================

-- 14. Top 25 highest billed claims
SELECT
    claim_id,
    provider_id,
    payer_id,
    claim_status,
    claim_submit_date,
    billed_amount,
    allowed_amount
FROM claims
ORDER BY billed_amount DESC
LIMIT 25;


-- 15. Claims with billed amount greater than 1,000
SELECT
    claim_id,
    provider_id,
    payer_id,
    claim_status,
    billed_amount,
    allowed_amount
FROM claims
WHERE billed_amount > 1000
ORDER BY billed_amount DESC
LIMIT 50;


-- 16. Denied claims with billed amount greater than 1,000
SELECT
    claim_id,
    provider_id,
    payer_id,
    claim_status,
    billed_amount,
    allowed_amount
FROM claims
WHERE claim_status = 'Denied'
  AND billed_amount > 1000
ORDER BY billed_amount DESC
LIMIT 50;


-- ============================================================
-- Section 5: Explore enrollment readiness records
-- Purpose: Review readiness issues tied to EDI enrollment workflows
-- ============================================================

-- 17. Enrollment records that are ready
SELECT
    enrollment_id,
    provider_id,
    payer_id,
    enrollment_type,
    current_status,
    blocker_reason,
    claims_ready_flag,
    era_ready_flag
FROM enrollment
WHERE current_status = 'Ready'
ORDER BY enrollment_id
LIMIT 25;


-- 18. Enrollment records that are blocked
SELECT
    enrollment_id,
    provider_id,
    payer_id,
    enrollment_type,
    current_status,
    blocker_reason,
    action_required_flag,
    claims_ready_flag,
    era_ready_flag
FROM enrollment
WHERE current_status = 'Blocked'
ORDER BY enrollment_id
LIMIT 25;


-- 19. Enrollment records requiring action
SELECT
    enrollment_id,
    provider_id,
    payer_id,
    enrollment_type,
    current_status,
    blocker_reason,
    action_required_flag
FROM enrollment
WHERE action_required_flag = 'Yes'
ORDER BY enrollment_id
LIMIT 25;


-- 20. Enrollment records with NPI mismatch
SELECT
    enrollment_id,
    provider_id,
    payer_id,
    credentialed_npi,
    enrolled_npi,
    npi_match_status,
    blocker_reason
FROM enrollment
WHERE npi_match_status = 'NPI Mismatch'
ORDER BY enrollment_id
LIMIT 25;


-- 21. Enrollment records with clearinghouse portal gaps
SELECT
    enrollment_id,
    provider_id,
    payer_id,
    enrollment_type,
    clearinghouse_portal_updated,
    clearinghouse_configuration_status,
    blocker_reason
FROM enrollment
WHERE clearinghouse_portal_updated = 'No'
   OR blocker_reason = 'Clearinghouse portal not updated'
ORDER BY enrollment_id
LIMIT 25;


-- ============================================================
-- Section 6: Explore denial records
-- Purpose: Review denial categories and preventable denials
-- ============================================================

-- 22. Preventable denials
SELECT
    denial_id,
    claim_id,
    denial_code,
    denial_category,
    denial_reason,
    denied_amount,
    denial_date,
    preventable_flag
FROM denials
WHERE preventable_flag = 'Yes'
ORDER BY denied_amount DESC
LIMIT 25;


-- 23. Enrollment/configuration denials
SELECT
    denial_id,
    claim_id,
    denial_code,
    denial_category,
    denial_reason,
    denied_amount,
    denial_date
FROM denials
WHERE denial_category = 'Enrollment/Configuration'
ORDER BY denied_amount DESC
LIMIT 25;


-- 24. High-dollar denials
SELECT
    denial_id,
    claim_id,
    denial_category,
    denial_reason,
    denied_amount,
    denial_date
FROM denials
WHERE denied_amount > 500
ORDER BY denied_amount DESC
LIMIT 25;


-- ============================================================
-- Section 7: Explore ERA records
-- Purpose: Review payment/remittance data
-- ============================================================

-- 25. Posted ERA records
SELECT
    era_id,
    claim_id,
    era_date,
    paid_amount,
    adjustment_amount,
    patient_responsibility,
    payment_method,
    era_status
FROM era
WHERE era_status = 'Posted'
ORDER BY era_date
LIMIT 25;


-- 26. ERA records pending review
SELECT
    era_id,
    claim_id,
    era_date,
    paid_amount,
    adjustment_amount,
    patient_responsibility,
    payment_method,
    era_status
FROM era
WHERE era_status = 'Pending Review'
ORDER BY era_date
LIMIT 25;


-- 27. High-payment ERA records
SELECT
    era_id,
    claim_id,
    era_date,
    paid_amount,
    adjustment_amount,
    patient_responsibility,
    payment_method,
    era_status
FROM era
WHERE paid_amount > 500
ORDER BY paid_amount DESC
LIMIT 25;


-- ============================================================
-- Section 8: Distinct values
-- Purpose: Understand available categories in the dataset
-- ============================================================

-- 28. Distinct claim statuses
SELECT DISTINCT
    claim_status
FROM claims
ORDER BY claim_status;


-- 29. Distinct enrollment statuses
SELECT DISTINCT
    current_status
FROM enrollment
ORDER BY current_status;


-- 30. Distinct enrollment blocker reasons
SELECT DISTINCT
    blocker_reason
FROM enrollment
ORDER BY blocker_reason;


-- 31. Distinct denial categories
SELECT DISTINCT
    denial_category
FROM denials
ORDER BY denial_category;


-- 32. Distinct payer types
SELECT DISTINCT
    payer_type
FROM payer
ORDER BY payer_type;


-- ============================================================
-- Section 9: LIKE filtering
-- Purpose: Search text fields
-- ============================================================

-- 33. Find practices with "Family" in the name
SELECT
    provider_id,
    provider_name,
    practice_name,
    specialty,
    state
FROM provider
WHERE practice_name LIKE '%Family%'
ORDER BY practice_name;


-- 34. Find denial reasons mentioning setup
SELECT
    denial_id,
    claim_id,
    denial_category,
    denial_reason,
    denied_amount
FROM denials
WHERE denial_reason LIKE '%setup%'
ORDER BY denied_amount DESC;


-- ============================================================
-- Section 10: NULL checks in analysis context
-- Purpose: Understand where values are expected to be missing
-- ============================================================

-- 35. Claims with no allowed amount
-- Expected: Submitted, Pending, and Rejected claims may not have allowed amounts yet.
SELECT
    claim_id,
    claim_status,
    billed_amount,
    allowed_amount
FROM claims
WHERE allowed_amount IS NULL
ORDER BY claim_id
LIMIT 50;


-- 36. Enrollment records without approved dates
-- Expected: Pending and blocked records may not have approval dates.
SELECT
    enrollment_id,
    provider_id,
    payer_id,
    current_status,
    submitted_date,
    approved_date,
    blocker_reason
FROM enrollment
WHERE approved_date IS NULL
ORDER BY submitted_date
LIMIT 50;


-- ============================================================
-- Section 11: Business-friendly starter questions
-- Purpose: Translate simple business questions into SQL
-- ============================================================

-- 37. Which claims are not fully resolved yet?
SELECT
    claim_id,
    provider_id,
    payer_id,
    claim_submit_date,
    claim_status,
    billed_amount
FROM claims
WHERE claim_status IN ('Submitted', 'Pending', 'Rejected')
ORDER BY claim_submit_date
LIMIT 50;


-- 38. Which enrollment records may create claims submission risk?
SELECT
    enrollment_id,
    provider_id,
    payer_id,
    enrollment_type,
    current_status,
    claims_ready_flag,
    blocker_reason
FROM enrollment
WHERE enrollment_type IN ('Claims', 'Claims and ERA')
  AND claims_ready_flag <> 'Ready'
ORDER BY enrollment_id
LIMIT 50;


-- 39. Which enrollment records may create ERA receipt risk?
SELECT
    enrollment_id,
    provider_id,
    payer_id,
    enrollment_type,
    current_status,
    era_ready_flag,
    blocker_reason
FROM enrollment
WHERE enrollment_type IN ('ERA', 'Claims and ERA')
  AND era_ready_flag <> 'Ready'
ORDER BY enrollment_id
LIMIT 50;


-- 40. Which denied claims have preventable denial reasons?
SELECT
    denial_id,
    claim_id,
    denial_category,
    denial_reason,
    denied_amount,
    preventable_flag
FROM denials
WHERE preventable_flag = 'Yes'
ORDER BY denied_amount DESC
LIMIT 50;


-- ===========================================================
My 5 most useful beginner queries from this script
-- ===========================================================

1. SELECT
    claim_id,
    service_date,
    claim_submit_date,
    DATEDIFF(claim_submit_date, service_date) AS days_from_service_to_submit,
    claim_status,
    billed_amount
FROM claims
WHERE service_date <> claim_submit_date
ORDER BY days_from_service_to_submit DESC
LIMIT 25;

2. SELECT
    claim_id,
    provider_id,
    payer_id,
    claim_status,
    billed_amount,
    allowed_amount
FROM claims
WHERE claim_status = 'Denied'
  AND billed_amount > 1000
ORDER BY billed_amount DESC
LIMIT 50;

3. SELECT
    denial_id,
    claim_id,
    denial_category,
    denial_reason,
    denied_amount,
    preventable_flag
FROM denials
WHERE preventable_flag = 'Yes'
ORDER BY denied_amount DESC
LIMIT 50;


4. SELECT
    enrollment_id,
    provider_id,
    payer_id,
    enrollment_type,
    current_status,
    claims_ready_flag,
    blocker_reason
FROM enrollment
WHERE enrollment_type IN ('Claims', 'Claims and ERA')
  AND claims_ready_flag <> 'Ready'
ORDER BY enrollment_id
LIMIT 50;

5. SELECT
    enrollment_id,
    provider_id,
    payer_id,
    enrollment_type,
    clearinghouse_portal_updated,
    clearinghouse_configuration_status,
    blocker_reason
FROM enrollment
WHERE clearinghouse_portal_updated = 'No'
   OR blocker_reason = 'Clearinghouse portal not updated'
ORDER BY enrollment_id
LIMIT 25;