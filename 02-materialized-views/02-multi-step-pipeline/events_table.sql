-- Source: Raw Events (same as simple pipeline)
CREATE TABLE ad_events (
    event_id UUID DEFAULT generateUUIDv4(),
    event_time DateTime64(3),
    event_type LowCardinality(String),
    campaign_id UInt32,
    game_id UInt32,
    placement_type LowCardinality(String),
    device_id String,
    revenue Decimal64(6),
    is_viewable UInt8
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_time)
ORDER BY (game_id, campaign_id, toStartOfHour(event_time), event_type);
