-- ============================================================
-- SAP REMEDIATION POC — NEW S/4HANA Data Model
-- This represents the CHANGED schema that triggers remediation
-- In Phase 3, this comes from Palantir Foundry.
-- For Phase 1, we create it directly in Snowflake.
-- ============================================================

USE DATABASE SAP_REMEDIATION;
USE SCHEMA NEW_MODEL;
USE WAREHOUSE SAP_REMEDIATION_WH;

-- ────────────────────────────────────────────────────────────
-- ACDOCA — Universal Journal Entry (THE big S/4HANA change)
--
-- This SINGLE table replaces:
--   BKPF (header) + BSEG (line items) + FAGLFLEXA + COEP + more
--
-- Key differences from ECC:
--   1. Header and line items are MERGED (no more join BKPF↔BSEG)
--   2. Includes CO (controlling) fields directly
--   3. Includes ML (material ledger) fields
--   4. Includes profit center, segment, functional area natively
--   5. New fields: RLDNR (ledger), RBUKRS (partner company code)
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE ACDOCA (
    -- Key fields
    RCLNT       VARCHAR(3)      COMMENT 'Client',
    RLDNR       VARCHAR(2)      COMMENT 'Ledger (0L=Leading, 2L=IFRS, etc.) ** NEW IN S4 **',
    RBUKRS      VARCHAR(4)      COMMENT 'Company Code',
    DOCNR       VARCHAR(10)     COMMENT 'Document Number (was BELNR)',
    GJAHR       VARCHAR(4)      COMMENT 'Fiscal Year',
    DOCLN       VARCHAR(6)      COMMENT 'Line Item (was BUZEI, now 6 chars)',

    -- Header fields (previously in BKPF only)
    BLART       VARCHAR(2)      COMMENT 'Document Type',
    BLDAT       DATE            COMMENT 'Document Date',
    BUDAT       DATE            COMMENT 'Posting Date',
    MONAT       VARCHAR(2)      COMMENT 'Fiscal Period',
    CPUDT       DATE            COMMENT 'Entry Date',
    USNAM       VARCHAR(12)     COMMENT 'User Name',
    BKTXT       VARCHAR(25)     COMMENT 'Document Header Text',
    XBLNR       VARCHAR(16)     COMMENT 'Reference Document Number',
    STBLG       VARCHAR(10)     COMMENT 'Reverse Document Number',
    AWTYP       VARCHAR(5)      COMMENT 'Reference Transaction Type ** NEW **',
    AWKEY       VARCHAR(20)     COMMENT 'Reference Key ** NEW **',

    -- Line item fields (previously in BSEG)
    KOART       VARCHAR(1)      COMMENT 'Account Type',
    SHKZG       VARCHAR(1)      COMMENT 'Debit/Credit Indicator',
    RACCT       VARCHAR(10)     COMMENT 'GL Account (was HKONT)',
    RHCUR       VARCHAR(5)      COMMENT 'Local Currency',
    RWCUR       VARCHAR(5)      COMMENT 'Document Currency',
    HSL         NUMBER(15,2)    COMMENT 'Amount in Local Currency (was DMBTR)',
    WSL         NUMBER(15,2)    COMMENT 'Amount in Doc Currency (was WRBTR)',
    OSL         NUMBER(15,2)    COMMENT 'Amount in Global Currency ** NEW **',
    MWSKZ       VARCHAR(2)      COMMENT 'Tax Code',
    SGTXT       VARCHAR(50)     COMMENT 'Line Item Text',

    -- Partner fields
    LIFNR       VARCHAR(10)     COMMENT 'Vendor Number (will migrate to BP)',
    KUNNR       VARCHAR(10)     COMMENT 'Customer Number (will migrate to BP)',
    BPNR        VARCHAR(10)     COMMENT 'Business Partner Number ** NEW IN S4 **',

    -- Controlling fields (previously separate tables COEP, COSS)
    RCNTR       VARCHAR(10)     COMMENT 'Cost Center (was KOSTL)',
    PRCTR       VARCHAR(10)     COMMENT 'Profit Center',
    RFAREA      VARCHAR(16)     COMMENT 'Functional Area ** NEW **',
    SEGMENT     VARCHAR(10)     COMMENT 'Segment ** NEW **',
    AUFNR       VARCHAR(12)     COMMENT 'Internal Order',
    PS_PSP_PNR  VARCHAR(24)     COMMENT 'WBS Element ** EXTENDED **',

    -- Material Ledger fields (previously CKMLHD, CKMLCR)
    MATNR       VARCHAR(40)     COMMENT 'Material Number ** EXTENDED to 40 chars **',
    WERKS       VARCHAR(4)      COMMENT 'Plant',
    QUANTITY    NUMBER(13,3)    COMMENT 'Quantity ** NEW: direct in journal **',
    MEINS       VARCHAR(3)      COMMENT 'Unit of Measure ** NEW **',

    -- Audit
    TIMESTAMP   TIMESTAMP_NTZ   COMMENT 'Change Timestamp ** NEW **',
    _LOADED_AT  TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP() COMMENT 'ETL load timestamp'
);

-- ────────────────────────────────────────────────────────────
-- BP — Business Partner (replaces LFA1 + KNA1)
--
-- Key differences:
--   1. SINGLE table for vendors AND customers (was separate LFA1/KNA1)
--   2. New partner number (PARTNER) replaces LIFNR and KUNNR
--   3. Role-based: same partner can be vendor AND customer
--   4. Includes additional classification fields
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE BP (
    MANDT       VARCHAR(3)      COMMENT 'Client',
    PARTNER     VARCHAR(10)     COMMENT 'Business Partner Number ** NEW: replaces LIFNR/KUNNR **',
    BP_ROLE     VARCHAR(6)      COMMENT 'BP Role (FLVN00=Vendor, FLCU00=Customer, FLCU01=Both) ** NEW **',
    BP_TYPE     VARCHAR(1)      COMMENT 'BP Type (1=Org, 2=Person) ** NEW **',
    BP_GROUP    VARCHAR(4)      COMMENT 'BP Grouping ** NEW **',

    -- Name (restructured from NAME1/NAME2)
    NAME_ORG1   VARCHAR(40)     COMMENT 'Organization Name 1 (was NAME1, extended)',
    NAME_ORG2   VARCHAR(40)     COMMENT 'Organization Name 2 (was NAME2, extended)',
    NAME_FIRST  VARCHAR(40)     COMMENT 'First Name (for person type) ** NEW **',
    NAME_LAST   VARCHAR(40)     COMMENT 'Last Name (for person type) ** NEW **',

    -- Address (extended)
    COUNTRY     VARCHAR(3)      COMMENT 'Country (was LAND1)',
    CITY        VARCHAR(40)     COMMENT 'City (was ORT01, extended)',
    POSTAL_CODE VARCHAR(10)     COMMENT 'Postal Code (was PSTLZ)',
    REGION      VARCHAR(3)      COMMENT 'Region (was REGIO)',
    STREET      VARCHAR(60)     COMMENT 'Street (was STRAS, extended to 60)',
    HOUSE_NUM   VARCHAR(10)     COMMENT 'House Number ** NEW: separated from street **',
    EMAIL       VARCHAR(241)    COMMENT 'Email Address ** NEW **',
    PHONE       VARCHAR(30)     COMMENT 'Telephone (was TELF1, extended)',
    URL         VARCHAR(132)    COMMENT 'Website ** NEW **',

    -- Tax and Legal
    TAX_NUM1    VARCHAR(20)     COMMENT 'Tax Number 1 (was STCD1, extended)',
    TAX_NUM2    VARCHAR(20)     COMMENT 'Tax Number 2 (was STCD2, extended)',
    TAX_TYPE    VARCHAR(2)      COMMENT 'Tax Number Type ** NEW **',
    INDUSTRY    VARCHAR(10)     COMMENT 'Industry Key ** NEW **',

    -- Status
    IS_BLOCKED  BOOLEAN         COMMENT 'Central Block (was SPERR, now boolean) ** CHANGED TYPE **',
    IS_DELETED  BOOLEAN         COMMENT 'Deletion Flag (was LOEVM, now boolean) ** CHANGED TYPE **',

    -- Cross-reference to legacy IDs
    LEGACY_LIFNR VARCHAR(10)    COMMENT 'Legacy Vendor Number (for migration mapping) ** NEW **',
    LEGACY_KUNNR VARCHAR(10)    COMMENT 'Legacy Customer Number (for migration mapping) ** NEW **',

    -- Audit
    CREATED_ON  DATE            COMMENT 'Creation Date (was ERDAT)',
    CREATED_BY  VARCHAR(12)     COMMENT 'Created By (was ERNAM)',
    CHANGED_ON  DATE            COMMENT 'Last Change Date ** NEW **',
    CHANGED_BY  VARCHAR(12)     COMMENT 'Last Changed By ** NEW **',
    _LOADED_AT  TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP() COMMENT 'ETL load timestamp'
);

-- ────────────────────────────────────────────────────────────
-- SKA1_S4 — GL Account Master (extended for S/4HANA)
--
-- Mostly same as SKA1 but with additional fields
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE SKA1_S4 (
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
    -- New S/4HANA fields
    FUNC_AREA   VARCHAR(16)     COMMENT 'Functional Area ** NEW **',
    GLACCOUNT_TYPE VARCHAR(2)   COMMENT 'GL Account Type (detailed) ** NEW **',
    IS_RELEVANT_CFLOW VARCHAR(1) COMMENT 'Cash Flow Relevance ** NEW **',
    _LOADED_AT  TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP() COMMENT 'ETL load timestamp'
);

-- ────────────────────────────────────────────────────────────
-- CSKS_S4 — Cost Center Master (extended for S/4HANA)
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE CSKS_S4 (
    MANDT       VARCHAR(3)      COMMENT 'Client',
    KOKRS       VARCHAR(4)      COMMENT 'Controlling Area',
    KOSTL       VARCHAR(10)     COMMENT 'Cost Center',
    DATBI       DATE            COMMENT 'Valid To Date',
    DATAB       DATE            COMMENT 'Valid From Date',
    BUKRS       VARCHAR(4)      COMMENT 'Company Code',
    KOSAR       VARCHAR(1)      COMMENT 'Cost Center Category',
    VERAK       VARCHAR(20)     COMMENT 'Person Responsible',
    KTEXT       VARCHAR(40)     COMMENT 'Description',
    LTEXT       VARCHAR(40)     COMMENT 'Long Description',
    APTS_GROUP  VARCHAR(10)     COMMENT 'Cost Center Group',
    PRCTR       VARCHAR(10)     COMMENT 'Profit Center',
    -- New S/4HANA fields
    FUNC_AREA   VARCHAR(16)     COMMENT 'Functional Area ** NEW **',
    SEGMENT     VARCHAR(10)     COMMENT 'Segment ** NEW **',
    _LOADED_AT  TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP() COMMENT 'ETL load timestamp'
);


-- ════════════════════════════════════════════════════════════
-- SCHEMA CHANGE MANIFEST (for the agent to reference)
-- Documents all changes between ECC and S/4HANA
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE TABLE SCHEMA_CHANGE_MANIFEST (
    CHANGE_ID       VARCHAR(20)     PRIMARY KEY,
    OLD_TABLE       VARCHAR(50)     COMMENT 'ECC table name',
    NEW_TABLE       VARCHAR(50)     COMMENT 'S/4HANA table name',
    CHANGE_TYPE     VARCHAR(20)     COMMENT 'MERGE|SPLIT|EXTEND|RENAME|NEW|REMOVED',
    OLD_COLUMN      VARCHAR(50)     COMMENT 'ECC column name (NULL if new)',
    NEW_COLUMN      VARCHAR(50)     COMMENT 'S/4HANA column name (NULL if removed)',
    DATA_TYPE_CHANGE VARCHAR(100)   COMMENT 'Description of data type change if any',
    MAPPING_NOTES   VARCHAR(500)    COMMENT 'Transformation logic notes',
    IMPACT_LEVEL    VARCHAR(10)     COMMENT 'HIGH|MEDIUM|LOW'
);

INSERT INTO SCHEMA_CHANGE_MANIFEST VALUES
-- BKPF + BSEG → ACDOCA (the big merge)
('CHG-001', 'BKPF',  'ACDOCA', 'MERGE',  'BELNR',   'DOCNR',   'Same type',                     'Direct rename: BELNR → DOCNR', 'HIGH'),
('CHG-002', 'BSEG',  'ACDOCA', 'MERGE',  'BUZEI',   'DOCLN',   'VARCHAR(3) → VARCHAR(6)',       'Extended line item number to 6 chars', 'HIGH'),
('CHG-003', 'BSEG',  'ACDOCA', 'MERGE',  'HKONT',   'RACCT',   'Same type',                     'Renamed: HKONT → RACCT (receiver account)', 'HIGH'),
('CHG-004', 'BSEG',  'ACDOCA', 'MERGE',  'DMBTR',   'HSL',     'Same numeric type',             'Renamed: DMBTR → HSL (house currency amount)', 'HIGH'),
('CHG-005', 'BSEG',  'ACDOCA', 'MERGE',  'WRBTR',   'WSL',     'Same numeric type',             'Renamed: WRBTR → WSL (document currency amount)', 'HIGH'),
('CHG-006', 'BSEG',  'ACDOCA', 'MERGE',  'KOSTL',   'RCNTR',   'Same type',                     'Renamed: KOSTL → RCNTR (receiver cost center)', 'MEDIUM'),
('CHG-007', 'BKPF',  'ACDOCA', 'MERGE',  'BUKRS',   'RBUKRS',  'Same type',                     'Renamed: BUKRS → RBUKRS (receiver company code)', 'MEDIUM'),
('CHG-008', NULL,     'ACDOCA', 'NEW',    NULL,       'RLDNR',   'NEW VARCHAR(2)',                'New: Ledger ID (0L=Leading). No ECC equivalent.', 'HIGH'),
('CHG-009', NULL,     'ACDOCA', 'NEW',    NULL,       'OSL',     'NEW NUMBER(15,2)',              'New: Amount in global/group currency', 'MEDIUM'),
('CHG-010', NULL,     'ACDOCA', 'NEW',    NULL,       'RFAREA',  'NEW VARCHAR(16)',               'New: Functional Area for reporting', 'MEDIUM'),
('CHG-011', NULL,     'ACDOCA', 'NEW',    NULL,       'SEGMENT', 'NEW VARCHAR(10)',               'New: Segment for segment reporting', 'MEDIUM'),
('CHG-012', NULL,     'ACDOCA', 'NEW',    NULL,       'BPNR',    'NEW VARCHAR(10)',               'New: Business Partner number (replaces LIFNR/KUNNR)', 'HIGH'),

-- LFA1 → BP
('CHG-020', 'LFA1',  'BP',     'MERGE',  'LIFNR',   'PARTNER', 'Same type',                      'Vendor number becomes unified Business Partner ID', 'HIGH'),
('CHG-021', 'LFA1',  'BP',     'MERGE',  'NAME1',   'NAME_ORG1','VARCHAR(35) → VARCHAR(40)',     'Extended and renamed', 'MEDIUM'),
('CHG-022', 'LFA1',  'BP',     'MERGE',  'SPERR',   'IS_BLOCKED','VARCHAR(1) → BOOLEAN',         'Changed from flag to boolean', 'MEDIUM'),
('CHG-023', 'LFA1',  'BP',     'MERGE',  'LOEVM',   'IS_DELETED','VARCHAR(1) → BOOLEAN',         'Changed from flag to boolean', 'MEDIUM'),
('CHG-024', NULL,     'BP',     'NEW',    NULL,       'BP_ROLE', 'NEW VARCHAR(6)',                 'New: Business Partner Role (vendor/customer/both)', 'HIGH'),
('CHG-025', NULL,     'BP',     'NEW',    NULL,       'BP_TYPE', 'NEW VARCHAR(1)',                 'New: BP Type (org vs person)', 'MEDIUM'),
('CHG-026', NULL,     'BP',     'NEW',    NULL,       'EMAIL',   'NEW VARCHAR(241)',               'New: Email address field', 'LOW'),
('CHG-027', NULL,     'BP',     'NEW',    NULL,       'LEGACY_LIFNR','NEW VARCHAR(10)',            'New: Cross-reference to old vendor number', 'HIGH'),

-- SKA1 → SKA1_S4 (extend)
('CHG-030', 'SKA1',  'SKA1_S4','EXTEND', NULL,       'FUNC_AREA','NEW VARCHAR(16)',               'New: Functional Area on GL master', 'MEDIUM'),
('CHG-031', 'SKA1',  'SKA1_S4','EXTEND', NULL,       'GLACCOUNT_TYPE','NEW VARCHAR(2)',            'New: Detailed GL Account Type', 'LOW'),

-- CSKS → CSKS_S4 (extend)
('CHG-040', 'CSKS',  'CSKS_S4','EXTEND', NULL,       'FUNC_AREA','NEW VARCHAR(16)',               'New: Functional Area on cost center', 'MEDIUM'),
('CHG-041', 'CSKS',  'CSKS_S4','EXTEND', NULL,       'SEGMENT', 'NEW VARCHAR(10)',                'New: Segment on cost center', 'LOW');

SELECT 'New S/4HANA model created with ' || COUNT(*) || ' documented schema changes' AS status
FROM SCHEMA_CHANGE_MANIFEST;
