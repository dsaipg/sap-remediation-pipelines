"""
Snowflake Connector — Handles all database interactions for the remediation agent.
Capabilities:
  - Connect to Snowflake
  - Introspect schemas (list tables, columns, types)
  - Compare old vs new schemas
  - Execute DDL in test schemas
  - Deploy approved changes to production
"""

import os
import json
from typing import Optional
import snowflake.connector
from dotenv import load_dotenv

load_dotenv()


class SnowflakeConnector:
    """Manages Snowflake connection and schema operations."""

    def __init__(self):
        self.connection = None
        self.config = {
            "account": os.getenv("SNOWFLAKE_ACCOUNT"),
            "user": os.getenv("SNOWFLAKE_USER"),
            "password": os.getenv("SNOWFLAKE_PASSWORD"),
            "database": os.getenv("SNOWFLAKE_DATABASE", "SAP_REMEDIATION"),
            "warehouse": os.getenv("SNOWFLAKE_WAREHOUSE", "SAP_REMEDIATION_WH"),
            "role": os.getenv("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
        }

    def connect(self):
        """Establish connection to Snowflake."""
        self.connection = snowflake.connector.connect(**self.config)
        print(f"Connected to Snowflake: {self.config['account']}")
        return self.connection

    def close(self):
        """Close Snowflake connection."""
        if self.connection:
            self.connection.close()
            print("Snowflake connection closed.")

    def execute(self, sql: str, fetch: bool = True):
        """Execute SQL and optionally return results."""
        cursor = self.connection.cursor()
        try:
            cursor.execute(sql)
            if fetch:
                columns = [desc[0] for desc in cursor.description] if cursor.description else []
                rows = cursor.fetchall()
                return {"columns": columns, "rows": rows}
            return {"status": "success"}
        finally:
            cursor.close()

    def get_schema_info(self, schema_name: str) -> dict:
        """
        Get complete schema information: all tables with their columns, types, comments.
        Returns a dict keyed by table name.
        """
        sql = f"""
        SELECT
            TABLE_NAME,
            COLUMN_NAME,
            DATA_TYPE,
            CHARACTER_MAXIMUM_LENGTH,
            NUMERIC_PRECISION,
            NUMERIC_SCALE,
            IS_NULLABLE,
            COLUMN_DEFAULT,
            COMMENT
        FROM {self.config['database']}.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = '{schema_name.upper()}'
        ORDER BY TABLE_NAME, ORDINAL_POSITION
        """
        result = self.execute(sql)
        schema = {}
        for row in result["rows"]:
            table_name = row[0]
            if table_name not in schema:
                schema[table_name] = {"columns": []}
            schema[table_name]["columns"].append({
                "name": row[1],
                "data_type": row[2],
                "max_length": row[3],
                "precision": row[4],
                "scale": row[5],
                "nullable": row[6],
                "default": row[7],
                "comment": row[8],
            })
        return schema

    def get_table_columns(self, schema_name: str, table_name: str) -> list:
        """Get columns for a specific table."""
        schema = self.get_schema_info(schema_name)
        return schema.get(table_name, {}).get("columns", [])

    def get_row_count(self, schema_name: str, table_name: str) -> int:
        """Get row count for a table."""
        sql = f"SELECT COUNT(*) FROM {self.config['database']}.{schema_name}.{table_name}"
        result = self.execute(sql)
        return result["rows"][0][0]

    def get_sample_data(self, schema_name: str, table_name: str, limit: int = 5) -> dict:
        """Get sample rows from a table."""
        sql = f"SELECT * FROM {self.config['database']}.{schema_name}.{table_name} LIMIT {limit}"
        return self.execute(sql)

    def create_test_schema(self, schema_name: str = "TEST_REMEDIATION"):
        """Create or recreate the test schema for agent work."""
        self.execute(f"CREATE SCHEMA IF NOT EXISTS {self.config['database']}.{schema_name}", fetch=False)
        print(f"Test schema ready: {schema_name}")

    def deploy_to_schema(self, ddl_statements: list, target_schema: str):
        """Execute a list of DDL statements against a target schema."""
        self.execute(f"USE SCHEMA {self.config['database']}.{target_schema}", fetch=False)
        results = []
        for ddl in ddl_statements:
            try:
                self.execute(ddl, fetch=False)
                results.append({"sql": ddl[:80] + "...", "status": "success"})
            except Exception as e:
                results.append({"sql": ddl[:80] + "...", "status": "error", "error": str(e)})
        return results

    def compare_schemas(self, old_schema: str, new_schema: str) -> dict:
        """
        Compare two schemas and return differences.
        This is the CORE function the agent uses to understand what changed.
        """
        old = self.get_schema_info(old_schema)
        new = self.get_schema_info(new_schema)

        diff = {
            "tables_removed": [],
            "tables_added": [],
            "tables_modified": [],
            "column_changes": [],
            "summary": {}
        }

        old_tables = set(old.keys())
        new_tables = set(new.keys())

        # Tables only in old
        diff["tables_removed"] = sorted(old_tables - new_tables)

        # Tables only in new
        diff["tables_added"] = sorted(new_tables - old_tables)

        # Tables in both — compare columns
        for table in sorted(old_tables & new_tables):
            old_cols = {c["name"]: c for c in old[table]["columns"]}
            new_cols = {c["name"]: c for c in new[table]["columns"]}

            old_col_names = set(old_cols.keys())
            new_col_names = set(new_cols.keys())

            removed_cols = old_col_names - new_col_names
            added_cols = new_col_names - old_col_names

            # Check for type changes in common columns
            type_changes = []
            for col in old_col_names & new_col_names:
                if old_cols[col]["data_type"] != new_cols[col]["data_type"]:
                    type_changes.append({
                        "column": col,
                        "old_type": old_cols[col]["data_type"],
                        "new_type": new_cols[col]["data_type"],
                    })

            if removed_cols or added_cols or type_changes:
                diff["tables_modified"].append(table)
                diff["column_changes"].append({
                    "table": table,
                    "columns_removed": sorted(removed_cols),
                    "columns_added": sorted(added_cols),
                    "type_changes": type_changes,
                })

        diff["summary"] = {
            "tables_removed": len(diff["tables_removed"]),
            "tables_added": len(diff["tables_added"]),
            "tables_modified": len(diff["tables_modified"]),
            "total_column_changes": sum(
                len(c["columns_removed"]) + len(c["columns_added"]) + len(c["type_changes"])
                for c in diff["column_changes"]
            ),
        }

        return diff


def test_connection():
    """Quick connectivity test."""
    sf = SnowflakeConnector()
    try:
        sf.connect()
        result = sf.execute("SELECT CURRENT_TIMESTAMP() AS ts, CURRENT_DATABASE() AS db")
        print(f"  Timestamp: {result['rows'][0][0]}")
        print(f"  Database:  {result['rows'][0][1]}")

        # Show schemas
        schemas = sf.get_schema_info("BRONZE")
        print(f"\n  Bronze tables found: {list(schemas.keys())}")
        for table, info in schemas.items():
            count = sf.get_row_count("BRONZE", table)
            print(f"    {table}: {len(info['columns'])} columns, {count} rows")

        print("\n  Connection test PASSED!")
    except Exception as e:
        print(f"  Connection test FAILED: {e}")
    finally:
        sf.close()


if __name__ == "__main__":
    test_connection()
