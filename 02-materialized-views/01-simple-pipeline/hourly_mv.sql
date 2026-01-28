-- Materialized View: Automatic Hourly Rollup
-- Triggered on every INSERT to ad_events

CREATE MATERIALIZED VIEW mv_hourly_campaign
TO hourly_campaign_metrics
AS
SELECT
    toStartOfHour(event_time) AS hour,
    campaign_id,
    game_id,
    placement_type,
    
    -- Use -State functions to create aggregate states
    countState() AS impressions,
    uniqState(device_id) AS unique_devices,
    sumState(toUInt64(is_viewable)) AS viewable_impressions,
    sumState(toUInt64(event_type = 'click')) AS clicks,
    sumState(revenue) AS revenue
    
FROM ad_events
WHERE event_type IN ('impression', 'click')
GROUP BY hour, campaign_id, game_id, placement_type;

-- How it works:
-- 1. App INSERTs 10,000 ad_events
-- 2. MV SELECT runs against those 10,000 rows only
-- 3. Result (~100 aggregated rows) INSERT into hourly_campaign_metrics
-- 4. Both INSERTs committed atomically

-- Cost characteristics:
-- • Compute happens at write time, not query time
-- • Each event processed exactly once
-- • No re-scanning historical data
-- • Dashboard queries hit pre-aggregated table
