-- Variable Grouping: Same States, Different Aggregations

-- PROBLEM: Dashboard needs multiple views of the same data
-- • By campaign (advertiser view)
-- • By game (publisher view)
-- • By placement type (operations view)

-- Traditional: Store three separate aggregation tables
-- ClickHouse: Store one table, query with different GROUP BY

-- Source: Hourly metrics at finest grain
CREATE TABLE hourly_metrics (
    hour DateTime,
    campaign_id UInt32,
    game_id UInt32,
    placement_type LowCardinality(String),
    
    impressions AggregateFunction(count, UInt64),
    unique_devices AggregateFunction(uniq, String),
    revenue AggregateFunction(sum, Decimal64(6))
)
ENGINE = AggregatingMergeTree()
ORDER BY (hour, campaign_id, game_id, placement_type);

-- View 1: Advertiser Dashboard (group by campaign)
SELECT
    campaign_id,
    countMerge(impressions) AS total_impressions,
    uniqMerge(unique_devices) AS unique_reach,  -- HLL sketches merge correctly!
    sumMerge(revenue) AS total_revenue
FROM hourly_metrics
WHERE hour >= today() - 7
GROUP BY campaign_id;

-- View 2: Publisher Dashboard (group by game)
SELECT
    game_id,
    countMerge(impressions) AS total_impressions,
    uniqMerge(unique_devices) AS unique_reach,
    sumMerge(revenue) AS total_revenue
FROM hourly_metrics
WHERE hour >= today() - 7
GROUP BY game_id;

-- View 3: Operations Dashboard (group by placement)
SELECT
    placement_type,
    countMerge(impressions) AS total_impressions,
    uniqMerge(unique_devices) AS unique_reach,
    sumMerge(revenue) AS total_revenue
FROM hourly_metrics
WHERE hour >= today() - 7
GROUP BY placement_type;

-- KEY INSIGHT:
-- uniqMerge produces correct unique counts regardless of grouping!
-- Campaign A has 100K uniques, Campaign B has 80K uniques
-- Merged together: NOT 180K, but actual unique count (say 150K)
-- This is mathematically correct because HLL sketches are mergeable
