"""
dbt Generator — Uses Claude to generate new dbt models based on schema changes.
This is the AI-powered core of the remediation agent.

Workflow:
  1. Receives the schema diff
  2. Reads existing dbt models
  3. Asks Claude to generate new models that handle the schema change
  4. Validates generated SQL
  5. Returns ready-to-deploy dbt models
"""

import os
import json
from pathlib import Path
from anthropic import Anthropic
from dotenv import load_dotenv

load_dotenv()


class DbtGenerator:
    """AI-powered dbt model generator for schema remediation."""

    def __init__(self, dbt_project_path: str = None):
        self.client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
        self.dbt_path = Path(dbt_project_path) if dbt_project_path else Path(__file__).parent.parent / "dbt_project"
        self.model = "claude-sonnet-4-20250514"

    def read_existing_models(self) -> dict:
        """Read all current dbt models from the project."""
        models = {}
        models_dir = self.dbt_path / "models"
        for sql_file in models_dir.rglob("*.sql"):
            relative_path = sql_file.relative_to(self.dbt_path)
            models[str(relative_path)] = sql_file.read_text()
        return models

    def generate_remediated_models(self, schema_diff: dict, existing_models: dict) -> dict:
        """
        Use Claude to generate new dbt models that handle the schema change.
        Returns a dict of {filepath: new_sql_content}.
        """
        prompt = self._build_generation_prompt(schema_diff, existing_models)

        response = self.client.messages.create(
            model=self.model,
            max_tokens=8000,
            system="""You are an expert SAP data engineer specializing in S/4HANA migrations.
You generate production-quality dbt models for Snowflake.
Your output must be valid dbt SQL using Jinja2 syntax ({{ ref() }}, {{ source() }}).
Return your response as JSON with the structure:
{
  "models": {
    "models/staging/stg_acdoca.sql": "-- SQL content here",
    ...
  },
  "changes_summary": "description of what changed and why"
}
Only return JSON, no markdown fences or other text.""",
            messages=[{"role": "user", "content": prompt}],
        )

        # Parse response
        response_text = response.content[0].text
        # Clean any markdown fences
        if "```json" in response_text:
            response_text = response_text.split("```json")[1].split("```")[0]
        elif "```" in response_text:
            response_text = response_text.split("```")[1].split("```")[0]

        try:
            result = json.loads(response_text)
        except json.JSONDecodeError:
            result = {
                "models": {},
                "changes_summary": "Failed to parse AI response. Manual review needed.",
                "raw_response": response_text,
            }

        return result

    def _build_generation_prompt(self, schema_diff: dict, existing_models: dict) -> str:
        """Build the prompt for Claude to generate new dbt models."""
        prompt_parts = []

        prompt_parts.append("# SAP S/4HANA Data Model Remediation Task\n")
        prompt_parts.append("## Schema Change Summary")
        prompt_parts.append(f"Old model tables: {schema_diff.get('old_tables', [])}")
        prompt_parts.append(f"New model tables: {schema_diff.get('new_tables', [])}")

        prompt_parts.append("\n## Table Mapping (Old → New)")
        for mapping in schema_diff.get("table_mapping", []):
            prompt_parts.append(f"- {mapping['description']}")

        prompt_parts.append("\n## Detailed Column Mappings")
        for change in schema_diff.get("column_mapping", []):
            prompt_parts.append(
                f"- {change.get('old_table', 'NEW')}.{change.get('old_column', 'N/A')} → "
                f"{change.get('new_table', 'N/A')}.{change.get('new_column', 'N/A')} "
                f"| {change.get('change_type')} | {change.get('mapping_notes', '')}"
            )

        prompt_parts.append("\n## Current dbt Models (to be updated)")
        for path, content in existing_models.items():
            prompt_parts.append(f"\n### File: {path}")
            prompt_parts.append(f"```sql\n{content}\n```")

        prompt_parts.append("""
## Your Task
Generate UPDATED dbt models for the new S/4HANA schema. Specifically:

1. **New staging models** for the new source tables:
   - `stg_acdoca.sql` — replaces stg_bkpf + stg_bseg (since ACDOCA merges headers and line items)
   - `stg_bp.sql` — replaces stg_lfa1 (since BP replaces vendor master)
   - `stg_ska1_s4.sql` — updated from stg_ska1 (extended with new fields)
   - `stg_csks_s4.sql` — updated from stg_csks (extended with new fields)

2. **Updated gold models**:
   - `financial_transactions.sql` — must now source from stg_acdoca instead of stg_bkpf + stg_bseg
   - `financial_master_data.sql` — must now include BP data instead of LFA1

3. **Updated sources.yml** for the new model tables.

4. **Updated schema.yml** for silver and gold layers.

Key requirements:
- Maintain all existing business logic (signed amounts, account type decoding, etc.)
- Add new S/4HANA fields where applicable (ledger, segment, functional area)
- Keep the same Gold table structure so reports don't break (add new columns at the end)
- Use {{ source('new_model', 'TABLE') }} for new model references
- Include clear comments about what changed and why
""")

        return "\n".join(prompt_parts)

    def save_generated_models(self, generated: dict, output_dir: str = None) -> list:
        """Save generated models to the filesystem."""
        if output_dir is None:
            output_dir = self.dbt_path / "models_remediated"
        else:
            output_dir = Path(output_dir)

        output_dir.mkdir(parents=True, exist_ok=True)
        saved_files = []

        for filepath, content in generated.get("models", {}).items():
            full_path = output_dir / filepath
            full_path.parent.mkdir(parents=True, exist_ok=True)
            full_path.write_text(content)
            saved_files.append(str(full_path))
            print(f"  Saved: {full_path}")

        # Save the changes summary
        summary_path = output_dir / "CHANGES_SUMMARY.md"
        summary_path.write_text(generated.get("changes_summary", "No summary available"))
        saved_files.append(str(summary_path))

        return saved_files

    def generate_diff_document(self, existing_models: dict, new_models: dict) -> str:
        """Generate a PR-ready diff document comparing old and new models."""
        lines = [
            "# ETL Pipeline Remediation — Change Document",
            f"## SAP ECC → S/4HANA Migration",
            "",
            "### Files Changed",
        ]

        all_files = set(list(existing_models.keys()) + list(new_models.get("models", {}).keys()))

        for f in sorted(all_files):
            old_content = existing_models.get(f, "")
            new_content = new_models.get("models", {}).get(f, "")

            if not old_content:
                lines.append(f"\n#### 🆕 NEW: `{f}`")
                lines.append("This is a new model created for the S/4HANA schema.")
            elif not new_content:
                lines.append(f"\n#### 🗑️ DEPRECATED: `{f}`")
                lines.append("This model is no longer needed (source table removed).")
            else:
                lines.append(f"\n#### ✏️ MODIFIED: `{f}`")

            lines.append("")

        if new_models.get("changes_summary"):
            lines.append("\n### AI-Generated Change Summary")
            lines.append(new_models["changes_summary"])

        return "\n".join(lines)
