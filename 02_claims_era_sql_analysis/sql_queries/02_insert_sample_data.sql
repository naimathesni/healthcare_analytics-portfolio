-- Script 02: Insert synthetic sample data
-- SQL dialect: MySQL
-- Purpose: Load synthetic payer, provider, enrollment, claims, ERA, and denial data

USE healthcare_claims_era;

-- Clear existing data in dependency order.
SET FOREIGN_KEY_CHECKS = 0;

DELETE FROM denials;
DELETE FROM era;
DELETE FROM claims;
DELETE FROM enrollment;
DELETE FROM provider;
DELETE FROM payer;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- Load payer reference data
-- Grain: One row per payer
-- ============================================================

INSERT INTO payer (
    payer_id,
    payer_name,
    payer_type,
    clearinghouse_payer_id,
    active_flag
)
VALUES
('PYR001', 'Medicare', 'Medicare', 'MED001', 'Yes'),
('PYR002', 'Medicaid', 'Medicaid', 'MCD002', 'Yes'),
('PYR003', 'Blue Cross', 'Commercial', 'BCBS01', 'Yes'),
('PYR004', 'United Healthcare', 'Commercial', 'UHC001', 'Yes'),
('PYR005', 'Aetna', 'Commercial', 'AET001', 'Yes'),
('PYR006', 'Cigna', 'Commercial', 'CIG001', 'Yes'),
('PYR007', 'Humana', 'Commercial', 'HUM001', 'Yes'),
('PYR008', 'Molina Healthcare', 'Medicaid', 'MOL008', 'Yes'),
('PYR009', 'Kaiser Permanente', 'Commercial', 'KAI009', 'Yes'),
('PYR010', 'Tricare', 'Commercial', 'TRI010', 'Yes');


-- ============================================================
-- Load synthetic providers
-- Grain: One row per provider/practice setup
-- ============================================================

DROP PROCEDURE IF EXISTS load_providers;

DELIMITER $$

CREATE PROCEDURE load_providers()
BEGIN
    DECLARE p INT DEFAULT 1;

    WHILE p <= 40 DO

        INSERT INTO provider (
            provider_id,
            provider_name,
            practice_name,
            specialty,
            individual_npi,
            group_npi,
            tax_id,
            state
        )
        VALUES (
            CONCAT('PRV', LPAD(p, 3, '0')),

            CONCAT(
                ELT(
                    MOD(p, 16) + 1,
                    'Dr. Asha Menon',
                    'Dr. Daniel Lee',
                    'Dr. Priya Shah',
                    'Dr. Mark Wilson',
                    'Dr. Vivek Nair',
                    'Dr. Emily Chen',
                    'Dr. Rohan Patel',
                    'Dr. Sara Khan',
                    'Dr. Kavya Iyer',
                    'Dr. Thomas Gray',
                    'Dr. Isha Kapoor',
                    'Dr. Omar Ali',
                    'Dr. Lily Morgan',
                    'Dr. Sanjay Mehta',
                    'Dr. Hannah Scott',
                    'Dr. Grace Miller'
                ),
                ' ',
                LPAD(p, 2, '0')
            ),

            ELT(
                MOD(p, 20) + 1,
                'River Valley Family Care',
                'Northside Pediatrics',
                'Greenway Internal Medicine',
                'Lakeside Women Health',
                'Hillcrest Orthopedics',
                'BrightCare Cardiology',
                'Cedar Grove Clinic',
                'Oak Street Primary Care',
                'Westbrook Dermatology',
                'Summit Eye Care',
                'Pine Ridge Family Clinic',
                'Silverline Neurology',
                'Maple Leaf Urgent Care',
                'Southview Endocrinology',
                'Blue Harbor ENT',
                'Valley View Gastro',
                'Riverside Behavioral Health',
                'Sunrise Family Medicine',
                'Metro Spine Center',
                'Parkside Oncology'
            ),

            ELT(
                MOD(p, 12) + 1,
                'Family Practice',
                'Internal Medicine',
                'Pediatrics',
                'Cardiology',
                'Orthopedic Surgery',
                'Dermatology',
                'Neurology',
                'Endocrinology',
                'Gastroenterology',
                'Behavioral Health',
                'Oncology',
                'ENT'
            ),

            CONCAT('1', LPAD(p, 9, '0')),
            CONCAT('2', LPAD(MOD(p - 1, 20) + 1, 9, '0')),
            CONCAT('9', LPAD(p, 8, '0')),

            ELT(
                MOD(p, 8) + 1,
                'CA',
                'TX',
                'NY',
                'FL',
                'IL',
                'PA',
                'GA',
                'NC'
            )
        );

        SET p = p + 1;

    END WHILE;
END $$

DELIMITER ;

CALL load_providers();

DROP PROCEDURE IF EXISTS load_providers;


-- ============================================================
-- Load synthetic enrollment records
-- Grain: One row per provider/payer enrollment setup
-- 40 providers x 10 payers = 400 enrollment records
-- ============================================================

DROP PROCEDURE IF EXISTS load_enrollments;

DELIMITER $$

CREATE PROCEDURE load_enrollments()
BEGIN
    DECLARE p INT DEFAULT 1;
    DECLARE q INT DEFAULT 1;

    DECLARE v_provider_id VARCHAR(20);
    DECLARE v_payer_id VARCHAR(20);
    DECLARE v_enrollment_id VARCHAR(20);

    DECLARE v_group_npi CHAR(10);
    DECLARE v_individual_npi CHAR(10);
    DECLARE v_credentialed_npi CHAR(10);
    DECLARE v_enrolled_npi CHAR(10);
    DECLARE v_npi_match_status VARCHAR(20);

    DECLARE v_enrollment_type VARCHAR(20);
    DECLARE v_blocker VARCHAR(150);

    DECLARE v_credentialing_status VARCHAR(20);
    DECLARE v_claims_enrollment_status VARCHAR(20);
    DECLARE v_era_enrollment_status VARCHAR(20);
    DECLARE v_portal_updated VARCHAR(5);
    DECLARE v_config_status VARCHAR(30);
    DECLARE v_current_status VARCHAR(20);
    DECLARE v_action_required VARCHAR(5);
    DECLARE v_claims_ready VARCHAR(20);
    DECLARE v_era_ready VARCHAR(20);

    DECLARE v_submitted_date DATE;
    DECLARE v_approved_date DATE;

    WHILE p <= 40 DO

        SET q = 1;

        WHILE q <= 10 DO

            SET v_provider_id = CONCAT('PRV', LPAD(p, 3, '0'));
            SET v_payer_id = CONCAT('PYR', LPAD(q, 3, '0'));
            SET v_enrollment_id = CONCAT('ENR', LPAD(p, 3, '0'), LPAD(q, 3, '0'));

            SELECT group_npi, individual_npi
            INTO v_group_npi, v_individual_npi
            FROM provider
            WHERE provider_id = v_provider_id;

            SET v_enrollment_type =
                CASE
                    WHEN MOD(p + q, 5) = 0 THEN 'ERA'
                    WHEN MOD(p + q, 3) = 0 THEN 'Claims'
                    ELSE 'Claims and ERA'
                END;

            SET v_blocker =
                CASE
                    WHEN MOD(p + q, 17) = 0 THEN 'Credentialing not completed'
                    WHEN MOD(p * q, 23) = 0 THEN 'Credentialed NPI mismatch'
                    WHEN MOD(p + q, 11) = 0 THEN 'Individual NPI used instead of group NPI'
                    WHEN q IN (1, 2, 8) AND MOD(p + q, 9) = 0 THEN 'Incorrect PTAN/provider number'
                    WHEN q = 1 AND MOD(p, 7) = 0 THEN 'Medicare additional enrollment missing'
                    WHEN q IN (2, 8) AND MOD(p, 8) = 0 THEN 'Medicaid additional enrollment missing'
                    WHEN MOD(p + q, 5) = 0 THEN 'Clearinghouse portal not updated'
                    WHEN MOD(p * q, 7) = 0 THEN 'Wrong payer ID'
                    WHEN MOD(p + q, 6) = 0 THEN 'Missing payer approval'
                    WHEN v_enrollment_type <> 'Claims' AND MOD(p * q, 19) = 0 THEN 'ERA setup not completed'
                    ELSE 'No blocker'
                END;

            SET v_credentialed_npi = v_group_npi;

            IF v_blocker = 'Individual NPI used instead of group NPI' THEN
                SET v_enrolled_npi = v_individual_npi;
            ELSEIF v_blocker = 'Credentialed NPI mismatch' THEN
                SET v_enrolled_npi = CONCAT('8', RIGHT(v_group_npi, 9));
            ELSE
                SET v_enrolled_npi = v_group_npi;
            END IF;

            SET v_npi_match_status =
                CASE
                    WHEN v_credentialed_npi = v_enrolled_npi THEN 'NPI Match'
                    ELSE 'NPI Mismatch'
                END;

            IF v_blocker = 'No blocker' THEN

                SET v_credentialing_status = 'Completed';
                SET v_claims_enrollment_status =
                    CASE
                        WHEN v_enrollment_type = 'ERA' THEN 'Not Required'
                        ELSE 'Approved'
                    END;
                SET v_era_enrollment_status =
                    CASE
                        WHEN v_enrollment_type = 'Claims' THEN 'Not Required'
                        ELSE 'Approved'
                    END;
                SET v_portal_updated = 'Yes';
                SET v_config_status = 'Completed';
                SET v_current_status = 'Ready';
                SET v_action_required = 'No';

            ELSEIF v_blocker = 'Credentialing not completed' THEN

                SET v_credentialing_status = 'In Progress';
                SET v_claims_enrollment_status =
                    CASE
                        WHEN v_enrollment_type = 'ERA' THEN 'Not Required'
                        ELSE 'Not Started'
                    END;
                SET v_era_enrollment_status =
                    CASE
                        WHEN v_enrollment_type = 'Claims' THEN 'Not Required'
                        ELSE 'Not Started'
                    END;
                SET v_portal_updated = 'No';
                SET v_config_status = 'Not Started';
                SET v_current_status = 'Pending';
                SET v_action_required = 'Yes';

            ELSEIF v_blocker = 'Missing payer approval' THEN

                SET v_credentialing_status = 'Completed';
                SET v_claims_enrollment_status =
                    CASE
                        WHEN v_enrollment_type = 'ERA' THEN 'Not Required'
                        ELSE 'Pending'
                    END;
                SET v_era_enrollment_status =
                    CASE
                        WHEN v_enrollment_type = 'Claims' THEN 'Not Required'
                        ELSE 'Pending'
                    END;
                SET v_portal_updated = 'Yes';
                SET v_config_status = 'In Progress';
                SET v_current_status = 'Pending';
                SET v_action_required = 'Yes';

            ELSEIF v_blocker = 'Clearinghouse portal not updated' THEN

                SET v_credentialing_status = 'Completed';
                SET v_claims_enrollment_status =
                    CASE
                        WHEN v_enrollment_type = 'ERA' THEN 'Not Required'
                        ELSE 'Approved'
                    END;
                SET v_era_enrollment_status =
                    CASE
                        WHEN v_enrollment_type = 'Claims' THEN 'Not Required'
                        ELSE 'Approved'
                    END;
                SET v_portal_updated = 'No';
                SET v_config_status = 'Pending';
                SET v_current_status = 'Pending';
                SET v_action_required = 'Yes';

            ELSEIF v_blocker = 'ERA setup not completed' THEN

                SET v_credentialing_status = 'Completed';
                SET v_claims_enrollment_status =
                    CASE
                        WHEN v_enrollment_type = 'ERA' THEN 'Not Required'
                        ELSE 'Approved'
                    END;
                SET v_era_enrollment_status = 'Pending';
                SET v_portal_updated = 'Yes';
                SET v_config_status = 'In Progress';
                SET v_current_status = 'Pending';
                SET v_action_required = 'Yes';

            ELSE

                SET v_credentialing_status = 'Completed';
                SET v_claims_enrollment_status =
                    CASE
                        WHEN v_enrollment_type = 'ERA' THEN 'Not Required'
                        ELSE 'Rejected'
                    END;
                SET v_era_enrollment_status =
                    CASE
                        WHEN v_enrollment_type = 'Claims' THEN 'Not Required'
                        ELSE 'Rejected'
                    END;
                SET v_portal_updated = 'Yes';
                SET v_config_status = 'Issue Found';
                SET v_current_status = 'Blocked';
                SET v_action_required = 'Yes';

            END IF;

            SET v_claims_ready =
                CASE
                    WHEN v_enrollment_type = 'ERA' THEN 'Not Applicable'
                    WHEN v_blocker = 'No blocker' THEN 'Ready'
                    ELSE 'Not Ready'
                END;

            SET v_era_ready =
                CASE
                    WHEN v_enrollment_type = 'Claims' THEN 'Not Applicable'
                    WHEN v_blocker = 'No blocker' THEN 'Ready'
                    ELSE 'Not Ready'
                END;

            SET v_submitted_date = DATE_ADD('2026-01-01', INTERVAL MOD((p * 7) + (q * 11), 150) DAY);

            SET v_approved_date =
                CASE
                    WHEN v_blocker = 'No blocker'
                    THEN DATE_ADD(v_submitted_date, INTERVAL 8 + MOD(p + q, 10) DAY)
                    ELSE NULL
                END;

            INSERT INTO enrollment (
                enrollment_id,
                provider_id,
                payer_id,
                enrollment_type,
                credentialing_status,
                claims_enrollment_status,
                era_enrollment_status,
                clearinghouse_portal_updated,
                clearinghouse_configuration_status,
                credentialed_npi,
                enrolled_npi,
                npi_match_status,
                blocker_reason,
                submitted_date,
                approved_date,
                current_status,
                action_required_flag,
                claims_ready_flag,
                era_ready_flag
            )
            VALUES (
                v_enrollment_id,
                v_provider_id,
                v_payer_id,
                v_enrollment_type,
                v_credentialing_status,
                v_claims_enrollment_status,
                v_era_enrollment_status,
                v_portal_updated,
                v_config_status,
                v_credentialed_npi,
                v_enrolled_npi,
                v_npi_match_status,
                v_blocker,
                v_submitted_date,
                v_approved_date,
                v_current_status,
                v_action_required,
                v_claims_ready,
                v_era_ready
            );

            SET q = q + 1;

        END WHILE;

        SET p = p + 1;

    END WHILE;
END $$

DELIMITER ;

CALL load_enrollments();

DROP PROCEDURE IF EXISTS load_enrollments;


-- ============================================================
-- Load synthetic claims, ERA records, and denials
-- Grain:
-- claims = one row per claim
-- era = one row per claim-level remittance record
-- denials = one row per denied claim reason
-- ============================================================

DROP PROCEDURE IF EXISTS load_claims_era_denials;

DELIMITER $$

CREATE PROCEDURE load_claims_era_denials()
BEGIN
    DECLARE i INT DEFAULT 1;

    DECLARE v_provider_num INT;
    DECLARE v_payer_num INT;

    DECLARE v_provider_id VARCHAR(20);
    DECLARE v_payer_id VARCHAR(20);
    DECLARE v_enrollment_id VARCHAR(20);

    DECLARE v_claim_id VARCHAR(20);
    DECLARE v_blocker VARCHAR(150);
    DECLARE v_claims_ready VARCHAR(20);
    DECLARE v_era_ready VARCHAR(20);

    DECLARE v_claim_status VARCHAR(20);
    DECLARE v_claim_type VARCHAR(20);

    DECLARE v_service_date DATE;
    DECLARE v_submit_date DATE;
    DECLARE v_era_date DATE;

    DECLARE v_billed DECIMAL(12,2);
    DECLARE v_allowed DECIMAL(12,2);
    DECLARE v_paid DECIMAL(12,2);
    DECLARE v_adjustment DECIMAL(12,2);
    DECLARE v_patient_resp DECIMAL(12,2);

    DECLARE v_denial_category VARCHAR(50);
    DECLARE v_denial_code VARCHAR(20);
    DECLARE v_denial_reason VARCHAR(255);
    DECLARE v_preventable VARCHAR(5);

    WHILE i <= 1500 DO

        SET v_provider_num = MOD(i, 40) + 1;
        SET v_payer_num = MOD(i * 7, 10) + 1;

        SET v_provider_id = CONCAT('PRV', LPAD(v_provider_num, 3, '0'));
        SET v_payer_id = CONCAT('PYR', LPAD(v_payer_num, 3, '0'));
        SET v_enrollment_id = CONCAT('ENR', LPAD(v_provider_num, 3, '0'), LPAD(v_payer_num, 3, '0'));
        SET v_claim_id = CONCAT('CLM', LPAD(i, 6, '0'));

        SELECT blocker_reason, claims_ready_flag, era_ready_flag
        INTO v_blocker, v_claims_ready, v_era_ready
        FROM enrollment
        WHERE enrollment_id = v_enrollment_id;

        IF v_claims_ready = 'Ready' THEN

            IF MOD(i, 20) <= 13 THEN
                SET v_claim_status = 'Paid';
            ELSEIF MOD(i, 20) <= 16 THEN
                SET v_claim_status = 'Denied';
            ELSEIF MOD(i, 20) = 17 THEN
                SET v_claim_status = 'Pending';
            ELSE
                SET v_claim_status = 'Submitted';
            END IF;

        ELSE

            IF MOD(i, 20) <= 8 THEN
                SET v_claim_status = 'Rejected';
            ELSEIF MOD(i, 20) <= 12 THEN
                SET v_claim_status = 'Denied';
            ELSEIF MOD(i, 20) <= 16 THEN
                SET v_claim_status = 'Pending';
            ELSE
                SET v_claim_status = 'Submitted';
            END IF;

        END IF;

        SET v_claim_type =
            CASE
                WHEN MOD(i, 8) = 0 THEN 'Institutional'
                ELSE 'Professional'
            END;

        SET v_service_date = DATE_ADD('2026-01-01', INTERVAL MOD(i, 150) DAY);
        SET v_submit_date = DATE_ADD(v_service_date, INTERVAL 1 + MOD(i, 6) DAY);

        SET v_billed = ROUND(100 + MOD(i * 37, 1200) + (MOD(i, 5) * 19.75), 2);

        IF v_claim_status IN ('Paid', 'Denied') THEN
            SET v_allowed = ROUND(v_billed * (0.45 + (MOD(i, 5) * 0.05)), 2);
        ELSE
            SET v_allowed = NULL;
        END IF;

        INSERT INTO claims (
            claim_id,
            provider_id,
            payer_id,
            enrollment_id,
            patient_id,
            claim_type,
            service_date,
            claim_submit_date,
            claim_status,
            billed_amount,
            allowed_amount,
            claim_source,
            created_by
        )
        VALUES (
            v_claim_id,
            v_provider_id,
            v_payer_id,
            v_enrollment_id,
            CONCAT('PAT', LPAD(MOD(i, 500) + 1, 6, '0')),
            v_claim_type,
            v_service_date,
            v_submit_date,
            v_claim_status,
            v_billed,
            v_allowed,
            ELT(MOD(i, 3) + 1, 'EHR', 'Clearinghouse', 'Manual'),
            ELT(MOD(i, 6) + 1, 'owner_01', 'owner_02', 'owner_03', 'owner_04', 'owner_05', 'owner_06')
        );

        IF v_claim_status IN ('Paid', 'Denied') THEN

            SET v_era_date = DATE_ADD(v_submit_date, INTERVAL 7 + MOD(i, 28) DAY);

            IF v_claim_status = 'Paid' THEN
                SET v_patient_resp = ROUND(v_allowed * (MOD(i, 4) * 0.05), 2);
                SET v_paid = ROUND(GREATEST(v_allowed - v_patient_resp, 0), 2);
                SET v_adjustment = ROUND(GREATEST(v_billed - v_allowed, 0), 2);
            ELSE
                SET v_patient_resp = 0.00;
                SET v_paid = 0.00;
                SET v_adjustment = ROUND(v_billed, 2);
            END IF;

            INSERT INTO era (
                era_id,
                claim_id,
                era_date,
                paid_amount,
                adjustment_amount,
                patient_responsibility,
                payment_method,
                era_status
            )
            VALUES (
                CONCAT('ERA', LPAD(i, 6, '0')),
                v_claim_id,
                v_era_date,
                v_paid,
                v_adjustment,
                v_patient_resp,
                IF(v_claim_status = 'Paid', ELT(MOD(i, 3) + 1, 'EFT', 'Check', 'Virtual Card'), 'No Payment'),
                IF(MOD(i, 9) = 0, 'Pending Review', 'Posted')
            );

        END IF;

        IF v_claim_status = 'Denied' THEN

            IF v_blocker IN (
                'Individual NPI used instead of group NPI',
                'Credentialed NPI mismatch',
                'Clearinghouse portal not updated',
                'Wrong payer ID',
                'Old payer ID used',
                'Medicare additional enrollment missing',
                'Medicaid additional enrollment missing',
                'Incorrect PTAN/provider number'
            ) THEN
                SET v_denial_category = 'Enrollment/Configuration';
            ELSEIF MOD(i, 6) = 0 THEN
                SET v_denial_category = 'Eligibility';
            ELSEIF MOD(i, 6) = 1 THEN
                SET v_denial_category = 'Authorization';
            ELSEIF MOD(i, 6) = 2 THEN
                SET v_denial_category = 'Coding';
            ELSEIF MOD(i, 6) = 3 THEN
                SET v_denial_category = 'Medical Necessity';
            ELSEIF MOD(i, 6) = 4 THEN
                SET v_denial_category = 'Timely Filing';
            ELSE
                SET v_denial_category = 'Duplicate';
            END IF;

            SET v_denial_code =
                CASE v_denial_category
                    WHEN 'Eligibility' THEN 'CO-27'
                    WHEN 'Enrollment/Configuration' THEN 'CO-109'
                    WHEN 'Authorization' THEN 'CO-197'
                    WHEN 'Coding' THEN 'CO-16'
                    WHEN 'Timely Filing' THEN 'CO-29'
                    WHEN 'Duplicate' THEN 'CO-18'
                    WHEN 'Medical Necessity' THEN 'CO-50'
                    ELSE 'CO-96'
                END;

            SET v_denial_reason =
                CASE v_denial_category
                    WHEN 'Eligibility' THEN 'Patient coverage inactive or eligibility not verified'
                    WHEN 'Enrollment/Configuration' THEN 'Provider, payer, NPI, PTAN, or clearinghouse setup issue'
                    WHEN 'Authorization' THEN 'Prior authorization missing or invalid'
                    WHEN 'Coding' THEN 'Invalid or incomplete coding information'
                    WHEN 'Timely Filing' THEN 'Claim submitted after timely filing limit'
                    WHEN 'Duplicate' THEN 'Duplicate claim submission'
                    WHEN 'Medical Necessity' THEN 'Service not considered medically necessary'
                    ELSE 'Other denial reason'
                END;

            SET v_preventable =
                IF(
                    v_denial_category IN (
                        'Eligibility',
                        'Enrollment/Configuration',
                        'Authorization',
                        'Timely Filing',
                        'Duplicate'
                    ),
                    'Yes',
                    'No'
                );

            INSERT INTO denials (
                denial_id,
                claim_id,
                denial_code,
                denial_category,
                denial_reason,
                denied_amount,
                denial_date,
                preventable_flag
            )
            VALUES (
                CONCAT('DEN', LPAD(i, 6, '0')),
                v_claim_id,
                v_denial_code,
                v_denial_category,
                v_denial_reason,
                IFNULL(v_allowed, v_billed),
                v_era_date,
                v_preventable
            );

        END IF;

        SET i = i + 1;

    END WHILE;
END $$

DELIMITER ;

CALL load_claims_era_denials();

DROP PROCEDURE IF EXISTS load_claims_era_denials;


-- ============================================================
-- Validation queries
-- ============================================================

SELECT 'payer' AS table_name, COUNT(*) AS row_count FROM payer
UNION ALL
SELECT 'provider' AS table_name, COUNT(*) AS row_count FROM provider
UNION ALL
SELECT 'enrollment' AS table_name, COUNT(*) AS row_count FROM enrollment
UNION ALL
SELECT 'claims' AS table_name, COUNT(*) AS row_count FROM claims
UNION ALL
SELECT 'era' AS table_name, COUNT(*) AS row_count FROM era
UNION ALL
SELECT 'denials' AS table_name, COUNT(*) AS row_count FROM denials;

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