-- Silver Layer: Business Partner Master Data (S/4HANA)
-- Source: NEW_MODEL.BP
-- Replaces: stg_lfa1 (LFA1 vendor master) and stg_kna1 (customer master, ECC)
--
-- Key S/4HANA changes:
--   1. Single BP table unifies vendors AND customers (LFA1 + KNA1 merged)
--   2. LIFNR/KUNNR replaced by PARTNER (business partner number)
--   3. IS_BLOCKED/IS_DELETED are now native BOOLEAN (was VARCHAR 'X')
--   4. New fields: BP_ROLE (vendor/customer/both), BP_TYPE, EMAIL, LEGACY_LIFNR

WITH source AS (
    SELECT * FROM {{ source('new_model', 'BP') }}
    WHERE MANDT = '100'
),

cleaned AS (
    SELECT
        PARTNER                                     AS business_partner_number,
        LEGACY_LIFNR                                AS vendor_number,       -- cross-reference to old LIFNR
        LEGACY_KUNNR                                AS customer_number,     -- cross-reference to old KUNNR

        -- BP classification (new in S/4HANA)
        BP_ROLE                                     AS bp_role,
        CASE BP_ROLE
            WHEN 'FLVN00' THEN 'Vendor'
            WHEN 'FLCU00' THEN 'Customer'
            WHEN 'FLCU01' THEN 'Vendor and Customer'
            ELSE BP_ROLE
        END                                         AS bp_role_desc,
        BP_TYPE                                     AS bp_type,
        CASE BP_TYPE
            WHEN '1' THEN 'Organization'
            WHEN '2' THEN 'Person'
            ELSE 'Unknown'
        END                                         AS bp_type_desc,
        BP_GROUP                                    AS bp_group,

        -- Name
        NAME_ORG1                                   AS partner_name,        -- was NAME1
        NULLIF(NAME_ORG2, '')                       AS partner_name_2,      -- was NAME2
        NULLIF(NAME_FIRST, '')                      AS first_name,          -- new in S/4HANA
        NULLIF(NAME_LAST, '')                       AS last_name,           -- new in S/4HANA

        -- Address
        COUNTRY                                     AS country_code,        -- was LAND1
        CITY                                        AS city,                -- was ORT01
        POSTAL_CODE                                 AS postal_code,         -- was PSTLZ
        NULLIF(REGION, '')                          AS region,
        STREET                                      AS street_address,      -- was STRAS
        NULLIF(HOUSE_NUM, '')                       AS house_number,        -- new; split from STRAS
        NULLIF(EMAIL, '')                           AS email,               -- new in S/4HANA
        NULLIF(PHONE, '')                           AS phone_number,        -- was TELF1
        NULLIF(URL, '')                             AS website,             -- new in S/4HANA

        -- Tax
        NULLIF(TAX_NUM1, '')                        AS tax_number_1,        -- was STCD1
        NULLIF(TAX_NUM2, '')                        AS tax_number_2,        -- was STCD2
        NULLIF(TAX_TYPE, '')                        AS tax_type,            -- new
        NULLIF(INDUSTRY, '')                        AS industry_key,        -- new

        -- Status (now native BOOLEAN — no conversion needed)
        IS_BLOCKED                                  AS is_blocked,
        IS_DELETED                                  AS is_deleted,
        CASE
            WHEN IS_BLOCKED OR IS_DELETED THEN FALSE
            ELSE TRUE
        END                                         AS is_active,

        -- Audit
        CREATED_ON                                  AS created_date,        -- was ERDAT
        CREATED_BY                                  AS created_by,          -- was ERNAM
        CHANGED_ON                                  AS last_changed_date,   -- new in S/4HANA
        CHANGED_BY                                  AS last_changed_by,     -- new in S/4HANA

        -- ETL metadata
        _LOADED_AT                                  AS bronze_loaded_at,
        CURRENT_TIMESTAMP()                         AS silver_loaded_at

    FROM source
)

SELECT * FROM cleaned
