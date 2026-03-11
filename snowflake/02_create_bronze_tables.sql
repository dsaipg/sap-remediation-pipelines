-- ============================================================
-- SAP REMEDIATION POC — Bronze Layer Tables (OLD SAP ECC Model)
-- These represent the CURRENT state of raw ingested SAP data
-- ============================================================

USE DATABASE SAP_REMEDIATION;
USE SCHEMA BRONZE;
USE WAREHOUSE SAP_REMEDIATION_WH;

-- ────────────────────────────────────────────────────────────
-- 1. BKPF — Accounting Document Header
--    One row per accounting document (invoice, payment, etc.)
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE BKPF (
    MANDT       VARCHAR(3)      COMMENT 'Client (SAP system ID)',
    BUKRS       VARCHAR(4)      COMMENT 'Company Code',
    BELNR       VARCHAR(10)     COMMENT 'Accounting Document Number',
    GJAHR       VARCHAR(4)      COMMENT 'Fiscal Year',
    BLART       VARCHAR(2)      COMMENT 'Document Type (SA=GL, KR=Vendor Invoice, DR=Customer Invoice)',
    BLDAT       DATE            COMMENT 'Document Date',
    BUDAT       DATE            COMMENT 'Posting Date',
    MONAT       VARCHAR(2)      COMMENT 'Fiscal Period',
    CPUDT       DATE            COMMENT 'Entry Date (when entered in system)',
    USNAM       VARCHAR(12)     COMMENT 'User Name who created document',
    TCODE       VARCHAR(20)     COMMENT 'Transaction Code used',
    BKTXT       VARCHAR(25)     COMMENT 'Document Header Text',
    WAERS       VARCHAR(5)      COMMENT 'Currency Key',
    KURSF       NUMBER(9,5)     COMMENT 'Exchange Rate',
    XBLNR       VARCHAR(16)     COMMENT 'Reference Document Number',
    STBLG       VARCHAR(10)     COMMENT 'Reverse Document Number',
    STJAH       VARCHAR(4)      COMMENT 'Reverse Document Fiscal Year',
    _LOADED_AT  TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP() COMMENT 'ETL load timestamp'
);

-- ────────────────────────────────────────────────────────────
-- 2. BSEG — Accounting Document Line Item
--    Multiple rows per document — the actual debit/credit lines
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE BSEG (
    MANDT       VARCHAR(3)      COMMENT 'Client',
    BUKRS       VARCHAR(4)      COMMENT 'Company Code',
    BELNR       VARCHAR(10)     COMMENT 'Accounting Document Number',
    GJAHR       VARCHAR(4)      COMMENT 'Fiscal Year',
    BUZEI       VARCHAR(3)      COMMENT 'Line Item Number',
    BUZID       VARCHAR(1)      COMMENT 'Line Item ID (debit/credit indicator)',
    KOART       VARCHAR(1)      COMMENT 'Account Type (S=GL, D=Customer, K=Vendor)',
    SHKZG       VARCHAR(1)      COMMENT 'Debit/Credit Indicator (S=Debit, H=Credit)',
    HKONT       VARCHAR(10)     COMMENT 'GL Account Number',
    DMBTR       NUMBER(15,2)    COMMENT 'Amount in Local Currency',
    WRBTR       NUMBER(15,2)    COMMENT 'Amount in Document Currency',
    PSWSL       VARCHAR(5)      COMMENT 'Currency of GL Update',
    MWSKZ       VARCHAR(2)      COMMENT 'Tax Code',
    KOSTL       VARCHAR(10)     COMMENT 'Cost Center',
    AUFNR       VARCHAR(12)     COMMENT 'Internal Order Number',
    ZUONR       VARCHAR(18)     COMMENT 'Assignment Number',
    SGTXT       VARCHAR(50)     COMMENT 'Line Item Text',
    LIFNR       VARCHAR(10)     COMMENT 'Vendor Number',
    KUNNR       VARCHAR(10)     COMMENT 'Customer Number',
    PRCTR       VARCHAR(10)     COMMENT 'Profit Center',
    _LOADED_AT  TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP() COMMENT 'ETL load timestamp'
);

-- ────────────────────────────────────────────────────────────
-- 3. SKA1 — GL Account Master Data
--    One row per GL account in the chart of accounts
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE SKA1 (
    MANDT       VARCHAR(3)      COMMENT 'Client',
    KTOPL       VARCHAR(4)      COMMENT 'Chart of Accounts',
    SAKNR       VARCHAR(10)     COMMENT 'GL Account Number',
    BILKT       VARCHAR(10)     COMMENT 'Group Account Number',
    GVTYP       VARCHAR(1)      COMMENT 'PL Statement Account Type',
    KTOKS       VARCHAR(4)      COMMENT 'GL Account Group',
    XBILK       VARCHAR(1)      COMMENT 'Balance Sheet Account Indicator',
    TXT20       VARCHAR(20)     COMMENT 'Short Text',
    TXT50       VARCHAR(50)     COMMENT 'Long Text',
    XLOEV       VARCHAR(1)      COMMENT 'Deletion Flag',
    XSPEB       VARCHAR(1)      COMMENT 'Blocked for Posting',
    _LOADED_AT  TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP() COMMENT 'ETL load timestamp'
);

-- ────────────────────────────────────────────────────────────
-- 4. CSKS — Cost Center Master Data
--    One row per cost center per controlling area
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE CSKS (
    MANDT       VARCHAR(3)      COMMENT 'Client',
    KOKRS       VARCHAR(4)      COMMENT 'Controlling Area',
    KOSTL       VARCHAR(10)     COMMENT 'Cost Center',
    DATBI       DATE            COMMENT 'Valid To Date',
    DATAB       DATE            COMMENT 'Valid From Date',
    BUKRS       VARCHAR(4)      COMMENT 'Company Code',
    KOSAR       VARCHAR(1)      COMMENT 'Cost Center Category',
    VERAK       VARCHAR(20)     COMMENT 'Person Responsible',
    KTEXT       VARCHAR(40)     COMMENT 'Cost Center Description',
    LTEXT       VARCHAR(40)     COMMENT 'Long Description',
    APTS_GROUP  VARCHAR(10)     COMMENT 'Cost Center Group/Hierarchy',
    PRCTR       VARCHAR(10)     COMMENT 'Profit Center',
    _LOADED_AT  TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP() COMMENT 'ETL load timestamp'
);

-- ────────────────────────────────────────────────────────────
-- 5. LFA1 — Vendor Master Data (General Section)
--    One row per vendor
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE LFA1 (
    MANDT       VARCHAR(3)      COMMENT 'Client',
    LIFNR       VARCHAR(10)     COMMENT 'Vendor Account Number',
    LAND1       VARCHAR(3)      COMMENT 'Country Key',
    NAME1       VARCHAR(35)     COMMENT 'Vendor Name 1',
    NAME2       VARCHAR(35)     COMMENT 'Vendor Name 2',
    ORT01       VARCHAR(35)     COMMENT 'City',
    PSTLZ       VARCHAR(10)     COMMENT 'Postal Code',
    REGIO       VARCHAR(3)      COMMENT 'Region/State',
    STRAS       VARCHAR(35)     COMMENT 'Street Address',
    TELF1       VARCHAR(16)     COMMENT 'Telephone Number',
    STCD1       VARCHAR(16)     COMMENT 'Tax Number 1',
    STCD2       VARCHAR(11)     COMMENT 'Tax Number 2',
    SPERR       VARCHAR(1)      COMMENT 'Central Posting Block',
    LOEVM       VARCHAR(1)      COMMENT 'Central Deletion Flag',
    KTOKK       VARCHAR(4)      COMMENT 'Vendor Account Group',
    ERDAT       DATE            COMMENT 'Creation Date',
    ERNAM       VARCHAR(12)     COMMENT 'Created By',
    _LOADED_AT  TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP() COMMENT 'ETL load timestamp'
);

SELECT 'Bronze tables created: BKPF, BSEG, SKA1, CSKS, LFA1' AS status;
