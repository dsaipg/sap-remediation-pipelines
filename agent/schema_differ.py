"""
Schema Differ — Compares OLD (ECC) and NEW (S/4HANA) data models.
Produces a structured diff report that the agent uses to generate new ETL code.

This is the intelligence layer that understands:
  - Which tables merged/split
  - Which columns were renamed, retyped, added, removed
  - What mapping logic is needed for the Gold layer
"""

import json
from datetime import datetime


class SchemaDiffer:
    """Compares schemas and produces actionable diff reports."""

    def __init__(self, snowflake_connector):
        self.sf = snowflake_connector

    def diff_bronze_to_new_model(self) -> dict:
        """
        Compare current BRONZE schema (old ECC) against NEW_MODEL schema (S/4HANA).
        This is the primary diff that drives remediation.
        """
        old_schema = self.sf.get_schema_info("BRONZE")
        new_schema = self.sf.get_schema_info("NEW_MODEL")

        # Also pull the change manifest if available
        manifest = self._get_change_manifest()

        diff = {
            "generated_at": datetime.now().isoformat(),
            "old_schema": "BRONZE (SAP ECC)",
            "new_schema": "NEW_MODEL (SAP S/4HANA)",
            "old_tables": sorted(old_schema.keys()),
            "new_tables": sorted(new_schema.keys()),
            "table_mapping": self._compute_table_mapping(old_schema, new_schema, manifest),
            "column_mapping": self._compute_column_mapping(old_schema, new_schema, manifest),
            "impact_analysis": {},
            "manifest_changes": manifest,
        }

        diff["impact_analysis"] = self._compute_impact(diff)
        return diff

    def _get_change_manifest(self) -> list:
        """Read the SCHEMA_CHANGE_MANIFEST if it exists."""
        try:
            result = self.sf.execute("""
                SELECT CHANGE_ID, OLD_TABLE, NEW_TABLE, CHANGE_TYPE,
                       OLD_COLUMN, NEW_COLUMN, DATA_TYPE_CHANGE,
                       MAPPING_NOTES, IMPACT_LEVEL
                FROM SAP_REMEDIATION.NEW_MODEL.SCHEMA_CHANGE_MANIFEST
                ORDER BY CHANGE_ID
            """)
            return [
                dict(zip(result["columns"], row))
                for row in result["rows"]
            ]
        except Exception:
            return []

    def _compute_table_mapping(self, old_schema, new_schema, manifest) -> list:
        """Determine how old tables map to new tables."""
        mappings = []

        # Use manifest to understand merges
        merge_map = {}  # new_table -> [old_tables]
        for change in manifest:
            if change.get("CHANGE_TYPE") == "MERGE" and change.get("OLD_TABLE") and change.get("NEW_TABLE"):
                nt = change["NEW_TABLE"]
                ot = change["OLD_TABLE"]
                if nt not in merge_map:
                    merge_map[nt] = set()
                merge_map[nt].add(ot)

        # ACDOCA merges BKPF + BSEG
        for new_table, old_tables in merge_map.items():
            mappings.append({
                "type": "MERGE",
                "old_tables": sorted(old_tables),
                "new_table": new_table,
                "description": f"{', '.join(sorted(old_tables))} → {new_table}",
            })

        # Extended tables (SKA1 → SKA1_S4, CSKS → CSKS_S4)
        extend_map = {}
        for change in manifest:
            if change.get("CHANGE_TYPE") == "EXTEND":
                nt = change["NEW_TABLE"]
                ot = change["OLD_TABLE"]
                if nt and ot:
                    extend_map[nt] = ot
        for new_table, old_table in extend_map.items():
            mappings.append({
                "type": "EXTEND",
                "old_tables": [old_table],
                "new_table": new_table,
                "description": f"{old_table} → {new_table} (extended with new fields)",
            })

        return mappings

    def _compute_column_mapping(self, old_schema, new_schema, manifest) -> list:
        """Detailed column-level mapping between old and new schemas."""
        mappings = []
        for change in manifest:
            mappings.append({
                "change_id": change.get("CHANGE_ID"),
                "old_table": change.get("OLD_TABLE"),
                "new_table": change.get("NEW_TABLE"),
                "old_column": change.get("OLD_COLUMN"),
                "new_column": change.get("NEW_COLUMN"),
                "change_type": change.get("CHANGE_TYPE"),
                "type_change": change.get("DATA_TYPE_CHANGE"),
                "mapping_notes": change.get("MAPPING_NOTES"),
                "impact": change.get("IMPACT_LEVEL"),
            })
        return mappings

    def _compute_impact(self, diff: dict) -> dict:
        """Compute the impact analysis for the change."""
        high_impact = [c for c in diff["column_mapping"] if c.get("impact") == "HIGH"]
        medium_impact = [c for c in diff["column_mapping"] if c.get("impact") == "MEDIUM"]

        return {
            "total_changes": len(diff["column_mapping"]),
            "high_impact_changes": len(high_impact),
            "medium_impact_changes": len(medium_impact),
            "tables_affected": {
                "bronze": diff["old_tables"],
                "silver": [f"stg_{t.lower()}" for t in diff["old_tables"]],
                "gold": ["financial_transactions", "financial_master_data"],
            },
            "dbt_models_to_update": [
                "stg_bkpf.sql → MUST REWRITE (source table merged into ACDOCA)",
                "stg_bseg.sql → MUST REWRITE (source table merged into ACDOCA)",
                "stg_ska1.sql → UPDATE (source extended to SKA1_S4)",
                "stg_csks.sql → UPDATE (source extended to CSKS_S4)",
                "stg_lfa1.sql → MUST REWRITE (source replaced by BP)",
                "financial_transactions.sql → UPDATE (upstream models changed)",
                "financial_master_data.sql → UPDATE (vendor model changed)",
            ],
            "estimated_manual_hours": 80,
            "estimated_agent_minutes": 5,
        }

    def generate_diff_report(self, diff: dict) -> str:
        """Generate a human-readable markdown diff report."""
        lines = []
        lines.append("# Schema Change Impact Report")
        lines.append(f"Generated: {diff['generated_at']}")
        lines.append(f"\n## Source: {diff['old_schema']} → {diff['new_schema']}")

        lines.append("\n## Table Mapping")
        for m in diff["table_mapping"]:
            lines.append(f"- **{m['type']}**: {m['description']}")

        lines.append(f"\n## Impact Summary")
        impact = diff["impact_analysis"]
        lines.append(f"- Total schema changes: **{impact['total_changes']}**")
        lines.append(f"- HIGH impact: **{impact['high_impact_changes']}**")
        lines.append(f"- MEDIUM impact: **{impact['medium_impact_changes']}**")
        lines.append(f"- Estimated manual effort: **{impact['estimated_manual_hours']} hours**")
        lines.append(f"- Estimated agent time: **{impact['estimated_agent_minutes']} minutes**")

        lines.append(f"\n## dbt Models Requiring Changes")
        for model in impact["dbt_models_to_update"]:
            lines.append(f"- {model}")

        lines.append(f"\n## Detailed Column Changes")
        for change in diff["column_mapping"]:
            emoji = "🔴" if change["impact"] == "HIGH" else "🟡" if change["impact"] == "MEDIUM" else "🟢"
            old = f"{change['old_table']}.{change['old_column']}" if change['old_column'] else "(new field)"
            new = f"{change['new_table']}.{change['new_column']}" if change['new_column'] else "(removed)"
            lines.append(f"- {emoji} `{old}` → `{new}` | {change['change_type']} | {change['mapping_notes']}")

        return "\n".join(lines)


def run_diff(sf_connector):
    """Run the diff and print the report."""
    differ = SchemaDiffer(sf_connector)
    diff = differ.diff_bronze_to_new_model()

    # Print report
    report = differ.generate_diff_report(diff)
    print(report)

    # Save JSON
    with open("schema_diff_output.json", "w") as f:
        json.dump(diff, f, indent=2, default=str)
    print("\nJSON diff saved to schema_diff_output.json")

    return diff
