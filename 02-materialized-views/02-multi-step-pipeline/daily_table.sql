-- Layer 2: Daily Aggregates (rolled up from hourly)
CREATE TABLE metrics_daily (
    date Date,
    campaign_id UInt32,
    game_id UInt32,
    
    impressions AggregateFunction(count, UInt64),
    unique_devices AggregateFunction(uniq, String),
    revenue AggregateFunction(sum, Decimal64(6))
)
ENGINE = AggregatingMergeTree()
ORDER BY (date, campaign_id, game_id);
