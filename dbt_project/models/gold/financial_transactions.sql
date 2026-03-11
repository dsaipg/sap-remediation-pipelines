-- Gold Layer: Consolidated Financial Transactions
-- Joins: stg_bkpf (headers) + stg_bseg (line items) + stg_ska1 (GL) + stg_csks (cost centers)
-- This is the PRIMARY table consumed by the Streamlit report
--
-- Business logic:
--   - Each row = one accounting line item with full context
--   - Enriched with GL account descriptions, cost center names
--   - Signed amounts for easy aggregation
--   - Excludes reversed documents

WITH headers AS (
    SELECT * FROM {{ ref('stg_bkpf') }}
    WHERE is_reversed = FALSE
),

line_items AS (
    SELECT * FROM {{ ref('stg_bseg') }}
),

gl_accounts AS (
    SELECT * FROM {{ ref('stg_ska1') }}
),

cost_centers AS (
    SELECT * FROM {{ ref('stg_csks') }}
    WHERE is_active = TRUE
),

joined AS (
    SELECT
        -- Transaction identity
        h.company_code,
        h.document_number,
        h.fiscal_year,
        li.line_item_number,

        -- Document context
        h.document_type,
        h.document_type_desc,
        h.posting_date,
        h.document_date,
        h.fiscal_period,
        h.fiscal_quarter,
        h.reference_document,
        h.header_text,
        h.created_by_user,

        -- Account details
        li.account_type_code,
        li.account_type_desc,
        li.gl_account_number,
        gl.short_description                        AS gl_account_name,
        gl.long_description                         AS gl_account_full_name,
        gl.account_class,
        gl.pl_statement_type,

        -- Cost allocation
        li.cost_center,
        cc.description                              AS cost_center_name,
        cc.category_desc                            AS cost_center_category,
        cc.cost_center_group,
        li.profit_center,
        li.internal_order,

        -- Amounts
        li.debit_credit_indicator,
        li.debit_credit_desc,
        li.amount_local_currency,
        li.amount_doc_currency,
        li.signed_amount_local,
        li.signed_amount_doc,
        h.currency_code,
        h.exchange_rate,

        -- Partners
        li.vendor_number,
        li.customer_number,
        li.line_item_text,
        li.tax_code,

        -- ETL metadata
        h.bronze_loaded_at                          AS header_loaded_at,
        li.bronze_loaded_at                         AS line_item_loaded_at,
        CURRENT_TIMESTAMP()                         AS gold_loaded_at

    FROM line_items li
    INNER JOIN headers h
        ON  li.company_code = h.company_code
        AND li.document_number = h.document_number
        AND li.fiscal_year = h.fiscal_year
    LEFT JOIN gl_accounts gl
        ON li.gl_account_number = gl.gl_account_number
    LEFT JOIN cost_centers cc
        ON li.cost_center = cc.cost_center
)

SELECT * FROM joined
