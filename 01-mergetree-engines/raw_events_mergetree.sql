-- MergeTree: The Foundation for Raw Event Storage
-- Use case: Immutable event logs where every row matters

CREATE TABLE ad_events (
    -- Event identification
    event_id UUID DEFAULT generateUUIDv4(),
    event_time DateTime64(3),
    event_type LowCardinality(String),  -- 'impression', 'click', 'video_start', etc.

    -- Business dimensions
    campaign_id UInt32,
    advertiser_id UInt32,
    game_id UInt32,
    publisher_id UInt32,
    placement_type LowCardinality(String),  -- 'interstitial', 'rewarded', 'banner'

    -- Device context
    device_id String,
    device_type LowCardinality(String),
    country LowCardinality(String),

    -- Metrics
    revenue Decimal64(6),
    cost Decimal64(6),
    is_viewable UInt8,
    view_duration_ms UInt32
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_time)
ORDER BY (game_id, campaign_id, toStartOfHour(event_time), event_type, event_id)
TTL event_time + INTERVAL 90 DAY DELETE;

-- Why MergeTree for raw events?
-- ✓ Every event preserved (no deduplication, no aggregation)
-- ✓ Optimized for append-only workloads
-- ✓ Sparse index enables efficient range scans
-- ✓ Partitioning enables fast TTL cleanup
-- ✓ ORDER BY optimizes common query patterns

-- ORDER BY design rationale:
-- 1. game_id first: most queries filter by game
-- 2. campaign_id: second most common filter
-- 3. time (hourly): range scans within time windows
-- 4. event_type: often used in WHERE clause
-- 5. event_id: guarantees unique ordering
