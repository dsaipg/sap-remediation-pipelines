# SAP S/4HANA Data Model Remediation POC

## The Problem
SAP is migrating from ECC to S/4HANA, consolidating classic finance tables (BKPF, BSEG, SKA1, CSKS, LFA1) into new structures (ACDOCA Universal Journal, BP Business Partner). Every downstream ETL pipeline must be remediated — a process that currently takes weeks of manual effort.

## This POC
An AI agent that **automatically detects schema changes, generates new ETL code, documents differences, and creates PRs** — reducing remediation from weeks to minutes.

## Architecture
```
OLD SAP ECC Tables          NEW SAP S/4HANA Tables
─────────────────           ──────────────────────
BKPF (Doc Headers)    →    ACDOCA (Universal Journal)
BSEG (Doc Line Items) →       replaces BKPF+BSEG+more
SKA1 (GL Accounts)    →    SKA1_S4 (GL Accounts, extended)
CSKS (Cost Centers)   →    CSKS_S4 (Cost Centers, extended)
LFA1 (Vendors)        →    BP (Business Partner, replaces vendors+customers)

Snowflake Medallion:
  BRONZE (raw)  →  SILVER (clean)  →  GOLD (business-ready)
  5 tables         5 tables            2 tables
                                        ├── FINANCIAL_TRANSACTIONS
                                        └── FINANCIAL_MASTER_DATA
                                              ↓
                                        Streamlit Dashboard
```

## Phase 1 Setup

### Prerequisites
- Snowflake free trial account (Enterprise, AWS)
- Python 3.10+
- VS Code

### Step 1: Python Environment
```bash
cd sap_remediation_poc
python -m venv .venv
source .venv/bin/activate        # Mac/Linux
# .venv\Scripts\activate         # Windows

pip install -r requirements.txt
```

### Step 2: Snowflake Setup
1. Log into your Snowflake console
2. Open a SQL Worksheet
3. Run the scripts in order:
   - `snowflake/01_setup_database.sql`
   - `snowflake/02_create_bronze_tables.sql`
   - `snowflake/03_seed_bronze_data.sql`
4. Verify: run `SELECT COUNT(*) FROM SAP_REMEDIATION.BRONZE.BKPF;`

### Step 3: Configure dbt
1. Copy `dbt_project/profiles.yml` to `~/.dbt/profiles.yml`
2. Edit it with your Snowflake credentials
3. Run:
```bash
cd dbt_project
dbt debug          # verify connection
dbt run            # build Silver + Gold
dbt test           # run data quality tests
```

### Step 4: Configure Agent
1. Copy `agent/.env.example` to `agent/.env`
2. Fill in your Snowflake credentials and Anthropic API key
3. Run:
```bash
cd agent
python agent_main.py
```

### Step 5: Streamlit Dashboard
```bash
cd streamlit
streamlit run app.py
```

## Phases
- **Phase 1**: Snowflake + dbt + Agent skeleton + Streamlit ← YOU ARE HERE
- **Phase 2**: Git integration (auto-PR, code versioning)
- **Phase 3**: Palantir Foundry connectivity
- **Phase 4**: Jira-triggered full automation
