-- Layer 1: Hourly Aggregates
CREATE TABLE metrics_hourly (
    hour DateTime,
    campaign_id UInt32,
    game_id UInt32,
    
    impressions AggregateFunction(count, UInt64),
    unique_devices AggregateFunction(uniq, String),
    revenue AggregateFunction(sum, Decimal64(6))
)
ENGINE = AggregatingMergeTree()
ORDER BY (hour, campaign_id, game_id);
