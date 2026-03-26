#!/usr/bin/env bash
# ============================================================
# SAP Remediation POC — Full Reset Script
# Wipes all generated artifacts and restores the "before" state
# so the entire demo can be re-run from scratch.
#
# What this does:
#   1. Switch git back to main (restores ECC dbt models)
#   2. Delete the S4 migration branch locally (+ optionally on origin)
#   3. Clear agent run artifacts (runs/run_*)
#   4. Re-seed Snowflake (Bronze ECC + NEW_MODEL S4 schema)
#   5. Rebuild dbt Gold layer with ECC models
#
# Usage:
#   ./reset_poc.sh            # full reset
#   ./reset_poc.sh --no-sf    # skip Snowflake re-seed (git + dbt only)
#   ./reset_poc.sh --no-dbt   # skip dbt rebuild
# ============================================================

set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRANCH="remediation/s4hana-migration"
SKIP_SF=false
SKIP_DBT=false

for arg in "$@"; do
  case $arg in
    --no-sf)  SKIP_SF=true  ;;
    --no-dbt) SKIP_DBT=true ;;
  esac
done

echo "============================================================"
echo "  SAP Remediation POC — Reset"
echo "============================================================"

# ── Step 1: Git reset to main ────────────────────────────────
echo ""
echo "[1/5] Restoring git to main branch..."
cd "$ROOT_DIR"
git checkout main
echo "  Current branch: $(git branch --show-current)"

# Delete local S4 branch if it exists
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "  Deleting local branch: $BRANCH"
  git branch -D "$BRANCH"
fi

# ── Step 2: Close GitHub PR (if gh is available) ─────────────
echo ""
echo "[2/5] Closing open PRs on $BRANCH..."
if command -v gh &> /dev/null; then
  PR_NUMBER=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null || echo "")
  if [ -n "$PR_NUMBER" ]; then
    gh pr close "$PR_NUMBER" --delete-branch
    echo "  Closed PR #$PR_NUMBER and deleted remote branch"
  else
    # Try to delete remote branch even if no PR
    if git ls-remote --exit-code origin "$BRANCH" &>/dev/null; then
      git push origin --delete "$BRANCH"
      echo "  Deleted remote branch: $BRANCH"
    else
      echo "  No open PR or remote branch found — skipping"
    fi
  fi
else
  echo "  gh CLI not found — skipping PR close"
fi

# ── Step 3: Clear agent run artifacts ────────────────────────
echo ""
echo "[3/5] Clearing agent run artifacts..."
RUNS_DIR="$ROOT_DIR/agent/runs"
COUNT=$(find "$RUNS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
if [ "$COUNT" -gt 0 ]; then
  find "$RUNS_DIR" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
  echo "  Deleted $COUNT run director(ies)"
else
  echo "  No run artifacts to clear"
fi

# ── Step 4: Re-seed Snowflake ────────────────────────────────
echo ""
if [ "$SKIP_SF" = true ]; then
  echo "[4/5] Skipping Snowflake re-seed (--no-sf)"
else
  echo "[4/5] Re-seeding Snowflake..."
  echo "  NOTE: Run these SQL scripts in your Snowflake worksheet (in order):"
  echo "    1. snowflake/02_create_bronze_tables.sql   (CREATE OR REPLACE — wipes & recreates)"
  echo "    2. snowflake/03_seed_bronze_data.sql       (loads ECC seed data)"
  echo "    3. snowflake/04_create_new_model_tables.sql (CREATE OR REPLACE — recreates S4 schema)"
  echo ""
  echo "  Or if you have snowsql configured:"
  echo "    snowsql -f snowflake/02_create_bronze_tables.sql"
  echo "    snowsql -f snowflake/03_seed_bronze_data.sql"
  echo "    snowsql -f snowflake/04_create_new_model_tables.sql"
  echo ""
  echo "  Or run via the agent connection test:"
  echo "    cd agent && python agent_main.py test"
fi

# ── Step 5: Rebuild dbt with ECC models ──────────────────────
echo ""
if [ "$SKIP_DBT" = true ]; then
  echo "[5/5] Skipping dbt rebuild (--no-dbt)"
else
  echo "[5/5] Rebuilding dbt Gold layer with ECC models (main branch)..."
  cd "$ROOT_DIR/dbt_project"
  if [ -f profiles.yml ] || [ -f ~/.dbt/profiles.yml ]; then
    dbt run --select staging gold
    echo "  dbt run complete"
  else
    echo "  dbt profiles.yml not found — skipping dbt run"
    echo "  Run manually: cd dbt_project && dbt run --select staging gold"
  fi
fi

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  RESET COMPLETE"
echo "============================================================"
echo ""
echo "  State restored to:"
echo "    - Git branch:    main (ECC dbt models)"
echo "    - Agent runs:    cleared"
echo "    - S4 branch:     deleted (local + remote)"
echo ""
echo "  To run the full POC demo:"
echo "    cd agent && python agent_main.py remediate"
echo ""
echo "  This will:"
echo "    1. Connect to Snowflake"
echo "    2. Detect BRONZE vs NEW_MODEL schema differences"
echo "    3. Generate new S4 dbt models using Claude AI"
echo "    4. Save artifacts to agent/runs/run_<timestamp>/"
echo "    5. Produce a PR-ready change document"
echo ""
