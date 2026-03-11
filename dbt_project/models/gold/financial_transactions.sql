-- Gold Layer: Consolidated Financial Transactions (S/4HANA)
-- Source: stg_acdoca (replaces stg_bkpf + stg_bseg join)
-- Enriched with: stg_ska1_s4 (GL accounts), stg_csks_s4 (cost centers)
-- This is the PRIMARY table consumed by the Streamlit report
--
-- S/4HANA migration notes:
--   - ACDOCA is already flat (no header/line-item join needed)
--   - exchange_rate not present in ACDOCA; set to NULL for backward compatibility
--   - New fields added: ledger_id, amount_global_currency, business_partner_number,
--     functional_area, segment, material_number, plant, quantity, unit_of_measure

WITH transactions AS (
    SELECT * FROM {{ ref('stg_acdoca') }}
    WHERE is_reversed = FALSE
),

gl_accounts AS (
    SELECT * FROM {{ ref('stg_ska1_s4') }}
),

cost_centers AS (
    SELECT * FROM {{ ref('stg_csks_s4') }}
    WHERE is_active = TRUE
),

joined AS (
    SELECT
        -- Transaction identity
        t.company_code,
        t.document_number,
        t.fiscal_year,
        t.line_item_number,

        -- Document context
        t.document_type,
        t.document_type_desc,
        t.posting_date,
        t.document_date,
        t.fiscal_period,
        t.fiscal_quarter,
        t.reference_document,
        t.header_text,
        t.created_by_user,

        -- S/4HANA ledger field
        t.ledger_id,

        -- Account details
        t.account_type_code,
        t.account_type_desc,
        t.gl_account_number,
        gl.short_description                        AS gl_account_name,
        gl.long_description                         AS gl_account_full_name,
        gl.account_class,
        gl.pl_statement_type,
        gl.functional_area                          AS gl_functional_area,

        -- Cost allocation
        t.cost_center,
        cc.description                              AS cost_center_name,
        cc.category_desc                            AS cost_center_category,
        cc.cost_center_group,
        t.profit_center,
        t.internal_order,

        -- New S/4HANA controlling fields
        t.functional_area,
        t.segment,

        -- Amounts
        t.debit_credit_indicator,
        t.debit_credit_desc,
        t.amount_local_currency,
        t.amount_doc_currency,
        t.amount_global_currency,                   -- new in S/4HANA (OSL)
        t.signed_amount_local,
        t.signed_amount_doc,
        t.currency_code,
        NULL::FLOAT                                 AS exchange_rate,  -- not in ACDOCA; retained for schema compat

        -- Partners (BPNR supersedes LIFNR/KUNNR in S/4HANA)
        t.business_partner_number,
        t.vendor_number,
        t.customer_number,
        t.line_item_text,
        t.tax_code,

        -- Material Ledger (new in S/4HANA)
        t.material_number,
        t.plant,
        t.quantity,
        t.unit_of_measure,

        -- Reference transaction (new in S/4HANA)
        t.reference_transaction_type,

        -- ETL metadata
        t.bronze_loaded_at,
        CURRENT_TIMESTAMP()                         AS gold_loaded_at

    FROM transactions t
    LEFT JOIN gl_accounts gl
        ON t.gl_account_number = gl.gl_account_number
    LEFT JOIN cost_centers cc
        ON t.cost_center = cc.cost_center
)

SELECT * FROM joined
