-- Silver Layer: Cleaned GL Account Master Data
-- Source: BRONZE.SKA1 (SAP ECC)
-- Transformations:
--   1. Decode balance sheet vs P&L classification
--   2. Flag inactive/blocked accounts
--   3. Standardize column names

WITH source AS (
    SELECT * FROM {{ source('bronze', 'SKA1') }}
    WHERE MANDT = '100'
),

cleaned AS (
    SELECT
        KTOPL                                       AS chart_of_accounts,
        SAKNR                                       AS gl_account_number,
        BILKT                                       AS group_account_number,
        KTOKS                                       AS account_group,

        -- Classification
        CASE
            WHEN XBILK = 'X' THEN 'Balance Sheet'
            ELSE 'Profit & Loss'
        END                                         AS account_class,

        CASE GVTYP
            WHEN 'X' THEN 'Revenue'
            WHEN ' ' THEN CASE WHEN XBILK = 'X' THEN 'N/A - Balance Sheet' ELSE 'Expense' END
            ELSE 'Other'
        END                                         AS pl_statement_type,

        -- Descriptions
        TXT20                                       AS short_description,
        TXT50                                       AS long_description,

        -- Status flags
        CASE WHEN XLOEV = 'X' THEN TRUE ELSE FALSE END AS is_deleted,
        CASE WHEN XSPEB = 'X' THEN TRUE ELSE FALSE END AS is_blocked,
        CASE
            WHEN XLOEV = 'X' OR XSPEB = 'X' THEN FALSE
            ELSE TRUE
        END                                         AS is_active,

        -- ETL metadata
        _LOADED_AT                                  AS bronze_loaded_at,
        CURRENT_TIMESTAMP()                         AS silver_loaded_at

    FROM source
)

SELECT * FROM cleaned
