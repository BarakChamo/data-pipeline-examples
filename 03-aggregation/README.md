# Aggregate Combinators

This folder demonstrates ClickHouse's aggregate function combinators, which enable powerful incremental aggregation patterns.

## Files

| File | Topic |
|------|-------|
| `state_merge_example.sql` | -State and -Merge fundamentals |
| `conditional_aggregation.sql` | -If combinator for filtered aggregates |
| `variable_grouping.sql` | Same states, different GROUP BY |
| `multi_step_rollup.sql` | Hourly → daily → monthly pyramid |

## Key Concepts

### The Partial Aggregation Problem

How do you compute COUNT DISTINCT across time periods without double-counting?

```
Hour 1: 50,000 unique devices
Hour 2: 48,000 unique devices
─────────────────────────────
Sum:    98,000 ← WRONG (many devices appear in both hours)
Actual: 75,000 ← CORRECT
```

**Solution**: Store HyperLogLog sketches (states), not final counts. Merge sketches at query time.

### Aggregate Function States

Instead of storing final values, store intermediate computation states:

| Function | State Size | What's Stored |
|----------|------------|---------------|
| `countState()` | 8 bytes | Counter value |
| `sumState()` | 8 bytes | Accumulated sum |
| `uniqState()` | ~12 KB | HyperLogLog registers |
| `uniqHLL12State()` | ~2.5 KB | HyperLogLog 12-bit |
| `quantileTDigestState()` | ~5 KB | T-Digest centroids |

### Combinator Reference

| Combinator | Purpose | Example |
|------------|---------|---------|
| `-State` | Output state for storage | `countState() → blob` |
| `-Merge` | Combine states → final value | `countMerge(state) → UInt64` |
| `-MergeState` | Combine states → new state | `countMergeState(state) → blob` |
| `-If` | Conditional aggregation | `countIf(x > 0)` |
| `-StateIf` | Conditional state creation | `sumStateIf(val, cond)` |
| `-Array` | Apply to array elements | `sumArray([1,2,3]) → 6` |
| `-Map` | Apply to map values | `sumMap(keys, values)` |

### Variable Grouping

Store aggregates at fine granularity, query with different GROUP BY:

```sql
-- Stored: (hour, campaign_id, game_id, placement_type)
-- Query 1: GROUP BY campaign_id (advertiser view)
-- Query 2: GROUP BY game_id (publisher view)
-- Query 3: GROUP BY placement_type (operations view)
```

The `uniqMerge` function produces correct unique counts regardless of grouping because HyperLogLog sketches are mathematically mergeable.

### Multi-Step Rollups

Chain `-MergeState` to build rollup pyramids:

```sql
-- Hourly states
countState() AS impressions

-- Daily: merge hourly states into daily state
countMergeState(impressions) AS impressions

-- Query: merge daily states into final count
countMerge(impressions) AS total_impressions
```

## Gaming Adtech Example

**Pre-aggregate at**: (hour, campaign_id, game_id, placement_type)

**Serve multiple dashboards**:
- Advertiser: CTR, reach, spend by campaign
- Publisher: Fill rate, eCPM, revenue by game
- Operations: Performance by placement type

All from the same pre-aggregated table, with correct unique counts.
