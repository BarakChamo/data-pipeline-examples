-- Memory Usage Comparison: Why Approximation Matters at Scale
-- Demonstrating the storage impact of exact vs approximate aggregates

-- Scenario: Store unique device counts for:
-- • 1,000 campaigns
-- • 200 games
-- • 5 placement types
-- • Hourly granularity for 90 days
-- Total combinations: 1000 × 200 × 5 × 24 × 90 = 2.16 billion rows

-- But wait - we use AggregatingMergeTree, so we're storing states
-- Let's compare state sizes:

-- uniqExact state size depends on actual unique count
-- For 10K uniques per cell: ~800KB per state
-- Total: 2.16B × 800KB = 1.7 PB (impossible!)

-- uniq (HyperLogLog) state size is FIXED at 12KB
-- Total: 2.16B × 12KB = 25TB (still large, but we aggregate)

-- In reality, we aggregate to (hour, campaign_id, game_id, placement_type)
-- That's only: 24 × 90 × 1000 × 200 × 5 = 2.16B... wait, same thing

-- Let's be more realistic - aggregate at (hour, campaign_id, game_id)
-- Rows: 24 × 90 × 1000 × 200 = 432M rows
-- With uniq states: 432M × 12KB = 5.2TB
-- With uniqHLL12: 432M × 2.5KB = 1.1TB

-- Further aggregation to (date, campaign_id)
-- Rows: 90 × 1000 = 90,000 rows
-- With uniq states: 90K × 12KB = 1.1GB
-- With uniqHLL12: 90K × 2.5KB = 225MB

-- The pattern is clear:
-- 1. Approximate functions have FIXED state sizes
-- 2. Exact functions have VARIABLE state sizes (proportional to cardinality)
-- 3. At scale, fixed wins dramatically

-- Memory during query execution:
SELECT
    campaign_id,
    -- Exact: allocates hash set for each campaign (varies)
    uniqExact(device_id) AS exact_uniques,
    -- Approximate: allocates fixed 12KB buffer per campaign
    uniq(device_id) AS approx_uniques
FROM ad_events
GROUP BY campaign_id;

-- With 1000 campaigns and 1M devices each:
-- uniqExact: ~800GB memory (likely OOM)
-- uniq: ~12MB memory (no problem)
