-- AggregatingMergeTree: Store Any Aggregation State
-- Use case: Complex pre-computed metrics with COUNT DISTINCT, percentiles, etc.

CREATE TABLE hourly_campaign_metrics (
    hour DateTime,
    campaign_id UInt32,
    game_id UInt32,
    placement_type LowCardinality(String),
    
    -- Aggregate states (binary blobs, not final values)
    impressions AggregateFunction(count, UInt64),
    unique_devices AggregateFunction(uniq, String),
    clicks AggregateFunction(sum, UInt64),
    revenue AggregateFunction(sum, Decimal64(6)),
    view_duration_p50 AggregateFunction(quantileTDigest(0.5), UInt32),
    view_duration_p95 AggregateFunction(quantileTDigest(0.95), UInt32)
)
ENGINE = AggregatingMergeTree()
ORDER BY (hour, campaign_id, game_id, placement_type);

-- Populate via Materialized View (see mv_hourly_rollup.sql)
-- Or direct INSERT with -State functions:
INSERT INTO hourly_campaign_metrics
SELECT
    toStartOfHour(event_time) AS hour,
    campaign_id,
    game_id,
    placement_type,
    countState() AS impressions,
    uniqState(device_id) AS unique_devices,
    sumState(toUInt64(event_type = 'click')) AS clicks,
    sumState(revenue) AS revenue,
    quantileTDigestState(0.5)(view_duration_ms) AS view_duration_p50,
    quantileTDigestState(0.95)(view_duration_ms) AS view_duration_p95
FROM ad_events
WHERE event_type = 'impression'
GROUP BY hour, campaign_id, game_id, placement_type;

-- Query with -Merge functions to finalize:
SELECT
    hour,
    campaign_id,
    countMerge(impressions) AS impressions,
    uniqMerge(unique_devices) AS unique_reach,
    sumMerge(clicks) AS clicks,
    sumMerge(revenue) AS revenue,
    quantileTDigestMerge(0.5)(view_duration_p50) AS p50_view_ms,
    quantileTDigestMerge(0.95)(view_duration_p95) AS p95_view_ms
FROM hourly_campaign_metrics
WHERE hour >= now() - INTERVAL 7 DAY
GROUP BY hour, campaign_id;

-- Why AggregatingMergeTree for hourly metrics?
-- ✓ Store ANY aggregation (count distinct, percentiles, etc.)
-- ✓ States can be re-aggregated at query time
-- ✓ Foundation for rollup pyramids (hourly → daily → monthly)
-- ✓ Enables "variable grouping" (same data, different GROUP BY)
-- ✗ More complex than SummingMergeTree
-- ✗ Requires -State/-Merge function pairs
-- ✗ States are opaque binary blobs (not human-readable)
