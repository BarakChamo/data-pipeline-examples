-- Source Table: Raw Ad Events
-- This is the "landing zone" for all incoming events

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
ORDER BY (game_id, campaign_id, toStartOfHour(event_time), event_type)
TTL event_time + INTERVAL 90 DAY DELETE;

-- Sample data volume:
-- • 500M impressions/week
-- • ~3M rows/hour at peak
-- • 40+ columns per event
-- • 90 days retention = ~6.4B rows
