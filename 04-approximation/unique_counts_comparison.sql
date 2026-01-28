-- Unique Count Functions: Choosing the Right Tool

-- Function comparison for counting unique devices

-- 1. uniqExact: Hash set, 100% accurate
SELECT
    campaign_id,
    uniqExact(device_id) AS exact_unique_devices
FROM ad_events
GROUP BY campaign_id;

-- Memory: O(n) - stores every unique value
-- Speed: Slower, especially at high cardinality
-- Use when: Billing, financial reconciliation, fraud detection


-- 2. uniq: HyperLogLog++, ~2% error
SELECT
    campaign_id,
    uniq(device_id) AS approx_unique_devices
FROM ad_events
GROUP BY campaign_id;

-- Memory: Fixed 12KB per group
-- Speed: Fast, constant memory regardless of cardinality
-- Use when: Dashboards, reach reporting, general analytics


-- 3. uniqHLL12: HyperLogLog 12-bit, ~1.6% error
SELECT
    campaign_id,
    uniqHLL12(device_id) AS approx_unique_devices
FROM ad_events
GROUP BY campaign_id;

-- Memory: Fixed 2.5KB per group
-- Speed: Fastest, smallest memory footprint
-- Use when: High-volume state storage, memory-constrained environments


-- 4. uniqCombined: Adaptive (exact for small sets, HLL for large)
SELECT
    campaign_id,
    uniqCombined(device_id) AS adaptive_unique_devices
FROM ad_events
GROUP BY campaign_id;

-- Memory: Variable (small for low cardinality, capped for high)
-- Speed: Good balance
-- Use when: Mixed cardinality data


-- Practical example: Ad campaign reach reporting
SELECT
    campaign_id,
    
    -- For dashboard (fast, good enough)
    uniq(device_id) AS dashboard_reach,
    
    -- For billing reconciliation (exact, slower)
    uniqExact(device_id) AS billing_reach,
    
    -- Show the difference
    abs(uniqExact(device_id) - uniq(device_id)) AS difference,
    (1 - uniq(device_id) / uniqExact(device_id)) * 100 AS error_percent

FROM ad_events
WHERE event_type = 'impression'
GROUP BY campaign_id
ORDER BY billing_reach DESC
LIMIT 10;
