-- Step 1: Raw Events → Hourly Aggregates
CREATE MATERIALIZED VIEW mv_hourly
TO metrics_hourly
AS
SELECT
    toStartOfHour(event_time) AS hour,
    campaign_id,
    game_id,
    countState() AS impressions,
    uniqState(device_id) AS unique_devices,
    sumState(revenue) AS revenue
FROM ad_events
WHERE event_type = 'impression'
GROUP BY hour, campaign_id, game_id;
