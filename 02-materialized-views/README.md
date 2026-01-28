# Materialized Views

This folder contains examples of ClickHouse materialized views, which work fundamentally differently from Postgres MVs.

## Folders

| Folder | Description |
|--------|-------------|
| `01-simple-pipeline/` | Single-step aggregation (events → hourly metrics) |
| `02-multi-step-pipeline/` | Cascading MVs (events → hourly → daily) |

## Key Concepts

### ClickHouse MVs Are INSERT Triggers

Unlike Postgres MVs (which are cached query snapshots), ClickHouse MVs:

1. **Trigger on INSERT** to the source table
2. **Process only new rows** (not the entire table)
3. **Insert results** into a target table
4. **Are always current** (within the same transaction)

```sql
CREATE MATERIALIZED VIEW mv_hourly
TO hourly_metrics          -- Target table
AS
SELECT
    toStartOfHour(event_time) AS hour,
    campaign_id,
    countState() AS impressions
FROM ad_events             -- Source table
GROUP BY hour, campaign_id;
```

### What Happens on INSERT

```
INSERT 10,000 rows into ad_events
    ↓
MV SELECT runs against those 10,000 rows only
    ↓
~100 aggregated rows INSERT into hourly_metrics
    ↓
Both INSERTs committed atomically
```

### Cost Model

| Aspect | Without MVs | With MVs |
|--------|-------------|----------|
| Write cost | O(1) per event | O(k) per event (k = MV count) |
| Query cost | O(n) scan raw data | O(1) scan aggregates |
| Dashboard latency | 30+ seconds | <50ms |
| Storage | 1× (raw only) | ~1.1× (raw + aggregates) |

### Multi-Step Pipelines

MVs can cascade: inserting into one table triggers MVs that insert into another.

```
ad_events (raw)
    ↓ MV1: hourly aggregation
hourly_metrics
    ↓ MV2: daily rollup
daily_metrics
    ↓ MV3: monthly rollup
monthly_metrics
```

All three aggregations happen within a single INSERT transaction. No cron jobs, no ETL orchestration.

### When to Use MVs

**Good fit:**
- Dashboard queries with known patterns
- Real-time aggregation requirements
- Predictable latency SLAs

**Keep raw data for:**
- Ad-hoc exploration
- Debugging specific events
- Requirements you haven't anticipated

ClickHouse is fast enough that you can often query raw data directly for exploration, while MVs serve production dashboards.

## Gaming Adtech Example

**Source**: `ad_events` — 500M events/week, 40+ columns

**Target**: `hourly_campaign_metrics` — ~500K rows/day after aggregation

**Compression**: 140:1 row reduction, queries go from 30+ seconds to <50ms
