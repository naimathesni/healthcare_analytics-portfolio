-- Project 2: Healthcare claims & ERA  Analytics
-- Script 01: Create database and tables
-- SQL dialect: MySQL
-- Purpose: Build the relational schema for claims, ERA, denial, payer, proider, and enrollment


create database if not exists healthcare_claims_era;
use healthcare_claims_era;

-- Disable foreign key checks temporarily so tables can be dropped and reacreated safely

set foreign_key_checks = 0;


DROP TABLE IF EXISTS denials;
DROP TABLE IF EXISTS era;
DROP TABLE IF EXISTS claims;
DROP TABLE IF EXISTS enrollment;
DROP TABLE IF EXISTS provider;
DROP TABLE IF EXISTS payer;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- Table: payer
-- Grain: One row per payer
-- Purpose: Stores payer details used for claims, ERA, and enrollment analysis
-- ============================================================

CREATE TABLE payer (
    payer_id VARCHAR(20) PRIMARY KEY,
    payer_name VARCHAR(100) NOT NULL,
    payer_type ENUM('Commercial', 'Medicare', 'Medicaid') NOT NULL,
    clearinghouse_payer_id VARCHAR(30) NOT NULL,
    active_flag ENUM('Yes', 'No') NOT NULL DEFAULT 'Yes',

    INDEX idx_payer_name (payer_name),
    INDEX idx_payer_type (payer_type)
) ENGINE = InnoDB;


-- ============================================================
-- Table: provider
-- Grain: One row per provider/practice setup
-- Purpose: Stores provider, practice, specialty, NPI, and tax ID information
-- ============================================================

CREATE TABLE provider (
    provider_id VARCHAR(20) PRIMARY KEY,
    provider_name VARCHAR(100) NOT NULL,
    practice_name VARCHAR(150) NOT NULL,
    specialty VARCHAR(100) NOT NULL,
    individual_npi CHAR(10) NOT NULL,
    group_npi CHAR(10) NOT NULL,
    tax_id CHAR(9) NOT NULL,
    state CHAR(2) NOT NULL,

    INDEX idx_practice_name (practice_name),
    INDEX idx_specialty (specialty),
    INDEX idx_group_npi (group_npi)
) ENGINE = InnoDB;


-- ============================================================
-- Table: enrollment
-- Grain: One row per provider/payer enrollment setup record
-- Purpose: Tracks claims enrollment, ERA enrollment, credentialing, clearinghouse setup, and readiness
-- ============================================================

CREATE TABLE enrollment (
    enrollment_id VARCHAR(20) PRIMARY KEY,
    provider_id VARCHAR(20) NOT NULL,
    payer_id VARCHAR(20) NOT NULL,

    enrollment_type ENUM('Claims', 'ERA', 'Claims and ERA') NOT NULL,

    credentialing_status ENUM('Completed', 'In Progress', 'Not Started') NOT NULL,
    claims_enrollment_status ENUM('Approved', 'Pending', 'Rejected', 'Not Started', 'Not Required') NOT NULL,
    era_enrollment_status ENUM('Approved', 'Pending', 'Rejected', 'Not Started', 'Not Required') NOT NULL,

    clearinghouse_portal_updated ENUM('Yes', 'No') NOT NULL,
    clearinghouse_configuration_status ENUM('Completed', 'In Progress', 'Pending', 'Issue Found', 'Not Started') NOT NULL,

    credentialed_npi CHAR(10) NOT NULL,
    enrolled_npi CHAR(10) NOT NULL,
    npi_match_status ENUM('NPI Match', 'NPI Mismatch') NOT NULL,

    blocker_reason VARCHAR(150) NOT NULL,

    submitted_date DATE NOT NULL,
    approved_date DATE NULL,

    current_status ENUM('Ready', 'Pending', 'Blocked') NOT NULL,
    action_required_flag ENUM('Yes', 'No') NOT NULL,
    claims_ready_flag ENUM('Ready', 'Not Ready', 'Not Applicable') NOT NULL,
    era_ready_flag ENUM('Ready', 'Not Ready', 'Not Applicable') NOT NULL,

    CONSTRAINT fk_enrollment_provider
        FOREIGN KEY (provider_id)
        REFERENCES provider(provider_id),

    CONSTRAINT fk_enrollment_payer
        FOREIGN KEY (payer_id)
        REFERENCES payer(payer_id),

    INDEX idx_enrollment_provider (provider_id),
    INDEX idx_enrollment_payer (payer_id),
    INDEX idx_enrollment_status (current_status),
    INDEX idx_enrollment_action_required (action_required_flag),
    INDEX idx_enrollment_submitted_date (submitted_date)
) ENGINE = InnoDB;


-- ============================================================
-- Table: claims
-- Grain: One row per claim
-- Purpose: Stores claim submission, claim status, billed amount, and payer/provider relationship
-- ============================================================

CREATE TABLE claims (
    claim_id VARCHAR(20) PRIMARY KEY,
    provider_id VARCHAR(20) NOT NULL,
    payer_id VARCHAR(20) NOT NULL,
    enrollment_id VARCHAR(20) NULL,

    patient_id VARCHAR(20) NOT NULL,

    claim_type ENUM('Professional', 'Institutional') NOT NULL,
    service_date DATE NOT NULL,
    claim_submit_date DATE NOT NULL,

    claim_status ENUM('Submitted', 'Paid', 'Denied', 'Rejected', 'Pending') NOT NULL,

    billed_amount DECIMAL(12,2) NOT NULL,
    allowed_amount DECIMAL(12,2) NULL,

    claim_source ENUM('EHR', 'Clearinghouse', 'Manual') NOT NULL,
    created_by VARCHAR(50) NOT NULL,

    CONSTRAINT chk_claim_billed_amount
        CHECK (billed_amount >= 0),

    CONSTRAINT chk_claim_allowed_amount
        CHECK (allowed_amount IS NULL OR allowed_amount >= 0),

    CONSTRAINT fk_claims_provider
        FOREIGN KEY (provider_id)
        REFERENCES provider(provider_id),

    CONSTRAINT fk_claims_payer
        FOREIGN KEY (payer_id)
        REFERENCES payer(payer_id),

    CONSTRAINT fk_claims_enrollment
        FOREIGN KEY (enrollment_id)
        REFERENCES enrollment(enrollment_id),

    INDEX idx_claims_provider (provider_id),
    INDEX idx_claims_payer (payer_id),
    INDEX idx_claims_enrollment (enrollment_id),
    INDEX idx_claims_status (claim_status),
    INDEX idx_claims_submit_date (claim_submit_date),
    INDEX idx_claims_service_date (service_date)
) ENGINE = InnoDB;


-- ============================================================
-- Table: era
-- Grain: One row per claim-level ERA/remittance record
-- Purpose: Stores electronic remittance/payment information for claims
-- ============================================================

CREATE TABLE era (
    era_id VARCHAR(20) PRIMARY KEY,
    claim_id VARCHAR(20) NOT NULL,

    era_date DATE NOT NULL,

    paid_amount DECIMAL(12,2) NOT NULL,
    adjustment_amount DECIMAL(12,2) NOT NULL,
    patient_responsibility DECIMAL(12,2) NOT NULL,

    payment_method ENUM('EFT', 'Check', 'Virtual Card', 'No Payment') NOT NULL,
    era_status ENUM('Received', 'Posted', 'Pending Review', 'Rejected') NOT NULL,

    CONSTRAINT chk_era_paid_amount
        CHECK (paid_amount >= 0),

    CONSTRAINT chk_era_adjustment_amount
        CHECK (adjustment_amount >= 0),

    CONSTRAINT chk_era_patient_responsibility
        CHECK (patient_responsibility >= 0),

    CONSTRAINT fk_era_claim
        FOREIGN KEY (claim_id)
        REFERENCES claims(claim_id),

    INDEX idx_era_claim (claim_id),
    INDEX idx_era_date (era_date),
    INDEX idx_era_status (era_status)
) ENGINE = InnoDB;


-- ============================================================
-- Table: denials
-- Grain: One row per denied claim reason
-- Purpose: Stores denial category, denial reason, denied amount, and preventable flag
-- ============================================================

CREATE TABLE denials (
    denial_id VARCHAR(20) PRIMARY KEY,
    claim_id VARCHAR(20) NOT NULL,

    denial_code VARCHAR(20) NOT NULL,

    denial_category ENUM(
        'Eligibility',
        'Enrollment/Configuration',
        'Authorization',
        'Coding',
        'Timely Filing',
        'Duplicate',
        'Medical Necessity',
        'Other'
    ) NOT NULL,

    denial_reason VARCHAR(255) NOT NULL,
    denied_amount DECIMAL(12,2) NOT NULL,
    denial_date DATE NOT NULL,
    preventable_flag ENUM('Yes', 'No') NOT NULL,

    CONSTRAINT chk_denied_amount
        CHECK (denied_amount >= 0),

    CONSTRAINT fk_denials_claim
        FOREIGN KEY (claim_id)
        REFERENCES claims(claim_id),

    INDEX idx_denials_claim (claim_id),
    INDEX idx_denials_category (denial_category),
    INDEX idx_denials_date (denial_date),
    INDEX idx_denials_preventable (preventable_flag)
) ENGINE = InnoDB;


-- ============================================================
-- Verification queries
-- ============================================================

SHOW TABLES;

SELECT
    table_name,
    table_rows
FROM information_schema.tables
WHERE table_schema = 'healthcare_claims_era'
ORDER BY table_name;