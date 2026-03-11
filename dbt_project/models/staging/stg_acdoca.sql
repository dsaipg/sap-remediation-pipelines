-- Silver Layer: Universal Journal Entry (S/4HANA)
-- Source: NEW_MODEL.ACDOCA
-- Replaces: stg_bkpf + stg_bseg (BKPF + BSEG were merged into ACDOCA in S/4HANA)
--
-- Key S/4HANA changes:
--   1. Header and line items are now a SINGLE flat table (no more BKPF/BSEG join)
--   2. Field renames: BELNR→DOCNR, BUKRS→RBUKRS, BUZEI→DOCLN (6 chars),
--                     HKONT→RACCT, DMBTR→HSL, WRBTR→WSL, KOSTL→RCNTR
--   3. New fields: RLDNR (ledger), OSL (global currency), RFAREA, SEGMENT, BPNR
--   4. Quantity/material ledger now embedded directly in the journal

WITH source AS (
    SELECT * FROM {{ source('new_model', 'ACDOCA') }}
    WHERE RCLNT = '100'
      AND RLDNR = '0L'  -- Leading ledger only (equivalent to ECC behavior)
),

cleaned AS (
    SELECT
        -- Primary Key (replaces BUKRS+BELNR+GJAHR+BUZEI)
        RBUKRS                                      AS company_code,
        DOCNR                                       AS document_number,
        GJAHR                                       AS fiscal_year,
        DOCLN                                       AS line_item_number,

        -- Ledger (new in S/4HANA; 0L=Leading, 2L=IFRS, etc.)
        RLDNR                                       AS ledger_id,

        -- Document attributes (previously in BKPF only)
        BLART                                       AS document_type,
        CASE BLART
            WHEN 'SA' THEN 'GL Posting'
            WHEN 'KR' THEN 'Vendor Invoice'
            WHEN 'DR' THEN 'Customer Invoice'
            WHEN 'KZ' THEN 'Vendor Payment'
            WHEN 'DZ' THEN 'Customer Payment'
            WHEN 'AB' THEN 'Clearing'
            ELSE 'Other (' || BLART || ')'
        END                                         AS document_type_desc,

        -- Dates
        BLDAT                                       AS document_date,
        BUDAT                                       AS posting_date,
        CPUDT                                       AS entry_date,
        CAST(MONAT AS INTEGER)                      AS fiscal_period,
        CASE
            WHEN CAST(MONAT AS INTEGER) BETWEEN 1 AND 3 THEN 1
            WHEN CAST(MONAT AS INTEGER) BETWEEN 4 AND 6 THEN 2
            WHEN CAST(MONAT AS INTEGER) BETWEEN 7 AND 9 THEN 3
            ELSE 4
        END                                         AS fiscal_quarter,

        -- Currency
        RWCUR                                       AS currency_code,
        RHCUR                                       AS local_currency_code,

        -- Reference
        XBLNR                                       AS reference_document,
        BKTXT                                       AS header_text,
        USNAM                                       AS created_by_user,

        -- Reversal tracking
        STBLG                                       AS reversal_document_number,
        CASE
            WHEN STBLG IS NOT NULL AND STBLG != '' THEN TRUE
            ELSE FALSE
        END                                         AS is_reversed,

        -- Reference transaction (new in S/4HANA)
        AWTYP                                       AS reference_transaction_type,
        AWKEY                                       AS reference_key,

        -- Account classification (previously in BSEG)
        KOART                                       AS account_type_code,
        CASE KOART
            WHEN 'S' THEN 'GL Account'
            WHEN 'D' THEN 'Customer'
            WHEN 'K' THEN 'Vendor'
            WHEN 'M' THEN 'Material'
            WHEN 'A' THEN 'Asset'
            ELSE 'Other'
        END                                         AS account_type_desc,

        RACCT                                       AS gl_account_number,  -- was HKONT in BSEG

        -- Debit/Credit
        SHKZG                                       AS debit_credit_indicator,
        CASE SHKZG
            WHEN 'S' THEN 'Debit'
            WHEN 'H' THEN 'Credit'
        END                                         AS debit_credit_desc,

        -- Amounts: HSL=local currency (was DMBTR), WSL=doc currency (was WRBTR)
        HSL                                         AS amount_local_currency,
        WSL                                         AS amount_doc_currency,
        OSL                                         AS amount_global_currency,  -- new in S/4HANA
        CASE SHKZG
            WHEN 'S' THEN HSL
            WHEN 'H' THEN -1 * HSL
            ELSE HSL
        END                                         AS signed_amount_local,
        CASE SHKZG
            WHEN 'S' THEN WSL
            WHEN 'H' THEN -1 * WSL
            ELSE WSL
        END                                         AS signed_amount_doc,

        MWSKZ                                       AS tax_code,
        SGTXT                                       AS line_item_text,

        -- Cost allocation (RCNTR replaces KOSTL)
        NULLIF(RCNTR, '')                           AS cost_center,
        NULLIF(PRCTR, '')                           AS profit_center,
        NULLIF(AUFNR, '')                           AS internal_order,

        -- New S/4HANA controlling fields
        NULLIF(RFAREA, '')                          AS functional_area,
        NULLIF(SEGMENT, '')                         AS segment,

        -- Partner references
        NULLIF(LIFNR, '')                           AS vendor_number,           -- legacy; superseded by BPNR
        NULLIF(KUNNR, '')                           AS customer_number,         -- legacy; superseded by BPNR
        NULLIF(BPNR, '')                            AS business_partner_number, -- new in S/4HANA

        -- Material Ledger fields (new: quantity embedded directly in journal)
        NULLIF(MATNR, '')                           AS material_number,
        NULLIF(WERKS, '')                           AS plant,
        QUANTITY                                    AS quantity,
        NULLIF(MEINS, '')                           AS unit_of_measure,

        -- ETL metadata
        _LOADED_AT                                  AS bronze_loaded_at,
        CURRENT_TIMESTAMP()                         AS silver_loaded_at

    FROM source
)

SELECT * FROM cleaned
