-- Silver Layer: Cleaned Cost Center Master Data
-- Source: BRONZE.CSKS (SAP ECC)
-- Transformations:
--   1. Decode cost center categories
--   2. Determine active/expired status from valid-to date
--   3. Standardize names

WITH source AS (
    SELECT * FROM {{ source('bronze', 'CSKS') }}
    WHERE MANDT = '100'
),

cleaned AS (
    SELECT
        KOKRS                                       AS controlling_area,
        KOSTL                                       AS cost_center,
        BUKRS                                       AS company_code,

        -- Validity
        DATAB                                       AS valid_from,
        DATBI                                       AS valid_to,
        CASE
            WHEN DATBI >= CURRENT_DATE() THEN TRUE
            ELSE FALSE
        END                                         AS is_active,

        -- Classification
        KOSAR                                       AS category_code,
        CASE KOSAR
            WHEN 'E' THEN 'Executive/Management'
            WHEN 'F' THEN 'Finance'
            WHEN 'P' THEN 'Production'
            WHEN 'V' THEN 'Sales/Distribution'
            WHEN 'H' THEN 'Administration/Overhead'
            WHEN 'L' THEN 'Logistics'
            ELSE 'Other (' || KOSAR || ')'
        END                                         AS category_desc,

        -- Organizational
        VERAK                                       AS responsible_person,
        KTEXT                                       AS description,
        LTEXT                                       AS long_description,
        APTS_GROUP                                  AS cost_center_group,
        PRCTR                                       AS profit_center,

        -- ETL metadata
        _LOADED_AT                                  AS bronze_loaded_at,
        CURRENT_TIMESTAMP()                         AS silver_loaded_at

    FROM source
)

SELECT * FROM cleaned
