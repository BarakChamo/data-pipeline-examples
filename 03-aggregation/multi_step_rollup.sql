-- Multi-Step Aggregation: Hourly → Daily → Monthly
-- Building a rollup pyramid with aggregate states

-- Layer 1: Hourly (finest grain, populated by MV from raw events)
CREATE TABLE metrics_hourly (
    hour DateTime,
    campaign_id UInt32,
    impressions AggregateFunction(count, UInt64),
    unique_devices AggregateFunction(uniq, String),
    revenue AggregateFunction(sum, Decimal64(6))
)
ENGINE = AggregatingMergeTree()
ORDER BY (hour, campaign_id);

-- Layer 2: Daily (rolled up from hourly)
CREATE TABLE metrics_daily (
    date Date,
    campaign_id UInt32,
    impressions AggregateFunction(count, UInt64),
    unique_devices AggregateFunction(uniq, String),
    revenue AggregateFunction(sum, Decimal64(6))
)
ENGINE = AggregatingMergeTree()
ORDER BY (date, campaign_id);

-- MV: Hourly → Daily
CREATE MATERIALIZED VIEW mv_daily
TO metrics_daily
AS
SELECT
    toDate(hour) AS date,
    campaign_id,
    -- MergeState: merge hourly states, output new state for daily
    countMergeState(impressions) AS impressions,
    uniqMergeState(unique_devices) AS unique_devices,
    sumMergeState(revenue) AS revenue
FROM metrics_hourly
GROUP BY date, campaign_id;

-- Layer 3: Monthly (rolled up from daily)
CREATE TABLE metrics_monthly (
    month Date,
    campaign_id UInt32,
    impressions AggregateFunction(count, UInt64),
    unique_devices AggregateFunction(uniq, String),
    revenue AggregateFunction(sum, Decimal64(6))
)
ENGINE = AggregatingMergeTree()
ORDER BY (month, campaign_id);

-- MV: Daily → Monthly
CREATE MATERIALIZED VIEW mv_monthly
TO metrics_monthly
AS
SELECT
    toStartOfMonth(date) AS month,
    campaign_id,
    countMergeState(impressions) AS impressions,
    uniqMergeState(unique_devices) AS unique_devices,
    sumMergeState(revenue) AS revenue
FROM metrics_daily
GROUP BY month, campaign_id;

-- Query the appropriate layer based on time range:
-- Last 24 hours → metrics_hourly
-- Last 7 days → metrics_daily
-- Last 6 months → metrics_monthly

-- Data volume comparison for 1000 campaigns:
-- metrics_hourly: 24 × 1000 = 24,000 rows/day
-- metrics_daily: 1000 rows/day
-- metrics_monthly: 1000 rows/month

-- Dashboard query for monthly report now scans ~1000 rows
-- instead of 720,000 hourly rows (30 days × 24 hours × 1000 campaigns)
