# Tinybird Configuration

This folder contains Tinybird configuration files that demonstrate code-as-infrastructure for ClickHouse.

## Structure

```
05-tinybird/
├── datasources/
│   ├── ad_events.datasource          # Raw event schema
│   └── hourly_campaign_metrics.datasource  # Aggregated metrics schema
├── pipes/
│   ├── mv_hourly_rollup.pipe         # Materialized view
│   ├── api_campaign_dashboard.pipe   # REST API endpoint
│   └── api_publisher_revenue.pipe    # REST API endpoint
└── README.md
```

## Key Concepts

### What is Tinybird?

Tinybird is a managed ClickHouse service with developer-friendly tooling:

- **Declarative schemas**: Define tables in version-controlled files
- **SQL pipelines**: Materialized views and transformations as code
- **Instant APIs**: SQL queries become REST endpoints
- **Git-based CI/CD**: Deploy with `tb push`

### Datasource Files

Define table schema and ClickHouse engine settings:

```
SCHEMA >
    `event_id` UUID `json:$.event_id`,
    `event_time` DateTime64(3) `json:$.timestamp`,
    `campaign_id` UInt32 `json:$.campaign.id`

ENGINE MergeTree
ENGINE_SORTING_KEY game_id, campaign_id, toStartOfHour(event_time)
ENGINE_TTL event_time + INTERVAL 90 DAY DELETE
```

- `SCHEMA` defines columns with optional JSONPath for ingestion
- `ENGINE` maps to ClickHouse table engine
- `ENGINE_SORTING_KEY` maps to `ORDER BY`
- `ENGINE_TTL` for automatic data expiration

### Pipe Files

Define transformations, MVs, or API endpoints:

**Materialized View:**
```
NODE hourly_aggregation
SQL >
    SELECT toStartOfHour(event_time) AS hour, ...
    FROM ad_events
    GROUP BY hour, campaign_id

TYPE MATERIALIZED
DATASOURCE hourly_campaign_metrics
```

**API Endpoint:**
```
NODE campaign_metrics
SQL >
    SELECT campaign_id, countMerge(impressions) AS impressions
    FROM hourly_campaign_metrics
    WHERE campaign_id = {{ UInt32(campaign_id) }}
    GROUP BY campaign_id

TYPE ENDPOINT
```

### Templating Syntax

Tinybird pipes support parameterized queries:

| Syntax | Purpose |
|--------|---------|
| `{{ UInt32(param) }}` | URL parameter with type casting |
| `{{ UInt32(param, 100) }}` | Default value if not provided |
| `{% if defined(param) %}` | Conditional SQL |
| `{% end %}` | End conditional block |

### Deployment Workflow

```bash
# Validate without deploying
tb push --dry-run

# Deploy to Tinybird
tb push

# Push specific file
tb push datasources/ad_events.datasource

# Query an endpoint locally
tb pipe data api_campaign_dashboard --campaign_id=123
```

### CI/CD Integration

Typical workflow:

1. Developer creates PR with schema/query changes
2. CI runs `tb push --dry-run` to validate
3. Team reviews SQL changes like application code
4. Merge triggers `tb push` to deploy

Benefits:
- Version history for all changes
- Code review for data pipelines
- Rollback via git revert
- Reproducible environments

## Gaming Adtech Example

| File | Purpose |
|------|---------|
| `ad_events.datasource` | Raw event landing zone (500M events/week) |
| `hourly_campaign_metrics.datasource` | Pre-aggregated metrics table |
| `mv_hourly_rollup.pipe` | Automatic aggregation on INSERT |
| `api_campaign_dashboard.pipe` | Advertiser dashboard API |
| `api_publisher_revenue.pipe` | Publisher revenue API |

The entire data pipeline is defined in these 5 files, version-controlled, and deployable with a single command.
