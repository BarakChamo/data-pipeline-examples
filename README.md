# ClickHouse & Tinybird Examples for Gaming Adtech

This repository contains practical SQL and Tinybird configuration examples for building a real-time data platform for gaming adtech. These examples accompany a technical presentation on scaling analytics with ClickHouse.

## What's Inside

| Folder | Topic | Description |
|--------|-------|-------------|
| `01-mergetree-engines/` | MergeTree Engine Family | Choosing the right engine for each use case |
| `02-materialized-views/` | Materialized Views | INSERT trigger pipelines for real-time aggregation |
| `03-aggregation/` | Aggregate Combinators | States, -Merge, -If, and multi-step rollups |
| `04-approximation/` | Approximate Functions | HyperLogLog, T-Digest, and memory tradeoffs |
| `05-tinybird/` | Tinybird Configuration | Code-as-infrastructure for ClickHouse |

## Gaming Adtech Context

These examples model a gaming advertising platform similar to in-game ad networks. The data model includes:

- **Events**: Impressions, clicks, video views, viewability signals
- **Dimensions**: Campaigns, advertisers, games, publishers, placements, devices
- **Metrics**: CTR, viewability rate, unique reach, revenue, eCPM

### Scale Assumptions

- 500M+ impressions per week
- 200+ game integrations
- <50ms p99 dashboard query latency
- 90-day raw event retention

## Key Concepts

### 1. Column-Oriented Storage
ClickHouse stores data by column, not by row. This enables:
- Reading only the columns needed for a query
- 50-100x compression on repetitive values
- Vectorized execution (SIMD) on column batches

### 2. MergeTree Engines
Choose the right engine for your data:
- `MergeTree` — Raw events, append-only logs
- `ReplacingMergeTree` — Latest state per key (device profiles)
- `SummingMergeTree` — Automatic counter rollups
- `AggregatingMergeTree` — Complex pre-aggregation with states

### 3. Materialized Views as INSERT Triggers
Unlike Postgres MVs (snapshots that need REFRESH), ClickHouse MVs:
- Run on every INSERT to the source table
- Process only the new rows incrementally
- Are always up-to-date within the same transaction

### 4. Aggregate States
Store intermediate computation results, not final values:
```sql
-- Store state (binary blob)
countState() AS impressions

-- Merge states at query time
countMerge(impressions) AS total_impressions
```

This enables:
- Re-aggregation with different GROUP BY clauses
- Multi-step rollups (hourly → daily → monthly)
- Mathematically correct unique counts across time periods

### 5. Approximation for Scale
Trade precision for memory and speed:
- `uniq()` — HyperLogLog, ~2% error, fixed 12KB per state
- `uniqExact()` — Hash set, 0% error, unbounded memory
- Use approximate by default; exact only for billing

## Running the Examples

These examples are designed to be run against a ClickHouse instance. You can:

1. **Local ClickHouse**: `clickhouse-client < filename.sql`
2. **ClickHouse Cloud**: Copy/paste into the SQL console
3. **Tinybird**: Use `tb push` for the Tinybird config files

## Related Resources

- [ClickHouse Documentation](https://clickhouse.com/docs)
- [Tinybird Documentation](https://tinybird.co/docs)
- [MergeTree Engine Family](https://clickhouse.com/docs/en/engines/table-engines/mergetree-family)
- [Aggregate Function Combinators](https://clickhouse.com/docs/en/sql-reference/aggregate-functions/combinators)
- [Web Analytics Starter Kit](https://github.com/tinybirdco/web-analytics-starter-kit/tree/9e04882f4f6f2e7f2d973879ff85eaa28f4e28bb)
- [Logs Explorer Starter Kit](https://github.com/tinybirdco/logs-explorer-template)
