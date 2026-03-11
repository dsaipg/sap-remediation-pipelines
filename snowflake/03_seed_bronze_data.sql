-- ============================================================
-- SAP REMEDIATION POC — Seed Data for Bronze Tables
-- Realistic SAP ECC finance data for a fictional company
-- ============================================================

USE DATABASE SAP_REMEDIATION;
USE SCHEMA BRONZE;
USE WAREHOUSE SAP_REMEDIATION_WH;

-- ────────────────────────────────────────────────────────────
-- SKA1 — GL Account Master (seed first, referenced by others)
-- ────────────────────────────────────────────────────────────
INSERT INTO SKA1 (MANDT, KTOPL, SAKNR, BILKT, GVTYP, KTOKS, XBILK, TXT20, TXT50, XLOEV, XSPEB) VALUES
('100', 'CAUS', '0000100000', '0000100000', ' ', 'BS01', 'X', 'Cash - Main Bank',      'Cash and Cash Equivalents - Primary Bank Account',  '', ''),
('100', 'CAUS', '0000110000', '0000110000', ' ', 'BS01', 'X', 'Petty Cash',            'Petty Cash - Office',                                '', ''),
('100', 'CAUS', '0000120000', '0000120000', ' ', 'BS01', 'X', 'Accounts Receivable',   'Trade Accounts Receivable - Domestic',               '', ''),
('100', 'CAUS', '0000200000', '0000200000', ' ', 'BS02', 'X', 'Accounts Payable',      'Trade Accounts Payable - Domestic',                  '', ''),
('100', 'CAUS', '0000210000', '0000210000', ' ', 'BS02', 'X', 'Accrued Liabilities',   'Accrued Expenses and Other Liabilities',             '', ''),
('100', 'CAUS', '0000300000', '0000300000', ' ', 'BS03', 'X', 'Fixed Assets',          'Property Plant and Equipment - Gross',               '', ''),
('100', 'CAUS', '0000400000', '0000400000', 'X', 'PL01', ' ', 'Revenue - Products',    'Revenue from Product Sales',                         '', ''),
('100', 'CAUS', '0000410000', '0000410000', 'X', 'PL01', ' ', 'Revenue - Services',    'Revenue from Professional Services',                 '', ''),
('100', 'CAUS', '0000500000', '0000500000', 'X', 'PL02', ' ', 'COGS - Materials',      'Cost of Goods Sold - Raw Materials',                 '', ''),
('100', 'CAUS', '0000510000', '0000510000', 'X', 'PL02', ' ', 'COGS - Labor',          'Cost of Goods Sold - Direct Labor',                  '', ''),
('100', 'CAUS', '0000600000', '0000600000', 'X', 'PL03', ' ', 'SGA - Salaries',        'Selling General Admin - Salaries',                   '', ''),
('100', 'CAUS', '0000610000', '0000610000', 'X', 'PL03', ' ', 'SGA - Rent',            'Selling General Admin - Rent Expense',               '', ''),
('100', 'CAUS', '0000620000', '0000620000', 'X', 'PL03', ' ', 'SGA - Utilities',       'Selling General Admin - Utilities',                  '', ''),
('100', 'CAUS', '0000700000', '0000700000', 'X', 'PL04', ' ', 'Depreciation Exp',      'Depreciation and Amortization Expense',              '', ''),
('100', 'CAUS', '0000900000', '0000900000', 'X', 'PL05', ' ', 'Interest Expense',      'Interest Expense on Borrowings',                     '', 'X');

-- ────────────────────────────────────────────────────────────
-- CSKS — Cost Center Master Data
-- ────────────────────────────────────────────────────────────
INSERT INTO CSKS (MANDT, KOKRS, KOSTL, DATBI, DATAB, BUKRS, KOSAR, VERAK, KTEXT, LTEXT, APTS_GROUP, PRCTR) VALUES
('100', '1000', 'CC1000',  '9999-12-31', '2020-01-01', '1000', 'E', 'J.Smith',    'Executive Office',     'Executive Office - Corporate HQ',  'CORP',  'PC1000'),
('100', '1000', 'CC2000',  '9999-12-31', '2020-01-01', '1000', 'F', 'M.Johnson',  'Finance Department',   'Finance and Accounting',           'FIN',   'PC2000'),
('100', '1000', 'CC3000',  '9999-12-31', '2020-01-01', '1000', 'P', 'R.Williams', 'Production Line 1',    'Manufacturing - Production Line 1','MFG',   'PC3000'),
('100', '1000', 'CC3100',  '9999-12-31', '2020-01-01', '1000', 'P', 'R.Williams', 'Production Line 2',    'Manufacturing - Production Line 2','MFG',   'PC3000'),
('100', '1000', 'CC4000',  '9999-12-31', '2020-01-01', '1000', 'V', 'S.Brown',    'Sales - North',        'Sales Team - North Region',        'SALES', 'PC4000'),
('100', '1000', 'CC4100',  '9999-12-31', '2020-01-01', '1000', 'V', 'T.Davis',    'Sales - South',        'Sales Team - South Region',        'SALES', 'PC4000'),
('100', '1000', 'CC5000',  '9999-12-31', '2020-01-01', '1000', 'H', 'K.Miller',   'IT Department',        'Information Technology Services',  'IT',    'PC5000'),
('100', '1000', 'CC6000',  '9999-12-31', '2020-01-01', '1000', 'H', 'L.Wilson',   'Human Resources',      'Human Resources Department',       'HR',    'PC6000'),
('100', '1000', 'CC7000',  '9999-12-31', '2021-06-01', '1000', 'L', 'A.Garcia',   'Logistics',            'Warehouse and Logistics',          'LOG',   'PC7000'),
('100', '1000', 'CC9000',  '2023-12-31', '2020-01-01', '1000', 'F', 'SYSTEM',     'Legacy - Closed',      'Legacy Cost Center - Do Not Use',  'LEGACY','PC9000');

-- ────────────────────────────────────────────────────────────
-- LFA1 — Vendor Master Data
-- ────────────────────────────────────────────────────────────
INSERT INTO LFA1 (MANDT, LIFNR, LAND1, NAME1, NAME2, ORT01, PSTLZ, REGIO, STRAS, TELF1, STCD1, STCD2, SPERR, LOEVM, KTOKK, ERDAT, ERNAM) VALUES
('100', 'V000001000', 'US', 'Acme Industrial Supply',     'AIS Inc.',           'Chicago',      '60601', 'IL', '100 Michigan Ave',    '312-555-0100', '36-1234567',  '', '', '', 'KRED', '2020-03-15', 'ADMIN'),
('100', 'V000002000', 'US', 'TechParts International',    'TPI Corp',           'San Jose',     '95112', 'CA', '500 Innovation Dr',   '408-555-0200', '77-2345678',  '', '', '', 'KRED', '2020-05-20', 'ADMIN'),
('100', 'V000003000', 'US', 'Global Logistics Partners',  'GLP LLC',            'Memphis',      '38118', 'TN', '2200 Cargo Way',      '901-555-0300', '62-3456789',  '', '', '', 'KRED', '2020-07-01', 'JSMITH'),
('100', 'V000004000', 'DE', 'Müller Maschinenbau GmbH',  'Müller Group',       'Stuttgart',    '70173', 'BW', 'Industriestr. 45',    '+49-711-55500', 'DE123456789','', '', '', 'KRED', '2021-01-10', 'MJOHNSON'),
('100', 'V000005000', 'US', 'Office Solutions Inc',       '',                    'New York',     '10001', 'NY', '350 5th Avenue',      '212-555-0500', '13-5678901',  '', '', '', 'KRED', '2021-03-22', 'ADMIN'),
('100', 'V000006000', 'JP', 'Yamamoto Electronics',       'YE Japan KK',        'Osaka',        '530-01','27', '1-1 Umeda',           '+81-6-55506',  'JP6789012',   '', '', '', 'KRED', '2021-06-15', 'ADMIN'),
('100', 'V000007000', 'US', 'CleanEnergy Utilities',      'CEU',                'Austin',       '73301', 'TX', '800 Energy Blvd',     '512-555-0700', '74-7890123',  '', '', '', 'KRED', '2022-01-05', 'TBROWN'),
('100', 'V000008000', 'US', 'Pinnacle Consulting Group',  'PCG',                'Boston',       '02101', 'MA', '1 Financial Center',  '617-555-0800', '04-8901234',  '', 'X','', 'KRED', '2022-04-18', 'ADMIN'),
('100', 'V000009000', 'US', 'INACTIVE VENDOR DO NOT USE', '',                    'N/A',          '00000', '',   '',                     '',              '',            '', '', 'X','KRED', '2019-01-01', 'SYSTEM'),
('100', 'V000010000', 'IN', 'Tata Consulting Services',   'TCS',                'Mumbai',       '400001','MH', 'TCS House, Ravindra', '+91-22-67789', 'AAACT1234A',  '', '', '', 'KRED', '2022-09-01', 'ADMIN');

-- ────────────────────────────────────────────────────────────
-- BKPF — Accounting Document Headers (30 documents)
-- ────────────────────────────────────────────────────────────
INSERT INTO BKPF (MANDT, BUKRS, BELNR, GJAHR, BLART, BLDAT, BUDAT, MONAT, CPUDT, USNAM, TCODE, BKTXT, WAERS, KURSF, XBLNR, STBLG, STJAH) VALUES
-- Jan 2024 - Vendor invoices
('100','1000','0100000001','2024','KR','2024-01-05','2024-01-05','01','2024-01-05','MJOHNSON','FB60','Acme supply invoice Jan','USD',1.00000,'INV-2024-001','',''),
('100','1000','0100000002','2024','KR','2024-01-12','2024-01-12','01','2024-01-12','MJOHNSON','FB60','TechParts Q1 order','USD',1.00000,'INV-2024-002','',''),
('100','1000','0100000003','2024','KR','2024-01-20','2024-01-20','01','2024-01-20','ADMIN','FB60','Office supplies Jan','USD',1.00000,'INV-2024-003','',''),
-- Jan 2024 - Revenue postings
('100','1000','0100000004','2024','DR','2024-01-15','2024-01-15','01','2024-01-15','SBROWN','FB70','Customer invoice North','USD',1.00000,'SI-2024-001','',''),
('100','1000','0100000005','2024','DR','2024-01-28','2024-01-28','01','2024-01-28','TDAVIS','FB70','Customer invoice South','USD',1.00000,'SI-2024-002','',''),
-- Jan 2024 - GL postings
('100','1000','0100000006','2024','SA','2024-01-31','2024-01-31','01','2024-01-31','MJOHNSON','FB50','Depreciation Jan 2024','USD',1.00000,'','',''),
('100','1000','0100000007','2024','SA','2024-01-31','2024-01-31','01','2024-01-31','MJOHNSON','FB50','Salary accrual Jan 2024','USD',1.00000,'','',''),
-- Feb 2024
('100','1000','0100000008','2024','KR','2024-02-03','2024-02-03','02','2024-02-03','MJOHNSON','FB60','Müller parts import Feb','EUR',0.92150,'INV-DE-0045','',''),
('100','1000','0100000009','2024','KR','2024-02-10','2024-02-10','02','2024-02-10','ADMIN','FB60','GLP shipping Feb','USD',1.00000,'INV-2024-010','',''),
('100','1000','0100000010','2024','DR','2024-02-15','2024-02-15','02','2024-02-15','SBROWN','FB70','Product sale Feb North','USD',1.00000,'SI-2024-005','',''),
('100','1000','0100000011','2024','DR','2024-02-22','2024-02-22','02','2024-02-22','TDAVIS','FB70','Service revenue Feb South','USD',1.00000,'SI-2024-006','',''),
('100','1000','0100000012','2024','SA','2024-02-29','2024-02-29','02','2024-02-29','MJOHNSON','FB50','Depreciation Feb 2024','USD',1.00000,'','',''),
-- Mar 2024
('100','1000','0100000013','2024','KR','2024-03-05','2024-03-05','03','2024-03-05','MJOHNSON','FB60','Acme supply invoice Mar','USD',1.00000,'INV-2024-015','',''),
('100','1000','0100000014','2024','KR','2024-03-08','2024-03-08','03','2024-03-08','ADMIN','FB60','Yamamoto electronics order','JPY',0.00667,'INV-JP-0099','',''),
('100','1000','0100000015','2024','DR','2024-03-12','2024-03-12','03','2024-03-12','SBROWN','FB70','Large product sale Mar','USD',1.00000,'SI-2024-010','',''),
('100','1000','0100000016','2024','SA','2024-03-31','2024-03-31','03','2024-03-31','MJOHNSON','FB50','Q1 closing adjustments','USD',1.00000,'','',''),
('100','1000','0100000017','2024','SA','2024-03-31','2024-03-31','03','2024-03-31','SYSTEM','FB50','Q1 FX revaluation','USD',1.00000,'','',''),
-- Reversal example
('100','1000','0100000018','2024','KR','2024-03-15','2024-03-15','03','2024-03-15','MJOHNSON','FB60','Wrong vendor - to reverse','USD',1.00000,'INV-ERR-001','0100000019','2024'),
('100','1000','0100000019','2024','KR','2024-03-16','2024-03-16','03','2024-03-16','MJOHNSON','FB08','Reversal of 0100000018','USD',1.00000,'','',''),
-- Apr 2024
('100','1000','0100000020','2024','KR','2024-04-02','2024-04-02','04','2024-04-02','MJOHNSON','FB60','TechParts Q2 order','USD',1.00000,'INV-2024-020','',''),
('100','1000','0100000021','2024','DR','2024-04-10','2024-04-10','04','2024-04-10','SBROWN','FB70','Product sale Apr North','USD',1.00000,'SI-2024-015','',''),
('100','1000','0100000022','2024','KR','2024-04-15','2024-04-15','04','2024-04-15','ADMIN','FB60','CleanEnergy Q2 bill','USD',1.00000,'UTIL-2024-Q2','',''),
('100','1000','0100000023','2024','SA','2024-04-30','2024-04-30','04','2024-04-30','MJOHNSON','FB50','Depreciation Apr 2024','USD',1.00000,'','',''),
-- May-Jun 2024
('100','1000','0100000024','2024','DR','2024-05-08','2024-05-08','05','2024-05-08','TDAVIS','FB70','Service contract May','USD',1.00000,'SI-2024-020','',''),
('100','1000','0100000025','2024','KR','2024-05-15','2024-05-15','05','2024-05-15','MJOHNSON','FB60','Acme bulk order May','USD',1.00000,'INV-2024-025','',''),
('100','1000','0100000026','2024','DR','2024-06-01','2024-06-01','06','2024-06-01','SBROWN','FB70','Large enterprise deal Jun','USD',1.00000,'SI-2024-025','',''),
('100','1000','0100000027','2024','KR','2024-06-10','2024-06-10','06','2024-06-10','ADMIN','FB60','TCS consulting Jun','INR',0.01200,'INV-IN-5001','',''),
('100','1000','0100000028','2024','SA','2024-06-30','2024-06-30','06','2024-06-30','MJOHNSON','FB50','Q2 closing adjustments','USD',1.00000,'','',''),
('100','1000','0100000029','2024','SA','2024-06-30','2024-06-30','06','2024-06-30','SYSTEM','FB50','Q2 FX revaluation','USD',1.00000,'','',''),
('100','1000','0100000030','2024','SA','2024-06-30','2024-06-30','06','2024-06-30','MJOHNSON','FB50','H1 intercompany recon','USD',1.00000,'','','');

-- ────────────────────────────────────────────────────────────
-- BSEG — Accounting Document Line Items (2-3 lines per document)
-- ────────────────────────────────────────────────────────────
INSERT INTO BSEG (MANDT, BUKRS, BELNR, GJAHR, BUZEI, BUZID, KOART, SHKZG, HKONT, DMBTR, WRBTR, PSWSL, MWSKZ, KOSTL, AUFNR, ZUONR, SGTXT, LIFNR, KUNNR, PRCTR) VALUES
-- Doc 1: Acme vendor invoice $45,000 (materials)
('100','1000','0100000001','2024','001','','K','H','0000200000',45000.00,45000.00,'USD','V1','','','V000001000','Acme raw materials Jan','V000001000','','PC3000'),
('100','1000','0100000001','2024','002','','S','S','0000500000',45000.00,45000.00,'USD','V1','CC3000','','','Materials cost Jan','','','PC3000'),
-- Doc 2: TechParts invoice $28,500
('100','1000','0100000002','2024','001','','K','H','0000200000',28500.00,28500.00,'USD','V1','','','V000002000','TechParts components Q1','V000002000','','PC3000'),
('100','1000','0100000002','2024','002','','S','S','0000500000',28500.00,28500.00,'USD','V1','CC3100','','','Electronic parts Q1','','','PC3000'),
-- Doc 3: Office supplies $2,150
('100','1000','0100000003','2024','001','','K','H','0000200000',2150.00,2150.00,'USD','V1','','','V000005000','Office supplies Jan','V000005000','','PC2000'),
('100','1000','0100000003','2024','002','','S','S','0000620000',2150.00,2150.00,'USD','V1','CC1000','','','Office supplies expense','','','PC1000'),
-- Doc 4: Customer invoice North $125,000 (product sale)
('100','1000','0100000004','2024','001','','D','S','0000120000',125000.00,125000.00,'USD','A1','','','C000001','Product sale North Jan','','C000001','PC4000'),
('100','1000','0100000004','2024','002','','S','H','0000400000',125000.00,125000.00,'USD','A1','CC4000','','','Revenue products North','','','PC4000'),
-- Doc 5: Customer invoice South $87,000 (product + service)
('100','1000','0100000005','2024','001','','D','S','0000120000',87000.00,87000.00,'USD','A1','','','C000002','Sale South Jan','','C000002','PC4000'),
('100','1000','0100000005','2024','002','','S','H','0000400000',62000.00,62000.00,'USD','A1','CC4100','','','Revenue products South','','','PC4000'),
('100','1000','0100000005','2024','003','','S','H','0000410000',25000.00,25000.00,'USD','A1','CC4100','','','Revenue services South','','','PC4000'),
-- Doc 6: Depreciation Jan $8,500
('100','1000','0100000006','2024','001','','S','S','0000700000',8500.00,8500.00,'USD','','CC5000','','','Depreciation IT assets','','','PC5000'),
('100','1000','0100000006','2024','002','','S','H','0000300000',8500.00,8500.00,'USD','','','','','Accum depreciation','','','PC5000'),
-- Doc 7: Salary accrual Jan $185,000
('100','1000','0100000007','2024','001','','S','S','0000600000',95000.00,95000.00,'USD','','CC3000','','','Production salaries Jan','','','PC3000'),
('100','1000','0100000007','2024','002','','S','S','0000600000',55000.00,55000.00,'USD','','CC4000','','','Sales salaries Jan','','','PC4000'),
('100','1000','0100000007','2024','003','','S','S','0000600000',35000.00,35000.00,'USD','','CC2000','','','Finance salaries Jan','','','PC2000'),
('100','1000','0100000007','2024','004','','S','H','0000210000',185000.00,185000.00,'USD','','','','','Salary accrual Jan','','',''),
-- Doc 8: Müller import €32,000 ($34,720 at 0.9215)
('100','1000','0100000008','2024','001','','K','H','0000200000',34720.00,32000.00,'EUR','V1','','','V000004000','Müller parts import','V000004000','','PC3000'),
('100','1000','0100000008','2024','002','','S','S','0000500000',34720.00,32000.00,'EUR','V1','CC3000','','','Imported parts Feb','','','PC3000'),
-- Doc 10: Product sale Feb North $142,000
('100','1000','0100000010','2024','001','','D','S','0000120000',142000.00,142000.00,'USD','A1','','','C000001','Product sale Feb North','','C000001','PC4000'),
('100','1000','0100000010','2024','002','','S','H','0000400000',142000.00,142000.00,'USD','A1','CC4000','','','Revenue products Feb','','','PC4000'),
-- Doc 11: Service revenue Feb South $38,000
('100','1000','0100000011','2024','001','','D','S','0000120000',38000.00,38000.00,'USD','A1','','','C000002','Service invoice Feb','','C000002','PC4000'),
('100','1000','0100000011','2024','002','','S','H','0000410000',38000.00,38000.00,'USD','A1','CC4100','','','Service revenue Feb','','','PC4000'),
-- Doc 15: Large product sale Mar $250,000
('100','1000','0100000015','2024','001','','D','S','0000120000',250000.00,250000.00,'USD','A1','','','C000003','Enterprise deal Mar','','C000003','PC4000'),
('100','1000','0100000015','2024','002','','S','H','0000400000',250000.00,250000.00,'USD','A1','CC4000','','','Revenue enterprise Mar','','','PC4000'),
-- Doc 22: Utility bill $4,800
('100','1000','0100000022','2024','001','','K','H','0000200000',4800.00,4800.00,'USD','V1','','','V000007000','CleanEnergy Q2','V000007000','','PC5000'),
('100','1000','0100000022','2024','002','','S','S','0000620000',4800.00,4800.00,'USD','V1','CC5000','','','Utilities Q2','','','PC5000'),
-- Doc 26: Large enterprise deal Jun $380,000
('100','1000','0100000026','2024','001','','D','S','0000120000',380000.00,380000.00,'USD','A1','','','C000004','Enterprise deal Jun','','C000004','PC4000'),
('100','1000','0100000026','2024','002','','S','H','0000400000',310000.00,310000.00,'USD','A1','CC4000','','','Revenue products Jun','','','PC4000'),
('100','1000','0100000026','2024','003','','S','H','0000410000',70000.00,70000.00,'USD','A1','CC4100','','','Revenue services Jun','','','PC4000');


SELECT 'Seed data loaded!' AS status;
SELECT 'BKPF: ' || COUNT(*) FROM BRONZE.BKPF;
SELECT 'BSEG: ' || COUNT(*) FROM BRONZE.BSEG;
SELECT 'SKA1: ' || COUNT(*) FROM BRONZE.SKA1;
SELECT 'CSKS: ' || COUNT(*) FROM BRONZE.CSKS;
SELECT 'LFA1: ' || COUNT(*) FROM BRONZE.LFA1;
