-- Silver Layer: Cleaned Accounting Document Line Items
-- Source: BRONZE.BSEG (SAP ECC)
-- Transformations:
--   1. Standardize column names to business-friendly terms
--   2. Compute signed_amount (positive for debit, negative for credit)
--   3. Decode account types and debit/credit indicators
--   4. Clean up null/empty vendor and customer references

WITH source AS (
    SELECT * FROM {{ source('bronze', 'BSEG') }}
    WHERE MANDT = '100'
),

cleaned AS (
    SELECT
        -- Primary Key
        BUKRS                                       AS company_code,
        BELNR                                       AS document_number,
        GJAHR                                       AS fiscal_year,
        BUZEI                                       AS line_item_number,

        -- Account classification
        KOART                                       AS account_type_code,
        CASE KOART
            WHEN 'S' THEN 'GL Account'
            WHEN 'D' THEN 'Customer'
            WHEN 'K' THEN 'Vendor'
            WHEN 'M' THEN 'Material'
            WHEN 'A' THEN 'Asset'
            ELSE 'Other'
        END                                         AS account_type_desc,

        HKONT                                       AS gl_account_number,

        -- Debit/Credit
        SHKZG                                       AS debit_credit_indicator,
        CASE SHKZG
            WHEN 'S' THEN 'Debit'
            WHEN 'H' THEN 'Credit'
        END                                         AS debit_credit_desc,

        -- Amounts (signed: debit = positive, credit = negative)
        DMBTR                                       AS amount_local_currency,
        WRBTR                                       AS amount_doc_currency,
        CASE SHKZG
            WHEN 'S' THEN DMBTR
            WHEN 'H' THEN -1 * DMBTR
            ELSE DMBTR
        END                                         AS signed_amount_local,
        CASE SHKZG
            WHEN 'S' THEN WRBTR
            WHEN 'H' THEN -1 * WRBTR
            ELSE WRBTR
        END                                         AS signed_amount_doc,

        PSWSL                                       AS currency_code,
        MWSKZ                                       AS tax_code,

        -- Cost allocation
        NULLIF(KOSTL, '')                           AS cost_center,
        NULLIF(AUFNR, '')                           AS internal_order,
        NULLIF(PRCTR, '')                           AS profit_center,

        -- Assignment and text
        ZUONR                                       AS assignment_number,
        SGTXT                                       AS line_item_text,

        -- Partner references (cleaned)
        NULLIF(LIFNR, '')                           AS vendor_number,
        NULLIF(KUNNR, '')                           AS customer_number,

        -- ETL metadata
        _LOADED_AT                                  AS bronze_loaded_at,
        CURRENT_TIMESTAMP()                         AS silver_loaded_at

    FROM source
)

SELECT * FROM cleaned
