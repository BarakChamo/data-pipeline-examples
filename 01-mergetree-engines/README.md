# MergeTree Engine Family

This folder contains examples of different MergeTree engine variants, each optimized for specific use cases.

## Files

| File | Engine | Use Case |
|------|--------|----------|
| `raw_events_mergetree.sql` | MergeTree | Immutable event logs |
| `device_profiles_replacing.sql` | ReplacingMergeTree | Latest state per entity |
| `daily_totals_summing.sql` | SummingMergeTree | Automatic counter rollups |
| `hourly_metrics_aggregating.sql` | AggregatingMergeTree | Complex pre-aggregation |
| `event_corrections_collapsing.sql` | CollapsingMergeTree | Row updates via cancellation |

## Key Concepts

### MergeTree (Base Engine)

The foundation of ClickHouse storage. Data is:
1. Written as immutable "parts" sorted by `ORDER BY` columns
2. Indexed with a sparse primary index (1 entry per ~8192 rows)
3. Merged in the background to reduce part count

```sql
ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_time)
ORDER BY (game_id, campaign_id, toStartOfHour(event_time))
```

**Use when**: You need every row preserved (event logs, audit trails).

### ReplacingMergeTree

Keeps only the latest version of each row (by `ORDER BY` key) after background merges.

```sql
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY device_id
```

**Use when**: You want "upsert" semantics without explicit UPDATE statements. Good for dimension tables, device profiles, configuration state.

**Caveat**: Use `FINAL` keyword or `GROUP BY` with `argMax` to get accurate results before merge completes.

### SummingMergeTree

Automatically sums numeric columns for rows with the same `ORDER BY` key during merge.

```sql
ENGINE = SummingMergeTree()
ORDER BY (date, campaign_id)
```

**Use when**: You only need simple counters (impressions, clicks, revenue totals). Queries don't need special `-Merge` functions.

**Limitation**: Only supports SUM. Cannot do COUNT DISTINCT, AVG, percentiles.

### AggregatingMergeTree

Stores aggregate function states (binary blobs) that can be merged at query time.

```sql
ENGINE = AggregatingMergeTree()
ORDER BY (hour, campaign_id)

-- Column stores HyperLogLog sketch, not a number
unique_devices AggregateFunction(uniq, String)
```

**Use when**: You need complex aggregations like COUNT DISTINCT, percentiles, or want to re-aggregate with different GROUP BY clauses.

**Requires**: `-State` functions for INSERT, `-Merge` functions for SELECT.

### CollapsingMergeTree

Supports row "cancellation" by inserting a row with `sign = -1` to negate a previous row.

```sql
ENGINE = CollapsingMergeTree(sign)
ORDER BY (entity_id, version)
```

**Use when**: You need true update/delete semantics, or you're processing CDC streams with before/after images.

## Decision Guide

```
Need every row?
  → Yes: MergeTree

Need latest state only?
  → Yes: ReplacingMergeTree

Only simple counters (SUM)?
  → Yes: SummingMergeTree

Complex aggregates (COUNT DISTINCT, percentiles)?
  → Yes: AggregatingMergeTree

Need to "undo" previous rows?
  → Yes: CollapsingMergeTree
```

## Gaming Adtech Examples

| Engine | Example Table | Why |
|--------|--------------|-----|
| MergeTree | `ad_events` | Every impression/click must be preserved |
| ReplacingMergeTree | `device_profiles` | Only need current consent, location, frequency caps |
| SummingMergeTree | `daily_campaign_totals` | Simple counts, no unique metrics needed |
| AggregatingMergeTree | `hourly_campaign_metrics` | Need unique reach (HLL), percentile latencies |
