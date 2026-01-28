-- Target Table: Hourly Campaign Metrics
-- Pre-aggregated data for fast dashboard queries

CREATE TABLE hourly_campaign_metrics (
    hour DateTime,
    campaign_id UInt32,
    game_id UInt32,
    placement_type LowCardinality(String),
    
    -- Aggregate states (not final values!)
    impressions AggregateFunction(count, UInt64),
    unique_devices AggregateFunction(uniq, String),
    viewable_impressions AggregateFunction(sum, UInt64),
    clicks AggregateFunction(sum, UInt64),
    revenue AggregateFunction(sum, Decimal64(6))
)
ENGINE = AggregatingMergeTree()
ORDER BY (hour, campaign_id, game_id, placement_type);

-- Data volume after aggregation:
-- • 1000 campaigns × 200 games × 5 placements × 24 hours = 24M rows/day
-- • But most combinations are sparse, actual: ~500K rows/day
-- • 90 days = ~45M rows (vs 6.4B raw events)
-- • Compression ratio: 140:1
