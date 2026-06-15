-- Project 2: Healthcare Claims & ERA SQL Analysis
-- Script 06: Join Queries
-- Topic: Multi-table joins for claims, ERA, payer, provider, denial, and enrollment analysis
-- SQL dialect: MySQL
-- Purpose: Join core healthcare revenue-cycle tables to analyze  payer, provider, enrollment, ERA, and denial 
-- context around claims

USE healthcare_claims_era;


-- ============================================================
-- Section 1: Claims with payer context
-- Business question:
-- Which payers are associated with each claim?
-- ============================================================

SELECT
    c.claim_id,
    c.claim_submit_date,
    c.claim_status,
    c.billed_amount,
    c.allowed_amount,
    p.payer_id,
    p.payer_name,
    p.payer_type,
    p.clearinghouse_payer_id
FROM claims c
INNER JOIN payer p
    ON c.payer_id = p.payer_id
ORDER BY c.claim_id
LIMIT 50;


-- ============================================================
-- Section 2: Claims with provider context
-- Business question:
-- Which providers and practices are associated with each claim?
-- ============================================================

SELECT
    c.claim_id,
    c.claim_submit_date,
    c.claim_status,
    c.billed_amount,
    pr.provider_id,
    pr.provider_name,
    pr.practice_name,
    pr.specialty,
    pr.state
FROM claims c
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
ORDER BY c.claim_id
LIMIT 50;


-- ============================================================
-- Section 3: Claims with payer and provider context
-- Business question:
-- Show claim-level details with payer and practice context.
-- ============================================================

SELECT
    c.claim_id,
    c.claim_type,
    c.service_date,
    c.claim_submit_date,
    c.claim_status,
    c.billed_amount,
    c.allowed_amount,

    p.payer_name,
    p.payer_type,

    pr.provider_name,
    pr.practice_name,
    pr.specialty,
    pr.state
FROM claims c
INNER JOIN payer p
    ON c.payer_id = p.payer_id
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
ORDER BY c.claim_submit_date, c.claim_id
LIMIT 100;


-- ============================================================
-- Section 4: Claims with enrollment context
-- Business question:
-- What enrollment readiness status is tied to each claim?
-- ============================================================

SELECT
    c.claim_id,
    c.claim_submit_date,
    c.claim_status,
    c.billed_amount,

    e.enrollment_id,
    e.enrollment_type,
    e.current_status AS enrollment_current_status,
    e.blocker_reason,
    e.action_required_flag,
    e.claims_ready_flag,
    e.era_ready_flag,
    e.npi_match_status
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
ORDER BY c.claim_id
LIMIT 100;


-- ============================================================
-- Section 5: Claims with ERA context
-- Business question:
-- Which claims have ERA/remittance records?
-- ============================================================

SELECT
    c.claim_id,
    c.claim_status,
    c.claim_submit_date,
    c.billed_amount,
    c.allowed_amount,

    er.era_id,
    er.era_date,
    er.paid_amount,
    er.adjustment_amount,
    er.patient_responsibility,
    er.payment_method,
    er.era_status
FROM claims c
INNER JOIN era er
    ON c.claim_id = er.claim_id
ORDER BY c.claim_id
LIMIT 100;


-- ============================================================
-- Section 6: Claims without ERA context
-- Business question:
-- Which claims do not have an ERA record?
-- ============================================================

SELECT
    c.claim_id,
    c.claim_status,
    c.claim_submit_date,
    c.billed_amount,
    c.allowed_amount
FROM claims c
LEFT JOIN era er
    ON c.claim_id = er.claim_id
WHERE er.claim_id IS NULL
ORDER BY c.claim_submit_date, c.claim_id
LIMIT 100;


-- Expected:
-- Claims with no ERA are usually Submitted, Pending, or Rejected.


-- ============================================================
-- Section 7: Paid or denied claims without ERA check
-- Business question:
-- Are any finalized claims missing ERA records?
-- ============================================================

SELECT
    c.claim_status,
    COUNT(*) AS finalized_claims_without_era
FROM claims c
LEFT JOIN era er
    ON c.claim_id = er.claim_id
WHERE c.claim_status IN ('Paid', 'Denied')
  AND er.claim_id IS NULL
GROUP BY c.claim_status;


-- Expected:
-- This should return no rows if data quality is good.


-- ============================================================
-- Section 8: Claims with denials context
-- Business question:
-- Which denied claims have denial reason details?
-- ============================================================

SELECT
    c.claim_id,
    c.claim_submit_date,
    c.claim_status,
    c.billed_amount,
    c.allowed_amount,
    d.denial_id,
    d.denial_code,
    d.denial_category,
    d.denial_reason,
    d.denied_amount,
    d.preventable_flag
FROM claims c
INNER JOIN denials d
    ON c.claim_id = d.claim_id
ORDER BY d.denied_amount DESC
LIMIT 100;


-- ============================================================
-- Section 8A: Audit check - Denied claims missing denial detials
-- Business question:
-- are any denied claims missing a denial record?
-- Expected result:
-- No rows
-- ============================================================

SELECT
    c.claim_id,
    c.claim_submit_date,
    c.claim_status,
    c.billed_amount
    
FROM claims c
LEFT JOIN denials d
    ON c.claim_id = d.claim_id
WHERE c.claim_status = "Denied"
AND d.claim_id is null;


-- ============================================================
-- Section 9: Full claim detail with payer, provider, enrollment, ERA, and denial context
-- Business question:
-- What is the complete operational story for each claim?
-- ============================================================

SELECT
    c.claim_id,
    c.claim_type,
    c.service_date,
    c.claim_submit_date,
    c.claim_status,
    c.billed_amount,
    c.allowed_amount,

    p.payer_name,
    p.payer_type,

    pr.provider_name,
    pr.practice_name,
    pr.specialty,
    pr.state,

    e.enrollment_type,
    e.current_status AS enrollment_status,
    e.blocker_reason,
    e.action_required_flag,
    e.claims_ready_flag,
    e.era_ready_flag,
    e.npi_match_status,

    er.era_date,
    er.paid_amount,
    er.adjustment_amount,
    er.patient_responsibility,
    er.era_status,

    d.denial_category,
    d.denial_reason,
    d.denied_amount,
    d.preventable_flag
FROM claims c
INNER JOIN payer p
    ON c.payer_id = p.payer_id
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
LEFT JOIN era er
    ON c.claim_id = er.claim_id
LEFT JOIN denials d
    ON c.claim_id = d.claim_id
ORDER BY c.claim_submit_date, c.claim_id
LIMIT 100;


-- ============================================================
-- Section 10: Claim status by payer
-- Business question:
-- Which payers have the most paid, denied, rejected, pending, and submitted claims?
-- ============================================================

SELECT
    p.payer_name,
    p.payer_type,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
    SUM(CASE WHEN c.claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

    ROUND(SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent,
    ROUND(SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount
FROM claims c
INNER JOIN payer p
    ON c.payer_id = p.payer_id
GROUP BY
    p.payer_name,
    p.payer_type
ORDER BY rejected_claims DESC, denied_claims DESC;


-- ============================================================
-- Section 11: Claim status by provider/practice
-- Business question:
-- Which practices have the most claim issues?
-- ============================================================

SELECT
    pr.practice_name,
    pr.specialty,
    pr.state,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
    SUM(CASE WHEN c.claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

    ROUND(SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent,
    ROUND(SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount
FROM claims c
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
GROUP BY
    pr.practice_name,
    pr.specialty,
    pr.state
ORDER BY rejected_claims DESC, denied_claims DESC;


-- ============================================================
-- Section 12: Enrollment readiness impact on claim status
-- Business question:
-- Are claims tied to not-ready enrollment records more likely to reject or deny?
-- ============================================================

SELECT
    e.claims_ready_flag,
    e.current_status AS enrollment_status,
    e.action_required_flag,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
    SUM(CASE WHEN c.claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

    ROUND(SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,
    ROUND(SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
GROUP BY
    e.claims_ready_flag,
    e.current_status,
    e.action_required_flag
ORDER BY rejection_rate_percent DESC, denial_rate_percent DESC;


-- ============================================================
-- Section 13: Top blocker reasons connected to rejected claims
-- Business question:
-- Which enrollment blockers appear most often on rejected claims?
-- ============================================================

SELECT
    e.blocker_reason,
    COUNT(*) AS rejected_claims,
    ROUND(SUM(c.billed_amount), 2) AS rejected_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
WHERE c.claim_status = 'Rejected'
GROUP BY e.blocker_reason
ORDER BY rejected_claims DESC, rejected_billed_amount DESC;


-- ============================================================
-- Section 14: Top blocker reasons connected to denied claims
-- Business question:
-- Which enrollment blockers appear most often on denied claims?
-- ============================================================

SELECT
    e.blocker_reason,
    COUNT(*) AS denied_claims,
    ROUND(SUM(c.billed_amount), 2) AS denied_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
WHERE c.claim_status = 'Denied'
GROUP BY e.blocker_reason
ORDER BY denied_claims DESC, denied_billed_amount DESC;


-- ============================================================
-- Section 15: Enrollment/configuration denials with payer and provider context
-- Business question:
-- Which payers and practices are tied to enrollment/configuration denials?
-- ============================================================

SELECT
    d.denial_id,
    c.claim_id,
    c.claim_submit_date,
    c.billed_amount,

    p.payer_name,
    p.payer_type,

    pr.practice_name,
    pr.specialty,

    e.blocker_reason,
    e.npi_match_status,
    e.claims_ready_flag,
    e.era_ready_flag,

    d.denial_code,
    d.denial_category,
    d.denial_reason,
    d.denied_amount,
    d.preventable_flag
FROM denials d
INNER JOIN claims c
    ON d.claim_id = c.claim_id
INNER JOIN payer p
    ON c.payer_id = p.payer_id
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
WHERE d.denial_category = 'Enrollment/Configuration'
ORDER BY d.denied_amount DESC
LIMIT 100;


-- ============================================================
-- Section 16: Claims with no ERA by payer
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
ORDER BY claims_without_era DESC;


-- ============================================================
-- Section 17: ERA payment lag with payer context
-- Business question:
-- Which payers have longer payment/remittance turnaround?
-- ============================================================

SELECT
    p.payer_name,
    p.payer_type,

    COUNT(*) AS era_records,

    ROUND(AVG(DATEDIFF(er.era_date, c.claim_submit_date)), 2) AS avg_era_lag_days,
    MIN(DATEDIFF(er.era_date, c.claim_submit_date)) AS min_era_lag_days,
    MAX(DATEDIFF(er.era_date, c.claim_submit_date)) AS max_era_lag_days,

    ROUND(SUM(er.paid_amount), 2) AS total_paid_amount,
    ROUND(SUM(er.adjustment_amount), 2) AS total_adjustment_amount
FROM era er
INNER JOIN claims c
    ON er.claim_id = c.claim_id
INNER JOIN payer p
    ON c.payer_id = p.payer_id
GROUP BY
    p.payer_name,
    p.payer_type
ORDER BY avg_era_lag_days DESC;


-- ============================================================
-- Section 18: Provider/practice payment summary
-- Business question:
-- Which practices have the highest paid amount?
-- ============================================================

SELECT
    pr.practice_name,
    pr.specialty,
    pr.state,

    COUNT(DISTINCT c.claim_id) AS total_claims,
    COUNT(DISTINCT er.era_id) AS total_era_records,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount,
    ROUND(SUM(COALESCE(er.paid_amount, 0)), 2) AS total_paid_amount,
    ROUND(SUM(COALESCE(er.adjustment_amount, 0)), 2) AS total_adjustment_amount
FROM claims c
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
LEFT JOIN era er
    ON c.claim_id = er.claim_id
GROUP BY
    pr.practice_name,
    pr.specialty,
    pr.state
ORDER BY total_paid_amount DESC
LIMIT 25;


-- ============================================================
-- Section 19: Claims submitted while enrollment was not claims-ready
-- Business question:
-- Which claims were submitted despite claims enrollment not being ready?
-- ============================================================

SELECT
    c.claim_id,
    c.claim_submit_date,
    c.claim_status,
    c.billed_amount,

    p.payer_name,
    pr.practice_name,

    e.enrollment_type,
    e.current_status AS enrollment_status,
    e.claims_ready_flag,
    e.blocker_reason,
    e.npi_match_status
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
INNER JOIN payer p
    ON c.payer_id = p.payer_id
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
WHERE e.enrollment_type IN ('Claims', 'Claims and ERA')
  AND e.claims_ready_flag <> 'Ready'
ORDER BY c.claim_submit_date, c.claim_id
LIMIT 100;


-- ============================================================
-- Section 20: Claims with preventable denials and full business context
-- Business question:
-- Which preventable denials should operations prioritize?
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

    e.blocker_reason,
    e.claims_ready_flag,
    e.era_ready_flag,
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
LIMIT 100;


-- ============================================================
-- Analyst Notes
-- ============================================================

-- Most important join pattern:
-- claims is the central fact table for this project.
-- Most analysis starts from claims and joins outward to payer, provider, enrollment, ERA, and denials.

-- Most useful business join:
-- claims + enrollment shows whether rejected/denied claims are tied to claims readiness,
-- NPI mismatch, payer setup, or clearinghouse configuration issues.

-- Analyst takeaway:
-- Rejections and denials should not be reviewed only at the claim level.
-- They need payer, provider, enrollment, ERA, and denial context to identify root causes.