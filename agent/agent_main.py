"""
SAP Remediation Agent — Main Orchestrator

This is the entry point that coordinates the full remediation workflow:
  1. Connect to Snowflake
  2. Analyze schema differences (BRONZE vs NEW_MODEL)
  3. Read existing dbt models
  4. Generate new dbt models using Claude
  5. Deploy to test schema for validation
  6. Generate diff documentation for PR

Phase 1: Local execution against Snowflake
Phase 2: Adds Git PR creation
Phase 3: Adds Palantir Foundry as source
Phase 4: Adds Jira ticket as trigger
"""

import json
import sys
from pathlib import Path
from datetime import datetime

from snowflake_connector import SnowflakeConnector
from schema_differ import SchemaDiffer
from dbt_generator import DbtGenerator


class RemediationAgent:
    """Orchestrates the SAP data model remediation workflow."""

    def __init__(self, dbt_project_path: str = None):
        self.sf = SnowflakeConnector()
        self.differ = SchemaDiffer(self.sf)
        self.generator = DbtGenerator(dbt_project_path)
        self.run_id = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.output_dir = Path(f"runs/run_{self.run_id}")
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def run_full_remediation(self):
        """Execute the complete remediation pipeline."""
        print("=" * 70)
        print("  SAP S/4HANA Data Model Remediation Agent")
        print(f"  Run ID: {self.run_id}")
        print("=" * 70)

        # Step 1: Connect
        print("\n[1/6] Connecting to Snowflake...")
        self.sf.connect()
        self._verify_prerequisites()

        # Step 2: Analyze schema diff
        print("\n[2/6] Analyzing schema differences (BRONZE vs NEW_MODEL)...")
        diff = self.differ.diff_bronze_to_new_model()
        diff_report = self.differ.generate_diff_report(diff)
        self._save_artifact("schema_diff.json", json.dumps(diff, indent=2, default=str))
        self._save_artifact("schema_diff_report.md", diff_report)
        print(f"  Found {diff['impact_analysis']['total_changes']} schema changes")
        print(f"  HIGH impact: {diff['impact_analysis']['high_impact_changes']}")

        # Step 3: Read existing dbt models
        print("\n[3/6] Reading existing dbt models...")
        existing_models = self.generator.read_existing_models()
        print(f"  Found {len(existing_models)} existing models")
        for path in sorted(existing_models.keys()):
            print(f"    - {path}")

        # Step 4: Generate new models using Claude
        print("\n[4/6] Generating remediated dbt models using Claude AI...")
        new_models = self.generator.generate_remediated_models(diff, existing_models)
        generated_files = self.generator.save_generated_models(
            new_models,
            str(self.output_dir / "dbt_remediated")
        )
        print(f"  Generated {len(generated_files)} files")

        # Step 5: Generate diff documentation
        print("\n[5/6] Generating change documentation...")
        diff_doc = self.generator.generate_diff_document(existing_models, new_models)
        self._save_artifact("PULL_REQUEST.md", diff_doc)
        print(f"  PR document saved to {self.output_dir}/PULL_REQUEST.md")

        # Step 6: Deploy to test schema (optional)
        print("\n[6/6] Test schema deployment...")
        print("  Skipping deployment (run with --deploy to execute)")
        print("  In Phase 2, this will create a Git PR instead.")

        # Summary
        self._print_summary(diff, new_models, generated_files)

        # Cleanup
        self.sf.close()

    def run_test_connection(self):
        """Just test the Snowflake connection and show schema info."""
        print("Testing Snowflake connection...")
        self.sf.connect()
        self._verify_prerequisites()
        self.sf.close()

    def run_schema_diff_only(self):
        """Just run the schema diff without generating code."""
        print("Running schema diff...")
        self.sf.connect()
        diff = self.differ.diff_bronze_to_new_model()
        report = self.differ.generate_diff_report(diff)
        print(report)
        self.sf.close()

    def _verify_prerequisites(self):
        """Verify that all required schemas and tables exist."""
        bronze = self.sf.get_schema_info("BRONZE")
        new_model = self.sf.get_schema_info("NEW_MODEL")

        required_bronze = {"BKPF", "BSEG", "SKA1", "CSKS", "LFA1"}
        required_new = {"ACDOCA", "BP"}

        missing_bronze = required_bronze - set(bronze.keys())
        missing_new = required_new - set(new_model.keys())

        if missing_bronze:
            print(f"  ⚠️  Missing BRONZE tables: {missing_bronze}")
            print("  Run snowflake/02_create_bronze_tables.sql first!")
        else:
            print(f"  ✅ BRONZE schema: {sorted(bronze.keys())}")

        if missing_new:
            print(f"  ⚠️  Missing NEW_MODEL tables: {missing_new}")
            print("  Run snowflake/04_create_new_model_tables.sql first!")
        else:
            print(f"  ✅ NEW_MODEL schema: {sorted(new_model.keys())}")

        # Row counts
        for table in sorted(bronze.keys()):
            count = self.sf.get_row_count("BRONZE", table)
            print(f"    BRONZE.{table}: {count} rows")

    def _save_artifact(self, filename: str, content: str):
        """Save an artifact to the run output directory."""
        filepath = self.output_dir / filename
        filepath.write_text(content)

    def _print_summary(self, diff, new_models, generated_files):
        """Print the run summary."""
        print("\n" + "=" * 70)
        print("  REMEDIATION COMPLETE")
        print("=" * 70)
        print(f"\n  Run ID:           {self.run_id}")
        print(f"  Output directory:  {self.output_dir}")
        print(f"  Schema changes:    {diff['impact_analysis']['total_changes']}")
        print(f"  Files generated:   {len(generated_files)}")
        print(f"\n  Artifacts:")
        print(f"    - schema_diff.json        (full diff data)")
        print(f"    - schema_diff_report.md   (human-readable report)")
        print(f"    - PULL_REQUEST.md          (PR-ready change document)")
        print(f"    - dbt_remediated/          (new dbt models)")
        print(f"\n  Manual effort saved: ~{diff['impact_analysis']['estimated_manual_hours']} hours")
        print(f"\n  Next steps:")
        print(f"    1. Review generated models in {self.output_dir}/dbt_remediated/")
        print(f"    2. Review PULL_REQUEST.md for change documentation")
        print(f"    3. Run 'dbt run' with the new models in a test environment")
        print(f"    4. (Phase 2) Agent will auto-create a Git PR for approval")


def main():
    """CLI entry point."""
    import argparse
    parser = argparse.ArgumentParser(description="SAP Remediation Agent")
    parser.add_argument(
        "command",
        choices=["test", "diff", "remediate"],
        default="remediate",
        nargs="?",
        help="Command to run: test (connection), diff (schema only), remediate (full pipeline)"
    )
    parser.add_argument(
        "--dbt-path",
        default=None,
        help="Path to dbt project (default: ../dbt_project)"
    )
    args = parser.parse_args()

    agent = RemediationAgent(dbt_project_path=args.dbt_path)

    if args.command == "test":
        agent.run_test_connection()
    elif args.command == "diff":
        agent.run_schema_diff_only()
    elif args.command == "remediate":
        agent.run_full_remediation()


if __name__ == "__main__":
    main()
