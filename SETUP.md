# SAP S/4HANA Remediation POC — Setup Guide

## Business Case

SAP is retiring ECC and migrating customers to S/4HANA. When this happens, the
underlying table structures change dramatically:

- `BKPF + BSEG` (2 tables) → `ACDOCA` (1 flat Universal Journal table)
- `LFA1` (vendor master) → `BP` (Business Partner — unifies vendors + customers)
- `SKA1` → `SKA1_S4` (GL accounts extended with new fields)
- `CSKS` → `CSKS_S4` (cost centers extended with new fields)
- Fields get renamed, merged, and retyped throughout

Every company running SAP has downstream ETL pipelines (dbt models, reports,
dashboards) built on the old ECC tables. **All of them break after migration.**

Remediating these pipelines manually takes ~80 hours per system — a data engineer
must read SAP migration docs, map every field change, rewrite every model, test
it, and create a PR. Multiply that by dozens of pipelines across an enterprise.

**This POC is an AI agent that reduces 80 hours of manual remediation to 5 minutes:**
1. Detects schema changes automatically (BRONZE vs NEW_MODEL diff)
2. Reads the existing broken pipeline code
3. Calls Claude AI to generate the fixed dbt models
4. Commits the changes and raises a GitHub PR for human review

---

## Architecture

```
OLD SAP ECC (BRONZE)        NEW SAP S/4HANA (NEW_MODEL)
────────────────────        ───────────────────────────
BKPF (Doc Headers)    →    ACDOCA (Universal Journal — flat)
BSEG (Doc Line Items) →    replaces BKPF + BSEG + more
SKA1 (GL Accounts)    →    SKA1_S4 (extended)
CSKS (Cost Centers)   →    CSKS_S4 (extended)
LFA1 (Vendors)        →    BP (Business Partner)

Snowflake Medallion:
  BRONZE (raw ECC) → SILVER (cleaned, dbt) → GOLD (business-ready, dbt)
                                                      ↓
                                             Streamlit Dashboard

Agent:
  schema_differ.py  → compares BRONZE vs NEW_MODEL in Snowflake
  dbt_generator.py  → sends diff to Claude API, gets back new dbt models
  agent_main.py     → orchestrates the full pipeline
```

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.10+ | Agent + dashboard |
| Git | any | Version control |
| GitHub CLI (`gh`) | any | PR creation |
| Snowflake account | Enterprise (free trial ok) | Data warehouse |
| Anthropic API key | — | Claude AI for code generation |
| dbt | 1.7+ | ELT pipeline (installed via pip) |

---

## Step-by-Step Setup

### 1. Clone the repo

```bash
git clone https://github.com/dsaipg/sap-remediation-pipelines.git
cd sap-remediation-pipelines
```

### 2. Python environment

```bash
python -m venv .venv
source .venv/bin/activate        # Mac/Linux
# .venv\Scripts\activate         # Windows

pip install -r requirements.txt
```

### 3. Snowflake setup

You need a Snowflake account (free trial at snowflake.com — choose Enterprise on AWS).

In your Snowflake SQL Worksheet, run these scripts **in order**:

```
snowflake/01_setup_database.sql    → creates database, schemas, warehouse
snowflake/02_create_bronze_tables.sql  → creates ECC Bronze tables
snowflake/03_seed_bronze_data.sql  → loads fake ECC data (BKPF, BSEG, SKA1, CSKS, LFA1)
snowflake/04_create_new_model_tables.sql → creates S/4HANA tables + SCHEMA_CHANGE_MANIFEST
```

After running, verify:
```sql
SELECT COUNT(*) FROM SAP_REMEDIATION.BRONZE.BKPF;   -- should return 30
SELECT COUNT(*) FROM SAP_REMEDIATION.NEW_MODEL.ACDOCA; -- should return rows
```

### 4. Configure the agent

```bash
cp agent/.env.example agent/.env
```

Edit `agent/.env` and fill in:
```
SNOWFLAKE_ACCOUNT=your_account.region   # from Snowflake → Admin → Accounts
SNOWFLAKE_USER=your_username
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_DATABASE=SAP_REMEDIATION
SNOWFLAKE_WAREHOUSE=SAP_REMEDIATION_WH
SNOWFLAKE_ROLE=ACCOUNTADMIN
ANTHROPIC_API_KEY=sk-ant-xxxxx          # from console.anthropic.com
```

### 5. Configure dbt

```bash
cp dbt_project/profiles.yml ~/.dbt/profiles.yml
```

Edit `~/.dbt/profiles.yml` and fill in your Snowflake credentials.
**Important:** set `schema: PUBLIC` (not SILVER — that causes SILVER_SILVER naming bug):

```yaml
sap_remediation:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "your_account.region"
      user: "your_username"
      password: "your_password"
      role: ACCOUNTADMIN
      database: SAP_REMEDIATION
      warehouse: SAP_REMEDIATION_WH
      schema: PUBLIC          # ← must be PUBLIC, not SILVER
      threads: 4
      client_session_keep_alive: False
```

Verify dbt connection:
```bash
cd dbt_project && dbt debug
```

Build the ECC Silver + Gold pipeline:
```bash
dbt run
dbt test
```

### 6. GitHub CLI (for PR creation)

```bash
brew install gh       # Mac
gh auth login         # follow prompts → GitHub.com → HTTPS → browser
```

### 7. Test everything

```bash
# Test Snowflake connection
cd agent && python agent_main.py test

# Run schema diff (no AI call)
python agent_main.py diff

# Run full remediation (calls Claude, generates new dbt models, creates PR)
python agent_main.py remediate
```

### 8. Launch the dashboard

```bash
cd streamlit && streamlit run app.py
```

Open http://localhost:8501

---

## Demo Script

**Before every demo — run reset first:**
```bash
./reset_poc.sh
```
This ensures a clean slate: `main` branch, no old agent runs, ECC Gold tables in Snowflake.
Run this again between demos or after a failed run.

---

### Act 1 — The Problem (2 min)

1. Open Snowflake console → `SAP_REMEDIATION` database
2. Show `BRONZE` schema — point to BKPF, BSEG, SKA1, CSKS, LFA1
   > *"This is our live SAP ECC pipeline. Been running for years."*
3. Show `NEW_MODEL` schema next to it — point to ACDOCA, BP, SKA1_S4, CSKS_S4
   > *"SAP just delivered the new S/4HANA structure. BKPF and BSEG are gone — merged into ACDOCA. LFA1 is gone — replaced by BP."*
4. Open GitHub → `main` branch → `dbt_project/models/staging/`
   > *"All our dbt models reference the old tables. Every single one is now broken."*

---

### Act 2 — The Agent (3 min)

```bash
cd agent
python agent_main.py test
```
> *"Agent connects to both schemas — ECC and S/4HANA — confirmed."*

```bash
python agent_main.py diff
```
> *"24 schema changes detected. 10 high impact. Estimated 80 hours of manual work."*

```bash
python agent_main.py remediate
```
> *"Now we let Claude handle it."*

When it finishes, show `agent/runs/run_<timestamp>/`:
- `schema_diff_report.md` — what changed and why
- `dbt_remediated/` — the generated model code
- `PULL_REQUEST.md` — PR-ready documentation

---

### Act 3 — The Output (2 min)

- Open GitHub — PR is automatically created
  > *"The agent created a branch, committed the new models, and raised a PR — automatically."*
- Click into the PR diff, show `stg_acdoca.sql`
  > *"stg_bkpf and stg_bseg are gone. stg_acdoca replaces both. All the field renames are handled."*
- Point to the PR description
  > *"Full change documentation — ready for a human to review and approve. That's the only manual step."*

---

### Act 4 — The Result (2 min)

```bash
cd dbt_project && dbt run
```
> *"Deploy the fixed pipeline to Snowflake."*

Open browser at **http://localhost:8501** (run `cd streamlit && streamlit run app.py` if not already running)
> *"The finance dashboard — it still works. Zero changes to the report."*

Click the **Data Lineage** tab → toggle from ECC to S/4HANA
> *"Before and after — you can see exactly what changed in the pipeline."*

---

### The Pitch Close

> *"80 hours of manual remediation, done in 5 minutes. And this runs on every pipeline
> the moment SAP pushes the migration."*

---

### When to run `reset_poc.sh`

- Before every demo — gives you a clean slate
- After a failed run — wipes partial artifacts
- When showing the demo a second time to the same audience

```bash
./reset_poc.sh           # full reset
./reset_poc.sh --no-sf   # skip Snowflake re-seed (faster)
./reset_poc.sh --no-dbt  # skip dbt rebuild
```

---

## Running the Full Demo (commands only)

```bash
# 1. Build ECC pipeline in Snowflake
cd dbt_project && dbt run

# 2. Run the AI remediation agent
cd ../agent && python agent_main.py remediate

# 3. View the dashboard
cd ../streamlit && streamlit run app.py
```

The agent will:
- Detect 24 schema changes between ECC and S/4HANA
- Generate 6 new/updated dbt models using Claude
- Save everything to `agent/runs/run_<timestamp>/`
- Create a GitHub PR with full change documentation

---

## Resetting for a Fresh Demo Run

```bash
./reset_poc.sh
```

This wipes agent artifacts, deletes the S4 branch + closes the PR, and restores
the ECC Gold pipeline — so you can run the full demo again from scratch.

Options:
```bash
./reset_poc.sh --no-sf    # skip Snowflake re-seed
./reset_poc.sh --no-dbt   # skip dbt rebuild
```

---

## Phases

| Phase | Status | Description |
|-------|--------|-------------|
| 1 | Done | Snowflake + dbt ECC pipeline + Agent skeleton + Streamlit |
| 2 | Done | Git integration — auto branch, commit, PR via `gh` CLI |
| 3 | Planned | Palantir Foundry as source of NEW_MODEL schema |
| 4 | Planned | Jira ticket as trigger for full automation |

---

## Project Structure

```
sap_remediation_poc/
├── snowflake/              SQL scripts to set up Snowflake
│   ├── 01_setup_database.sql
│   ├── 02_create_bronze_tables.sql
│   ├── 03_seed_bronze_data.sql
│   └── 04_create_new_model_tables.sql
├── dbt_project/            dbt pipeline (Silver + Gold models)
│   ├── models/
│   │   ├── bronze_sources/ source definitions + sources.yml
│   │   ├── staging/        Silver models (stg_*.sql)
│   │   └── gold/           Gold models (financial_*.sql)
│   └── dbt_project.yml
├── agent/                  AI remediation agent
│   ├── agent_main.py       CLI entry point
│   ├── schema_differ.py    Compares BRONZE vs NEW_MODEL
│   ├── dbt_generator.py    Calls Claude to generate new models
│   ├── snowflake_connector.py
│   ├── .env.example        Credentials template
│   └── runs/               Agent output (gitignored)
├── streamlit/              Finance dashboard
│   └── app.py
├── reset_poc.sh            Full demo reset script
├── requirements.txt
└── SETUP.md                This file
```
