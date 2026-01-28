-- Understanding -State and -Merge: The Foundation of Incremental Aggregation

-- PROBLEM: How do you compute COUNT DISTINCT across multiple time periods
-- without re-scanning all raw data?

-- ANSWER: Store intermediate "states" that can be merged later

-- Step 1: Create state (during INSERT or MV)
SELECT
    toStartOfHour(event_time) AS hour,
    campaign_id,
    
    -- countState() returns a binary blob, NOT a number
    -- This blob contains the internal counter state
    countState() AS impressions_state,
    
    -- uniqState() returns a HyperLogLog sketch
    -- This 12KB blob can estimate unique counts
    uniqState(device_id) AS unique_devices_state
    
FROM ad_events
GROUP BY hour, campaign_id;

-- Step 2: Store states in AggregatingMergeTree
-- (States are stored as binary columns)

-- Step 3: Query with -Merge to finalize
SELECT
    campaign_id,
    
    -- countMerge() combines states and returns final count
    countMerge(impressions_state) AS total_impressions,
    
    -- uniqMerge() combines HLL sketches and returns estimate
    uniqMerge(unique_devices_state) AS unique_devices
    
FROM hourly_campaign_metrics
WHERE hour >= '2024-06-01' AND hour < '2024-06-08'
GROUP BY campaign_id;

-- KEY INSIGHT:
-- The -Merge operation combines states WITHOUT accessing raw data
-- 168 hourly states (7 days × 24 hours) merge in microseconds
-- vs. scanning millions of raw events

-- Binary representation example (conceptual):
-- countState() → 8 bytes (just the counter value)
-- sumState(revenue) → 8 bytes (accumulated sum)
-- uniqState(device_id) → ~12KB (HyperLogLog registers)
-- quantileTDigestState(0.95)(latency) → ~5KB (T-Digest centroids)
