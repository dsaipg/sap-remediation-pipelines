-- Silver Layer: Cleaned Vendor Master Data
-- Source: BRONZE.LFA1 (SAP ECC)
-- Transformations:
--   1. Determine active/blocked/deleted status
--   2. Standardize address fields
--   3. Clean up empty string fields to NULL

WITH source AS (
    SELECT * FROM {{ source('bronze', 'LFA1') }}
    WHERE MANDT = '100'
),

cleaned AS (
    SELECT
        LIFNR                                       AS vendor_number,
        KTOKK                                       AS vendor_account_group,

        -- Name
        NAME1                                       AS vendor_name,
        NULLIF(NAME2, '')                           AS vendor_name_2,

        -- Address
        LAND1                                       AS country_code,
        ORT01                                       AS city,
        PSTLZ                                       AS postal_code,
        NULLIF(REGIO, '')                           AS region,
        STRAS                                       AS street_address,
        NULLIF(TELF1, '')                           AS phone_number,

        -- Tax
        NULLIF(STCD1, '')                           AS tax_number_1,
        NULLIF(STCD2, '')                           AS tax_number_2,

        -- Status
        CASE WHEN SPERR = 'X' THEN TRUE ELSE FALSE END AS is_blocked,
        CASE WHEN LOEVM = 'X' THEN TRUE ELSE FALSE END AS is_deleted,
        CASE
            WHEN SPERR = 'X' OR LOEVM = 'X' THEN FALSE
            ELSE TRUE
        END                                         AS is_active,

        -- Audit
        ERDAT                                       AS created_date,
        ERNAM                                       AS created_by,

        -- ETL metadata
        _LOADED_AT                                  AS bronze_loaded_at,
        CURRENT_TIMESTAMP()                         AS silver_loaded_at

    FROM source
)

SELECT * FROM cleaned
