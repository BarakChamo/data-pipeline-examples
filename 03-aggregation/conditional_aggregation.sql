-- Conditional Aggregation with -If: Multiple Metrics in One Pass

-- PROBLEM: Calculate multiple filtered metrics
-- Traditional approach: multiple queries or subqueries

-- BAD: Multiple table scans
SELECT campaign_id, count(*) AS impressions FROM ad_events WHERE event_type = 'impression' GROUP BY campaign_id;
SELECT campaign_id, count(*) AS clicks FROM ad_events WHERE event_type = 'click' GROUP BY campaign_id;
SELECT campaign_id, count(*) AS viewable FROM ad_events WHERE is_viewable = 1 GROUP BY campaign_id;

-- GOOD: Single table scan with -If combinators
SELECT
    campaign_id,
    
    -- countIf: count only rows matching condition
    countIf(event_type = 'impression') AS impressions,
    countIf(event_type = 'click') AS clicks,
    countIf(event_type = 'impression' AND is_viewable = 1) AS viewable_impressions,
    
    -- sumIf: sum only matching rows
    sumIf(revenue, event_type = 'impression') AS impression_revenue,
    sumIf(revenue, event_type = 'click') AS click_revenue,
    
    -- Computed metrics
    countIf(event_type = 'click') / countIf(event_type = 'impression') AS ctr,
    countIf(is_viewable = 1) / countIf(event_type = 'impression') AS viewability_rate,
    
    -- uniqIf: unique count with condition
    uniqIf(device_id, event_type = 'impression') AS unique_impressions,
    uniqIf(device_id, event_type = 'click') AS unique_clickers

FROM ad_events
WHERE event_time >= now() - INTERVAL 7 DAY
GROUP BY campaign_id;

-- For pre-aggregation, combine -State and -If:
SELECT
    toStartOfHour(event_time) AS hour,
    campaign_id,
    
    -- Store conditional states
    countStateIf(event_type = 'impression') AS impressions,
    countStateIf(event_type = 'click') AS clicks,
    sumStateIf(revenue, event_type = 'impression') AS revenue
    
FROM ad_events
GROUP BY hour, campaign_id;

-- Query with -MergeIf (rare) or just -Merge on pre-filtered states
