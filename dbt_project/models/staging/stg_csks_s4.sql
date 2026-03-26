-- Silver Layer: Cost Center Master Data (S/4HANA Extended)
-- Source: NEW_MODEL.CSKS_S4
-- Extends: stg_csks (same core fields + new S/4HANA attributes)
--
-- New S/4HANA fields added to CSKS_S4:
--   - FUNC_AREA: Functional Area classification
--   - SEGMENT: Segment for segment-level reporting

WITH source AS (
    SELECT * FROM {{ source('new_model', 'CSKS_S4') }}
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

        -- Classification (same logic as ECC stg_csks)
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

        -- New S/4HANA fields
        NULLIF(FUNC_AREA, '')                       AS functional_area,
        NULLIF(SEGMENT, '')                         AS segment,

        -- ETL metadata
        _LOADED_AT                                  AS bronze_loaded_at,
        CURRENT_TIMESTAMP()                         AS silver_loaded_at

    FROM source
)

SELECT * FROM cleaned
