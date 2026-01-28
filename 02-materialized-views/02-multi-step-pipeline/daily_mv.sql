-- Step 2: Hourly Aggregates → Daily Aggregates
-- Triggered on INSERT to hourly_campaign_metrics (cascading!)

CREATE MATERIALIZED VIEW mv_daily_campaign
TO daily_campaign_metrics
AS
SELECT
    toDate(hour) AS date,
    campaign_id,
    game_id,

    -- Use -Merge to combine hourly states, then -State to re-emit
    countMergeState(impressions) AS impressions,
    uniqMergeState(unique_devices) AS unique_devices,
    sumMergeState(clicks) AS clicks,
    sumMergeState(revenue) AS revenue
FROM hourly_campaign_metrics
GROUP BY date, campaign_id, game_id;

-- Pipeline flow:
--
-- INSERT ad_events (10K rows)
--    ↓ triggers mv_hourly_campaign
-- INSERT hourly_campaign_metrics (~50 rows)
--    ↓ triggers mv_daily_campaign
-- INSERT daily_campaign_metrics (~10 rows)
--
-- All three INSERTs happen in one atomic transaction!
-- No cron jobs, no ETL orchestration, no Airflow DAGs.
