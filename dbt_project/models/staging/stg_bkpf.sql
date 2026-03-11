-- Silver Layer: Cleaned Accounting Document Headers
-- Source: BRONZE.BKPF (SAP ECC)
-- Transformations:
--   1. Cast types and standardize date formats
--   2. Filter out test/training client data (keep MANDT='100')
--   3. Add derived fields: is_reversal, fiscal_quarter
--   4. Exclude reversed documents (optional flag)

WITH source AS (
    SELECT * FROM {{ source('bronze', 'BKPF') }}
    WHERE MANDT = '100'
),

cleaned AS (
    SELECT
        -- Primary Key
        BUKRS                                       AS company_code,
        BELNR                                       AS document_number,
        GJAHR                                       AS fiscal_year,

        -- Document attributes
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
        WAERS                                       AS currency_code,
        KURSF                                       AS exchange_rate,

        -- Reference
        XBLNR                                       AS reference_document,
        BKTXT                                       AS header_text,
        USNAM                                       AS created_by_user,
        TCODE                                       AS transaction_code,

        -- Reversal tracking
        STBLG                                       AS reversal_document_number,
        STJAH                                       AS reversal_fiscal_year,
        CASE
            WHEN STBLG IS NOT NULL AND STBLG != '' THEN TRUE
            ELSE FALSE
        END                                         AS is_reversed,

        -- ETL metadata
        _LOADED_AT                                  AS bronze_loaded_at,
        CURRENT_TIMESTAMP()                         AS silver_loaded_at

    FROM source
)

SELECT * FROM cleaned
