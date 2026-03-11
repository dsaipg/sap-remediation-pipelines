-- Gold Layer: Consolidated Financial Master Data
-- Joins: stg_ska1 (GL accounts) + stg_csks (cost centers) + stg_lfa1 (vendors)
-- This is the REFERENCE table consumed by the Streamlit report
--
-- Purpose: Single source of truth for all finance master data dimensions
-- Used for: lookups, filters, drill-downs in reports

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
        silver_loaded_at
    FROM {{ ref('stg_ska1') }}
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
        silver_loaded_at
    FROM {{ ref('stg_csks') }}
),

vendors AS (
    SELECT
        'VENDOR'                                    AS master_data_type,
        vendor_number                               AS entity_id,
        vendor_name                                 AS entity_name,
        COALESCE(vendor_name || ' - ' || vendor_name_2, vendor_name) AS entity_full_name,
        vendor_account_group                        AS classification,
        NULL                                        AS sub_classification,
        NULL                                        AS parent_group,
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
        silver_loaded_at
    FROM {{ ref('stg_lfa1') }}
),

unioned AS (
    SELECT * FROM gl_accounts
    UNION ALL
    SELECT * FROM cost_centers
    UNION ALL
    SELECT * FROM vendors
)

SELECT
    *,
    CURRENT_TIMESTAMP()                             AS gold_loaded_at
FROM unioned
