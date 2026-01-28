-- SummingMergeTree: Automatic Counter Aggregation
-- Use case: Simple additive metrics without complex states

CREATE TABLE daily_impression_counts (
    date Date,
    campaign_id UInt32,
    game_id UInt32,
    placement_type LowCardinality(String),
    
    -- Simple counters (will be summed on merge)
    impressions UInt64,
    clicks UInt64,
    video_starts UInt64,
    video_completes UInt64,
    
    -- Revenue (also summable)
    revenue Decimal64(6),
    cost Decimal64(6)
)
ENGINE = SummingMergeTree()
ORDER BY (date, campaign_id, game_id, placement_type);

-- How it works:
-- 1. INSERT multiple rows with same (date, campaign_id, game_id, placement_type)
-- 2. During background merge, ClickHouse automatically SUMs numeric columns
-- 3. Result: one row per unique ORDER BY combination

-- Example: Two batches of events arrive
INSERT INTO daily_impression_counts VALUES
    ('2024-06-15', 123, 456, 'interstitial', 1000, 50, 800, 600, 100.00, 80.00);
    
INSERT INTO daily_impression_counts VALUES
    ('2024-06-15', 123, 456, 'interstitial', 500, 25, 400, 300, 50.00, 40.00);

-- After merge, becomes single row:
-- ('2024-06-15', 123, 456, 'interstitial', 1500, 75, 1200, 900, 150.00, 120.00)

-- Why SummingMergeTree for daily counters?
-- ✓ Simple mental model (just INSERT, sums happen automatically)
-- ✓ No AggregateFunction columns needed
-- ✓ Can query without -Merge functions
-- ✓ Great for "counter" style metrics
-- ✗ Only works for SUM aggregation
-- ✗ Can't do COUNT DISTINCT, AVG, percentiles
-- ✗ Use AggregatingMergeTree for complex aggregations
