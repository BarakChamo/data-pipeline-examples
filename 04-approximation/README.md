# Approximation Functions

This folder demonstrates when and how to use approximate aggregation functions for better performance and memory efficiency.

## Files

| File | Topic |
|------|-------|
| `unique_counts_comparison.sql` | uniq vs uniqExact vs uniqHLL12 |
| `percentile_calculation.sql` | quantileTDigest vs quantileExact |
| `memory_usage_demo.sql` | Why fixed-size states matter at scale |

## Key Concepts

### When Approximation Makes Sense

In adtech, many metrics are acceptable with small error margins:

| Metric | Exact Value | Approximate | Acceptable? |
|--------|-------------|-------------|-------------|
| Campaign reach | 12,345,678 | ~12.3M | ✓ Dashboard |
| Response time p95 | 147.23ms | ~147ms | ✓ Monitoring |
| Unique devices/day | 8,234,521 | ~8.2M | ✓ Trends |
| Billable impressions | 45,678,234 | N/A | ✗ Use exact |

**Rule of thumb**: Use approximate by default. Switch to exact only for billing/financial reconciliation.

### Unique Count Functions

| Function | Algorithm | Error | Memory | Use Case |
|----------|-----------|-------|--------|----------|
| `uniqExact` | Hash set | 0% | O(n) | Billing |
| `uniq` | HyperLogLog++ | ~2% | 12 KB | Dashboards |
| `uniqHLL12` | HyperLogLog 12-bit | ~1.6% | 2.5 KB | High-volume storage |
| `uniqCombined` | Adaptive | ~2% | Variable | Mixed cardinality |

### Memory Impact at Scale

Storing unique device counts for 1M campaign-hours:

| Function | Memory per State | Total (1M states) |
|----------|-----------------|-------------------|
| `uniqExact` (10K uniques) | ~800 KB | ~800 GB (OOM!) |
| `uniq` | 12 KB | 12 GB |
| `uniqHLL12` | 2.5 KB | 2.5 GB |

Fixed-size states make approximate functions dramatically more scalable.

### Percentile Functions

| Function | Algorithm | Error | Memory | Use Case |
|----------|-----------|-------|--------|----------|
| `quantileExact` | Full sort | 0% | O(n) | Small datasets |
| `quantileTDigest` | T-Digest | ~1% | ~5 KB | Latency monitoring |
| `quantileTiming` | Histogram | ~1% | Fixed | Response times <30s |

### Practical Usage

```sql
SELECT
    campaign_id,
    
    -- For dashboard (fast, good enough)
    uniq(device_id) AS dashboard_reach,
    
    -- For billing (exact, slower)
    uniqExact(device_id) AS billing_reach,
    
    -- Latency monitoring (approximate)
    quantileTDigest(0.95)(response_ms) AS p95_latency

FROM ad_events
GROUP BY campaign_id;
```

### Pre-Aggregation with Approximate States

```sql
-- Store T-Digest states per hour
latency_p95 AggregateFunction(quantileTDigest(0.95), UInt32)

-- Query: merge states across time range
quantileTDigestMerge(0.95)(latency_p95) AS p95_ms
```

## Gaming Adtech Example

| Metric | Function | Why |
|--------|----------|-----|
| Unique reach | `uniq` | "~12M users" is fine for dashboards |
| Frequency | `uniq` | Approximate per-device counts acceptable |
| Billable impressions | `count` (exact) | Financial reconciliation |
| API latency p99 | `quantileTDigest` | SLA monitoring, ~1% error OK |
