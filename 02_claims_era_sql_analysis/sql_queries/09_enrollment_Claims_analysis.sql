-- ============================================================
-- Project: Healthcare Claims & ERA SQL Analysis
-- Script: 09_enrollment_claims_analysis.sql
-- Topic: Enrollment readiness impact on claims, denials, rejections, and ERA risk
-- SQL dialect: MySQL
-- Purpose:
--   Analyze how claims enrollment, ERA enrollment, NPI match status,
--   clearinghouse setup, payer routing, and enrollment blockers affect
--   claim outcomes and revenue-cycle risk.
-- ============================================================

USE healthcare_claims_era;


-- ============================================================
-- Section 1: Enrollment readiness distribution
-- Business question:
-- What is the overall enrollment readiness status across provider/payer records?
-- ============================================================

SELECT
    current_status,
    action_required_flag,
    COUNT(*) AS enrollment_records,

    SUM(CASE WHEN claims_ready_flag = 'Ready' THEN 1 ELSE 0 END) AS claims_ready_records,
    SUM(CASE WHEN claims_ready_flag = 'Not Ready' THEN 1 ELSE 0 END) AS claims_not_ready_records,
    SUM(CASE WHEN claims_ready_flag = 'Not Applicable' THEN 1 ELSE 0 END) AS claims_not_applicable_records,

    SUM(CASE WHEN era_ready_flag = 'Ready' THEN 1 ELSE 0 END) AS era_ready_records,
    SUM(CASE WHEN era_ready_flag = 'Not Ready' THEN 1 ELSE 0 END) AS era_not_ready_records,
    SUM(CASE WHEN era_ready_flag = 'Not Applicable' THEN 1 ELSE 0 END) AS era_not_applicable_records
FROM enrollment
GROUP BY
    current_status,
    action_required_flag
ORDER BY enrollment_records DESC;


-- ============================================================
-- Section 2: Claim outcomes by claims readiness
-- Business question:
-- Are claims tied to not-ready enrollment records more likely to reject or deny?
-- Join logic:
-- INNER JOIN is used because every claim is expected to have a valid enrollment record.
-- ============================================================

SELECT
    e.claims_ready_flag,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
    SUM(CASE WHEN c.claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

    ROUND(SUM(CASE WHEN c.claim_status = 'Paid' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS paid_rate_percent,
    ROUND(SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent,
    ROUND(SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
GROUP BY e.claims_ready_flag
ORDER BY rejection_rate_percent DESC, denial_rate_percent DESC;


-- ============================================================
-- Section 3: Claim outcomes by enrollment current status
-- Business question:
-- Do Ready, Pending, and Blocked enrollment records show different claim outcomes?
-- ============================================================

SELECT
    e.current_status AS enrollment_status,
    e.action_required_flag,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
    SUM(CASE WHEN c.claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

    ROUND(SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,
    ROUND(SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
GROUP BY
    e.current_status,
    e.action_required_flag
ORDER BY rejection_rate_percent DESC, denial_rate_percent DESC;


-- ============================================================
-- Section 4: Claims submitted while claims enrollment was not ready
-- Business question:
-- Which claims were submitted even though the enrollment record was not claims-ready?
-- Why it matters:
-- This represents front-end claims submission risk.
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
-- Section 5: Financial exposure from claims submitted while not claims-ready
-- Business question:
-- How much billed amount is tied to claims submission risk?
-- ============================================================

SELECT
    e.claims_ready_flag,
    e.current_status AS enrollment_status,

    COUNT(*) AS claims_at_risk,

    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN c.claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
    SUM(CASE WHEN c.claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

    ROUND(SUM(c.billed_amount), 2) AS billed_amount_at_risk,
    ROUND(AVG(c.billed_amount), 2) AS avg_billed_amount_at_risk
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
WHERE e.enrollment_type IN ('Claims', 'Claims and ERA')
  AND e.claims_ready_flag <> 'Ready'
GROUP BY
    e.claims_ready_flag,
    e.current_status
ORDER BY billed_amount_at_risk DESC;


-- ============================================================
-- Section 6: Claim outcomes by NPI match status
-- Business question:
-- Do NPI mismatch records have higher rejection or denial rates?
-- ============================================================

SELECT
    e.npi_match_status,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
    SUM(CASE WHEN c.claim_status = 'Submitted' THEN 1 ELSE 0 END) AS submitted_claims,

    ROUND(SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,
    ROUND(SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
GROUP BY e.npi_match_status
ORDER BY rejection_rate_percent DESC, denial_rate_percent DESC;


-- ============================================================
-- Section 7: Claim outcomes for clearinghouse setup gaps
-- Business question:
-- Are clearinghouse portal/configuration gaps associated with claim problems?
-- ============================================================

SELECT
    CASE
        WHEN e.clearinghouse_portal_updated = 'No'
          OR e.clearinghouse_configuration_status <> 'Completed'
          OR e.blocker_reason = 'Clearinghouse portal not updated'
        THEN 'Clearinghouse Gap'
        ELSE 'No Clearinghouse Gap'
    END AS clearinghouse_gap_group,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,

    ROUND(SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,
    ROUND(SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
GROUP BY clearinghouse_gap_group
ORDER BY rejection_rate_percent DESC, denial_rate_percent DESC;


-- ============================================================
-- Section 8: Claim outcomes by enrollment blocker reason
-- Business question:
-- Which blocker reasons are tied to the most rejected or denied claims?
-- ============================================================

SELECT
    e.blocker_reason,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,

    ROUND(SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,
    ROUND(SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount,
    ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
GROUP BY e.blocker_reason
ORDER BY rejected_claims DESC, denied_claims DESC, issue_billed_amount DESC;


-- ============================================================
-- Section 9: Claim outcomes by operational issue category
-- Business question:
-- Which broader operational issue groups are tied to claim problems?
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

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,

    ROUND(SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,
    ROUND(SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount,
    ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
GROUP BY operational_issue_category
ORDER BY issue_billed_amount DESC, rejected_claims DESC, denied_claims DESC;


-- ============================================================
-- Section 10: Payer and enrollment risk matrix
-- Business question:
-- Which payers have high claim issue volume tied to enrollment readiness?
-- ============================================================

SELECT
    p.payer_name,
    p.payer_type,

    e.current_status AS enrollment_status,
    e.action_required_flag,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

    ROUND(SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,
    ROUND(SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount,
    ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
INNER JOIN payer p
    ON c.payer_id = p.payer_id
GROUP BY
    p.payer_name,
    p.payer_type,
    e.current_status,
    e.action_required_flag
ORDER BY issue_billed_amount DESC, rejected_claims DESC;


-- ============================================================
-- Section 11: Provider/practice enrollment risk matrix
-- Business question:
-- Which practices have the most claim issues tied to enrollment readiness?
-- ============================================================

SELECT
    pr.practice_name,
    pr.specialty,
    pr.state,

    e.current_status AS enrollment_status,
    e.action_required_flag,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

    ROUND(SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_percent,
    ROUND(SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS denial_rate_percent,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount,
    ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
INNER JOIN provider pr
    ON c.provider_id = pr.provider_id
GROUP BY
    pr.practice_name,
    pr.specialty,
    pr.state,
    e.current_status,
    e.action_required_flag
ORDER BY issue_billed_amount DESC, rejected_claims DESC
LIMIT 50;


-- ============================================================
-- Section 12: Enrollment/configuration denials by blocker reason
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
-- Section 13: ERA readiness risk on paid/denied claims
-- Business question:
-- Are paid or denied claims tied to enrollment records that are not ERA-ready?
-- Why it matters:
-- Even if a claim moves forward, ERA readiness issues may create remittance or posting risk.
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
-- Section 14: Claims without ERA by ERA readiness
-- Business question:
-- Which ERA readiness groups have the most claims missing ERA?
-- Join logic:
-- LEFT JOIN + WHERE er.claim_id IS NULL identifies claims without matching ERA records.
-- ============================================================

SELECT
    e.era_ready_flag,
    e.current_status AS enrollment_status,
    e.blocker_reason,

    COUNT(*) AS claims_without_era,
    ROUND(SUM(c.billed_amount), 2) AS billed_amount_without_era
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
LEFT JOIN era er
    ON c.claim_id = er.claim_id
WHERE er.claim_id IS NULL
GROUP BY
    e.era_ready_flag,
    e.current_status,
    e.blocker_reason
ORDER BY claims_without_era DESC, billed_amount_without_era DESC;


-- ============================================================
-- Section 15: Claims with high financial risk from enrollment blockers
-- Business question:
-- Which individual claims should operations review first?
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

    e.enrollment_type,
    e.current_status AS enrollment_status,
    e.claims_ready_flag,
    e.era_ready_flag,
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
WHERE c.claim_status IN ('Rejected', 'Denied', 'Pending')
  AND e.action_required_flag = 'Yes'
ORDER BY c.billed_amount DESC, c.claim_submit_date
LIMIT 100;


-- ============================================================
-- Section 16: Claims tied to payer routing issues
-- Business question:
-- How many claims are tied to wrong or old payer ID issues?
-- ============================================================

SELECT
    e.blocker_reason,

    COUNT(*) AS total_claims,
    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount,
    ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
WHERE e.blocker_reason IN ('Wrong payer ID', 'Old payer ID used')
GROUP BY e.blocker_reason
ORDER BY issue_billed_amount DESC;


-- ============================================================
-- Section 17: Government payer enrollment issue impact
-- Business question:
-- How many claims are tied to Medicare/Medicaid additional enrollment or PTAN issues?
-- ============================================================

SELECT
    p.payer_name,
    p.payer_type,
    e.blocker_reason,

    COUNT(*) AS total_claims,
    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount,
    ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
INNER JOIN payer p
    ON c.payer_id = p.payer_id
WHERE e.blocker_reason IN (
    'Medicare additional enrollment missing',
    'Medicaid additional enrollment missing',
    'Incorrect PTAN/provider number'
)
GROUP BY
    p.payer_name,
    p.payer_type,
    e.blocker_reason
ORDER BY issue_billed_amount DESC, rejected_claims DESC;


-- ============================================================
-- Section 18: Operational priority score for enrollment-related claim issues
-- Business question:
-- Which blocker reasons should operations prioritize first?
-- Logic:
-- Score weights rejected claims, denied claims, billed amount at issue, and enrollment/configuration denials.
-- ============================================================

SELECT
    e.blocker_reason,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,

    ROUND(SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END), 2) AS issue_billed_amount,

    SUM(CASE WHEN d.denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) AS enrollment_configuration_denials,

    ROUND(
        (
            SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) * 2.0
            + SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) * 1.5
            + SUM(CASE WHEN d.denial_category = 'Enrollment/Configuration' THEN 1 ELSE 0 END) * 2.5
            + SUM(CASE WHEN c.claim_status IN ('Rejected', 'Denied') THEN c.billed_amount ELSE 0 END) / 1000
        ),
        2
    ) AS operational_priority_score
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id
LEFT JOIN denials d
    ON c.claim_id = d.claim_id
WHERE e.blocker_reason <> 'No blocker'
GROUP BY e.blocker_reason
ORDER BY operational_priority_score DESC;


-- ============================================================
-- Section 19: Enrollment impact KPI summary for documentation
-- Business question:
-- What enrollment impact KPIs should be documented in the project README?
-- ============================================================

SELECT
    'Enrollment Impact KPI Summary' AS report_name,

    COUNT(*) AS total_claims,

    SUM(CASE WHEN e.action_required_flag = 'Yes' THEN 1 ELSE 0 END) AS claims_tied_to_action_required_enrollment,

    SUM(CASE WHEN e.enrollment_type IN ('Claims', 'Claims and ERA')
              AND e.claims_ready_flag <> 'Ready'
             THEN 1 ELSE 0 END) AS claims_submitted_while_not_claims_ready,

    SUM(CASE WHEN e.npi_match_status = 'NPI Mismatch' THEN 1 ELSE 0 END) AS claims_tied_to_npi_mismatch,

    SUM(CASE WHEN e.clearinghouse_portal_updated = 'No'
               OR e.clearinghouse_configuration_status <> 'Completed'
               OR e.blocker_reason = 'Clearinghouse portal not updated'
             THEN 1 ELSE 0 END) AS claims_tied_to_clearinghouse_gap,

    SUM(CASE WHEN c.claim_status = 'Rejected' THEN 1 ELSE 0 END) AS total_rejected_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END) AS total_denied_claims,

    ROUND(SUM(c.billed_amount), 2) AS total_billed_amount
FROM claims c
INNER JOIN enrollment e
    ON c.enrollment_id = e.enrollment_id;


-- ============================================================
-- Analyst Notes
-- ============================================================

-- Key interpretation:
-- Enrollment readiness should be analyzed before claim submission because not-ready
-- enrollment records can create rejection, denial, ERA, and payment flow risk.

-- Important distinction:
-- Claims readiness risk is usually more urgent than ERA readiness risk because claims
-- must submit successfully before ERA can be received.

-- Operational takeaway:
-- Claims submitted while claims_ready_flag <> 'Ready' should be reviewed first,
-- especially when tied to NPI mismatch, clearinghouse gaps, payer routing issues,
-- or government payer enrollment requirements.

-- My observation:
-- Claims tied to not ready enrollment records show meaningful rejection and denial exposure, which support adding pre-submission readiness validation.

-- Follow-up question:
-- which payer and blocker reason combination creates the highest rejected billed amount?