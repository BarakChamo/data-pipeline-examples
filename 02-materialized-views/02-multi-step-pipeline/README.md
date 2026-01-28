# Multi-Step Pipeline: Events → Hourly → Daily

Cascading materialized views that create a rollup pyramid for efficient time-range queries.

## Files

| File | Description |
|------|-------------|
| `events_table.sql` | Source table for raw ad events |
| `hourly_table.sql` | First aggregation layer (hourly granularity) |
| `hourly_mv.sql` | MV: events → hourly |
| `daily_table.sql` | Second aggregation layer (daily granularity) |
| `daily_mv.sql` | MV: hourly → daily |

## Data Flow

```
ad_events
    │ MV1: toStartOfHour(), countState(), uniqState()
    ▼
metrics_hourly
    │ MV2: toDate(), countMergeState(), uniqMergeState()
    ▼
metrics_daily
```

When you INSERT into `ad_events`:
1. `mv_hourly` triggers, aggregating to hourly granularity
2. INSERT into `metrics_hourly` triggers `mv_daily`
3. `mv_daily` aggregates hourly states into daily states
4. All three INSERTs happen in one atomic transaction

## Key Technique: -MergeState

When rolling up from hourly to daily, use `-MergeState` (not `-Merge`):

```sql
-- Combines hourly HLL sketches, outputs new HLL sketch for daily
uniqMergeState(unique_devices) AS unique_devices
```

This preserves the aggregate state for further rollup or flexible querying.

## Query Routing by Time Range

| Query Range | Table | Rows Scanned |
|-------------|-------|--------------|
| Last 24 hours | `metrics_hourly` | ~24K |
| Last 7 days | `metrics_daily` | ~7K |
| Last 90 days | `metrics_daily` | ~90K |
| Last 12 months | `metrics_monthly`* | ~12K |

*Monthly layer can be added with the same pattern.

## Why This Matters

For a dashboard showing "last 30 days by campaign":
- **Without rollups**: Scan 30 days × 500M events/week ≈ 2B+ rows
- **With daily rollup**: Scan 30 × 1000 campaigns = 30K rows

Same data, same accuracy, 60,000× fewer rows scanned.
