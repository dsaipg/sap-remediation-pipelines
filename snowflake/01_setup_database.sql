-- ============================================================
-- SAP REMEDIATION POC — Database & Schema Setup
-- Run this FIRST in your Snowflake SQL Worksheet
-- ============================================================

-- Use ACCOUNTADMIN for initial setup
USE ROLE ACCOUNTADMIN;

-- Create a dedicated warehouse for the POC
CREATE WAREHOUSE IF NOT EXISTS SAP_REMEDIATION_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse for SAP Remediation POC';

-- Create the main database
CREATE DATABASE IF NOT EXISTS SAP_REMEDIATION
  COMMENT = 'SAP S/4HANA Data Model Remediation POC';

-- Create Medallion schemas
CREATE SCHEMA IF NOT EXISTS SAP_REMEDIATION.BRONZE
  COMMENT = 'Raw ingested SAP ECC tables — no transformation';

CREATE SCHEMA IF NOT EXISTS SAP_REMEDIATION.SILVER
  COMMENT = 'Cleaned and conformed SAP data — type casting, dedup, null handling';

CREATE SCHEMA IF NOT EXISTS SAP_REMEDIATION.GOLD
  COMMENT = 'Business-ready consolidated tables — consumed by reports';

-- Test schema for agent-driven changes (Phase 4)
CREATE SCHEMA IF NOT EXISTS SAP_REMEDIATION.TEST_REMEDIATION
  COMMENT = 'Agent sandbox — new pipeline code tested here before promotion';

-- Schema for NEW S/4HANA model (simulates what comes from Foundry in Phase 3)
CREATE SCHEMA IF NOT EXISTS SAP_REMEDIATION.NEW_MODEL
  COMMENT = 'New SAP S/4HANA data model tables — source of truth for migration';

-- Grant usage
USE WAREHOUSE SAP_REMEDIATION_WH;

-- Verify
SHOW SCHEMAS IN DATABASE SAP_REMEDIATION;

SELECT 'Setup complete! You should see: BRONZE, SILVER, GOLD, TEST_REMEDIATION, NEW_MODEL' AS status;
