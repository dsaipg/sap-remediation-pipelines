"""
SAP Finance Dashboard — Streamlit App
Consumes the Gold layer tables: FINANCIAL_TRANSACTIONS and FINANCIAL_MASTER_DATA

This represents the "report" that depends on the Gold tables
and must continue to work after the S/4HANA migration.
"""

import os
import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from dotenv import load_dotenv
import snowflake.connector

load_dotenv()

# ── Page config ──
st.set_page_config(
    page_title="SAP Finance Dashboard",
    page_icon="📊",
    layout="wide"
)


@st.cache_resource
def get_connection():
    """Create Snowflake connection."""
    return snowflake.connector.connect(
        account=os.getenv("SNOWFLAKE_ACCOUNT"),
        user=os.getenv("SNOWFLAKE_USER"),
        password=os.getenv("SNOWFLAKE_PASSWORD"),
        database=os.getenv("SNOWFLAKE_DATABASE", "SAP_REMEDIATION"),
        warehouse=os.getenv("SNOWFLAKE_WAREHOUSE", "SAP_REMEDIATION_WH"),
        role=os.getenv("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
    )


@st.cache_data(ttl=60)
def load_transactions():
    """Load financial transactions from Gold layer."""
    conn = get_connection()
    query = """
    SELECT * FROM SAP_REMEDIATION.GOLD.FINANCIAL_TRANSACTIONS
    ORDER BY posting_date, document_number, line_item_number
    """
    return pd.read_sql(query, conn)


@st.cache_data(ttl=60)
def load_master_data():
    """Load financial master data from Gold layer."""
    conn = get_connection()
    query = """
    SELECT * FROM SAP_REMEDIATION.GOLD.FINANCIAL_MASTER_DATA
    ORDER BY master_data_type, entity_id
    """
    return pd.read_sql(query, conn)


def main():
    st.title("📊 SAP Finance Dashboard")
    st.caption("Consuming Gold Layer: FINANCIAL_TRANSACTIONS + FINANCIAL_MASTER_DATA")

    # Connection check
    try:
        txn_df = load_transactions()
        master_df = load_master_data()
    except Exception as e:
        st.error(f"Failed to connect to Snowflake: {e}")
        st.info("Make sure you've run the dbt models: `cd dbt_project && dbt run`")
        st.code("""
# Quick setup:
export SNOWFLAKE_ACCOUNT=your_account
export SNOWFLAKE_USER=your_user
export SNOWFLAKE_PASSWORD=your_password
cd dbt_project && dbt run
cd ../streamlit && streamlit run app.py
        """)
        return

    # ── Sidebar filters ──
    st.sidebar.header("Filters")

    periods = sorted(txn_df["FISCAL_PERIOD"].unique())
    selected_periods = st.sidebar.multiselect(
        "Fiscal Period", periods, default=periods
    )

    doc_types = sorted(txn_df["DOCUMENT_TYPE_DESC"].unique())
    selected_types = st.sidebar.multiselect(
        "Document Type", doc_types, default=doc_types
    )

    # Apply filters
    filtered = txn_df[
        (txn_df["FISCAL_PERIOD"].isin(selected_periods)) &
        (txn_df["DOCUMENT_TYPE_DESC"].isin(selected_types))
    ]

    # ── KPI Row ──
    col1, col2, col3, col4 = st.columns(4)

    total_debits = filtered[filtered["DEBIT_CREDIT_DESC"] == "Debit"]["AMOUNT_LOCAL_CURRENCY"].sum()
    total_credits = filtered[filtered["DEBIT_CREDIT_DESC"] == "Credit"]["AMOUNT_LOCAL_CURRENCY"].sum()
    num_documents = filtered["DOCUMENT_NUMBER"].nunique()
    num_vendors = master_df[master_df["MASTER_DATA_TYPE"] == "VENDOR"]["ENTITY_ID"].nunique()

    col1.metric("Total Debits", f"${total_debits:,.0f}")
    col2.metric("Total Credits", f"${total_credits:,.0f}")
    col3.metric("Documents", f"{num_documents}")
    col4.metric("Active Vendors", f"{num_vendors}")

    # ── Charts Row ──
    chart_col1, chart_col2 = st.columns(2)

    with chart_col1:
        st.subheader("Revenue & Expenses by Period")
        period_data = (
            filtered.groupby(["FISCAL_PERIOD", "ACCOUNT_CLASS"])["SIGNED_AMOUNT_LOCAL"]
            .sum()
            .reset_index()
        )
        if not period_data.empty:
            fig = px.bar(
                period_data,
                x="FISCAL_PERIOD",
                y="SIGNED_AMOUNT_LOCAL",
                color="ACCOUNT_CLASS",
                barmode="group",
                labels={"SIGNED_AMOUNT_LOCAL": "Amount ($)", "FISCAL_PERIOD": "Period"},
            )
            st.plotly_chart(fig, use_container_width=True)

    with chart_col2:
        st.subheader("Spend by Document Type")
        type_data = (
            filtered.groupby("DOCUMENT_TYPE_DESC")["AMOUNT_LOCAL_CURRENCY"]
            .sum()
            .reset_index()
        )
        if not type_data.empty:
            fig = px.pie(
                type_data,
                values="AMOUNT_LOCAL_CURRENCY",
                names="DOCUMENT_TYPE_DESC",
            )
            st.plotly_chart(fig, use_container_width=True)

    # ── Cost Center Analysis ──
    st.subheader("Expenses by Cost Center")
    cc_data = (
        filtered[filtered["COST_CENTER"].notna()]
        .groupby(["COST_CENTER", "COST_CENTER_NAME"])["SIGNED_AMOUNT_LOCAL"]
        .sum()
        .reset_index()
        .sort_values("SIGNED_AMOUNT_LOCAL", ascending=True)
    )
    if not cc_data.empty:
        fig = px.bar(
            cc_data,
            x="SIGNED_AMOUNT_LOCAL",
            y="COST_CENTER_NAME",
            orientation="h",
            labels={"SIGNED_AMOUNT_LOCAL": "Net Amount ($)", "COST_CENTER_NAME": "Cost Center"},
        )
        st.plotly_chart(fig, use_container_width=True)

    # ── Detail Tables ──
    tab1, tab2, tab3 = st.tabs(["Transactions", "Master Data", "Data Lineage"])

    with tab1:
        st.subheader("Transaction Detail")
        display_cols = [
            "POSTING_DATE", "DOCUMENT_NUMBER", "DOCUMENT_TYPE_DESC",
            "GL_ACCOUNT_NAME", "DEBIT_CREDIT_DESC", "AMOUNT_LOCAL_CURRENCY",
            "COST_CENTER_NAME", "VENDOR_NUMBER", "LINE_ITEM_TEXT"
        ]
        available_cols = [c for c in display_cols if c in filtered.columns]
        st.dataframe(filtered[available_cols], use_container_width=True, height=400)

    with tab2:
        st.subheader("Financial Master Data")
        st.dataframe(master_df, use_container_width=True, height=400)

    with tab3:
        st.subheader("Data Lineage (Current Pipeline)")
        st.markdown("""
        ```
        ┌─────────────────────────────────────────────────────────┐
        │  BRONZE (Raw SAP ECC)                                   │
        │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐        │
        │  │ BKPF │ │ BSEG │ │ SKA1 │ │ CSKS │ │ LFA1 │        │
        │  └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘        │
        │     │        │        │        │        │              │
        │  ───┼────────┼────────┼────────┼────────┼──── dbt ──  │
        │     ▼        ▼        ▼        ▼        ▼              │
        │  SILVER (Cleaned)                                       │
        │  ┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐   │
        │  │stg_bkpf││stg_bseg││stg_ska1││stg_csks││stg_lfa1│   │
        │  └──┬─────┘└──┬─────┘└──┬─────┘└──┬─────┘└──┬─────┘   │
        │     │        │        │        │        │              │
        │  ───┼────────┼────────┼────────┼────────┼──── dbt ──  │
        │     ▼        ▼        ▼        ▼        ▼              │
        │  GOLD (Business-Ready)                                  │
        │  ┌──────────────────────┐ ┌──────────────────────┐     │
        │  │FINANCIAL_TRANSACTIONS│ │ FINANCIAL_MASTER_DATA │     │
        │  └──────────┬───────────┘ └──────────┬───────────┘     │
        │             │                        │                  │
        │  ───────────┼────────────────────────┼──────────────── │
        │             ▼                        ▼                  │
        │         📊 THIS DASHBOARD                               │
        └─────────────────────────────────────────────────────────┘
        ```
        """)

    # ── Footer ──
    st.divider()
    st.caption(
        f"Data source: SAP_REMEDIATION.GOLD | "
        f"Rows: {len(filtered)} transactions, {len(master_df)} master records | "
        f"POC: SAP S/4HANA Remediation Agent"
    )


if __name__ == "__main__":
    main()
