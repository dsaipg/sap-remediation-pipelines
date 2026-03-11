-- Gold Layer: Consolidated Financial Master Data (S/4HANA)
-- Sources: stg_ska1_s4 (GL accounts), stg_csks_s4 (cost centers), stg_bp (business partners)
-- This is the REFERENCE table consumed by the Streamlit report
--
-- S/4HANA migration notes:
--   - stg_lfa1 replaced by stg_bp (Business Partner unifies vendors + customers)
--   - stg_ska1 replaced by stg_ska1_s4 (adds functional_area, gl_account_type)
--   - stg_csks replaced by stg_csks_s4 (adds functional_area, segment)
--   - VENDOR rows now keyed on business_partner_number (PARTNER); LEGACY_LIFNR retained as vendor_number

WITH gl_accounts AS (
    SELECT
        'GL_ACCOUNT'                                AS master_data_type,
        gl_account_number                           AS entity_id,
        short_description                           AS entity_name,
        long_description                            AS entity_full_name,
        account_class                               AS classification,
        pl_statement_type                           AS sub_classification,
        chart_of_accounts                           AS parent_group,
        account_group                               AS entity_group,
        NULL                                        AS country_code,
        NULL                                        AS city,
        NULL                                        AS responsible_person,
        is_active,
        is_blocked,
        is_deleted,
        NULL::DATE                                  AS valid_from,
        NULL::DATE                                  AS valid_to,
        NULL::DATE                                  AS created_date,
        functional_area,
        silver_loaded_at
    FROM {{ ref('stg_ska1_s4') }}
),

cost_centers AS (
    SELECT
        'COST_CENTER'                               AS master_data_type,
        cost_center                                 AS entity_id,
        description                                 AS entity_name,
        long_description                            AS entity_full_name,
        category_desc                               AS classification,
        cost_center_group                           AS sub_classification,
        controlling_area                            AS parent_group,
        profit_center                               AS entity_group,
        NULL                                        AS country_code,
        NULL                                        AS city,
        responsible_person,
        is_active,
        FALSE                                       AS is_blocked,
        FALSE                                       AS is_deleted,
        valid_from,
        valid_to,
        NULL::DATE                                  AS created_date,
        functional_area,
        silver_loaded_at
    FROM {{ ref('stg_csks_s4') }}
),

-- Business Partners replace stg_lfa1 (vendors) and can also represent customers
business_partners AS (
    SELECT
        'VENDOR'                                    AS master_data_type,
        business_partner_number                     AS entity_id,
        partner_name                                AS entity_name,
        COALESCE(partner_name || ' - ' || partner_name_2, partner_name) AS entity_full_name,
        bp_role_desc                                AS classification,
        bp_type_desc                                AS sub_classification,
        bp_group                                    AS parent_group,
        NULL                                        AS entity_group,
        country_code,
        city,
        NULL                                        AS responsible_person,
        is_active,
        is_blocked,
        is_deleted,
        NULL::DATE                                  AS valid_from,
        NULL::DATE                                  AS valid_to,
        created_date,
        NULL                                        AS functional_area,
        silver_loaded_at
    FROM {{ ref('stg_bp') }}
),

unioned AS (
    SELECT * FROM gl_accounts
    UNION ALL
    SELECT * FROM cost_centers
    UNION ALL
    SELECT * FROM business_partners
)

SELECT
    *,
    CURRENT_TIMESTAMP()                             AS gold_loaded_at
FROM unioned
