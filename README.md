# local_duckdb_project

A dbt Fusion project that reads from a Fivetran-managed Apache Iceberg lakehouse on S3 and materializes models into a local DuckDB database.

## Architecture

```
Fivetran Lakehouse (S3 / Apache Iceberg)
        │
        │  DuckDB httpfs + iceberg extensions
        │  ATTACH via Polaris REST catalog
        ▼
  dbt Fusion (local)
        │
        │  Reads from fivetran_lakehouse.*
        │  Writes to dev.duckdb
        ▼
  dev.duckdb (local materialization)
```

**Key insight:** DuckDB reads source data from Iceberg tables in S3 via the attached Polaris catalog. dbt then materializes the transformed models locally into `dev.duckdb`. The lakehouse is read-only from this project's perspective.

## Stack

| Component | Details |
|---|---|
| dbt engine | dbt Fusion 2.0.0-preview.190 |
| Local warehouse | DuckDB (via `dev.duckdb`) |
| Source data | Fivetran MDLS — Apache Iceberg on S3 (us-west-2) |
| Catalog | Fivetran Polaris REST catalog |
| DuckDB extensions | `httpfs`, `iceberg` |

## Setup

### Prerequisites

- dbt Fusion installed (`~/.local/bin/dbt`)
- DuckDB persistent secret `polaris_secret` configured in `~/.duckdb/stored_secrets/`

The persistent secret stores OAuth2 credentials for the Polaris catalog. Create it once with:

```sql
INSTALL httpfs FROM core; LOAD httpfs;
INSTALL iceberg FROM core; LOAD iceberg;
CREATE OR REPLACE PERSISTENT SECRET polaris_secret (
    TYPE iceberg,
    CLIENT_ID '<polaris_client_id>',
    CLIENT_SECRET '<polaris_client_secret>',
    OAUTH2_SCOPE 'PRINCIPAL_ROLE:ALL',
    OAUTH2_SERVER_URI '<polaris_oauth_uri>'
);
```

### Running the project

```bash
cd local_duckdb_project

# Install packages
dbt deps

# Run all models
dbt run

# Run a specific package
dbt run --select fivetran_log
```

## How Iceberg sources are wired

DuckDB's `httpfs` and `iceberg` extensions are loaded on every run via `on-run-start` hooks in `dbt_project.yml`, which also ATTACH the Polaris catalog:

```sql
ATTACH 'boarding_debating' AS fivetran_lakehouse (
    TYPE ICEBERG,
    ENDPOINT 'https://handle-snub.us-east-1.aws.polaris.fivetran.com/api/catalog',
    SECRET polaris_secret,
    DEFAULT_REGION 'us-west-2'
);
```

After the ATTACH, all Iceberg tables are referenceable as `fivetran_lakehouse.<namespace>.<table>` in model SQL. The dbt package vars point source lookups at the attached catalog:

```yaml
vars:
  fivetran_platform_database: fivetran_lakehouse
  fivetran_platform_schema: fivetran_log
```

## Packages

### `fivetran/fivetran_log` ✅

Fivetran's prebuilt dbt package for monitoring your Fivetran platform — connector sync status, MAR usage, audit logs, schema changelogs, and user activity.

**Lakehouse namespace:** `fivetran_lakehouse.fivetran_log`

**Key models:**
- `fivetran_platform__connection_status` — sync health per connector
- `fivetran_platform__mar_table_history` — Monthly Active Row usage over time
- `fivetran_platform__audit_table` — record-level sync audit trail
- `fivetran_platform__connection_daily_events` — daily sync event counts
- `fivetran_platform__usage_history` — credit and MAR usage history
- `fivetran_platform__audit_user_activity` — user actions in the Fivetran platform

**Config note:** `destination_membership` is not present in this lakehouse (Fivetran uses `resource_membership` in newer versions). Disabled via `fivetran_platform_using_destination_membership: false`.

### `fivetran/github` ⚠️ Not compatible

The `fivetran/github` package expects issues, pull requests, labels, and team tables from Fivetran's GitHub connector. The GitHub namespace in this lakehouse contains commit, traffic, and repository data instead — a different table profile. The package was installed but produces empty models.

**Lakehouse namespace:** `fivetran_lakehouse.github`

**Tables available:** `commit`, `commit_file`, `commit_parent`, `branch_commit_relation`, `repository`, `repository_clone`, `repository_language`, `page_view`, `user`, `repo_collaborator`

Custom models against this data would need to be written from scratch.

## Findings & Notes

**`adapter.get_relation()` works with attached Iceberg catalogs.** dbt Fusion's DuckDB adapter can resolve relations from the attached Polaris catalog — evidenced by the `fivetran_log` package successfully finding all its source tables. Standard Fivetran dbt packages work out of the box against Iceberg sources, as long as the expected tables are present.

**Variable names changed in `fivetran/fivetran_log`.** The package was renamed from `fivetran_log` to `fivetran_platform` internally. The correct vars are `fivetran_platform_database` and `fivetran_platform_schema` (not `fivetran_log_*`).

**`DEFAULT_REGION` must match the S3 bucket region, not the Polaris endpoint region.** The Polaris endpoint URL contains `us-east-1`, but the S3 data bucket is in `us-west-2`. Using the wrong region causes queries to hang. Always set `DEFAULT_REGION` from the bucket location.

**dbt Fusion static analysis warnings are noise at baseline tier.** Without a dbt Cloud login, Fusion runs static analysis in baseline mode and emits `BaselineIntrospectionSyntaxInvalid` warnings for any model using Jinja macros. These are safe to ignore — all models compile and run correctly.
