# Simple Pipeline: Events → Hourly Metrics

A single-step materialized view that aggregates raw events into hourly campaign metrics.

## Files

| File | Description |
|------|-------------|
| `events_table.sql` | Source table for raw ad events |
| `hourly_aggregates_table.sql` | Target table with AggregateFunction columns |
| `hourly_mv.sql` | Materialized view connecting source to target |

## Data Flow

```
ad_events (MergeTree)
    │
    │  INSERT 10,000 events
    ▼
mv_hourly_campaign (MV)
    │
    │  SELECT with -State functions
    │  GROUP BY hour, campaign_id, game_id, placement_type
    ▼
hourly_campaign_metrics (AggregatingMergeTree)
    │
    │  ~100 aggregated rows
    ▼
Dashboard query with -Merge functions
```

## Key Points

1. **Source table** uses MergeTree for raw event storage
2. **Target table** uses AggregatingMergeTree with `AggregateFunction` columns
3. **MV** uses `-State` functions to create aggregate states
4. **Queries** use `-Merge` functions to finalize the states

## Example Query

```sql
SELECT
    campaign_id,
    countMerge(impressions) AS impressions,
    uniqMerge(unique_devices) AS unique_reach,
    sumMerge(revenue) AS revenue
FROM hourly_campaign_metrics
WHERE hour >= now() - INTERVAL 7 DAY
GROUP BY campaign_id;
```

This query scans ~170K rows (7 days × 24 hours × ~1000 active campaigns) instead of ~500M raw events.
