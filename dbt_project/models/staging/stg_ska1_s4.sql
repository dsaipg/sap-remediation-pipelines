-- Silver Layer: GL Account Master Data (S/4HANA Extended)
-- Source: NEW_MODEL.SKA1_S4
-- Extends: stg_ska1 (same core fields + new S/4HANA attributes)
--
-- New S/4HANA fields added to SKA1_S4:
--   - FUNC_AREA: Functional Area for P&L reporting
--   - GLACCOUNT_TYPE: Detailed GL account type classification
--   - IS_RELEVANT_CFLOW: Cash flow statement relevance indicator

WITH source AS (
    SELECT * FROM {{ source('new_model', 'SKA1_S4') }}
    WHERE MANDT = '100'
),

cleaned AS (
    SELECT
        KTOPL                                       AS chart_of_accounts,
        SAKNR                                       AS gl_account_number,
        BILKT                                       AS group_account_number,
        KTOKS                                       AS account_group,

        -- Classification (same logic as ECC stg_ska1)
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

        -- New S/4HANA fields
        NULLIF(FUNC_AREA, '')                       AS functional_area,
        NULLIF(GLACCOUNT_TYPE, '')                  AS gl_account_type,
        CASE WHEN IS_RELEVANT_CFLOW = 'X' THEN TRUE ELSE FALSE END AS is_cash_flow_relevant,

        -- ETL metadata
        _LOADED_AT                                  AS bronze_loaded_at,
        CURRENT_TIMESTAMP()                         AS silver_loaded_at

    FROM source
)

SELECT * FROM cleaned
