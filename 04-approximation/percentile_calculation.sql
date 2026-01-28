-- Percentile Functions: Latency and Performance Monitoring

-- PROBLEM: Calculate p50, p95, p99 latency across millions of events
-- Exact calculation requires sorting all values: O(n log n)
-- At 500M events, this is prohibitively expensive

-- 1. quantileExact: Exact percentile (sorts all values)
SELECT
    game_id,
    quantileExact(0.50)(response_time_ms) AS p50_exact,
    quantileExact(0.95)(response_time_ms) AS p95_exact,
    quantileExact(0.99)(response_time_ms) AS p99_exact
FROM api_requests
GROUP BY game_id;

-- Memory: O(n) - stores all values
-- Speed: Slow at scale
-- Use when: Small datasets, validation, exact requirements


-- 2. quantileTDigest: T-Digest algorithm (~1% error)
SELECT
    game_id,
    quantileTDigest(0.50)(response_time_ms) AS p50_approx,
    quantileTDigest(0.95)(response_time_ms) AS p95_approx,
    quantileTDigest(0.99)(response_time_ms) AS p99_approx
FROM api_requests
GROUP BY game_id;

-- Memory: Fixed ~5KB per group (stores ~100 centroids)
-- Speed: Fast, streaming algorithm
-- Use when: Latency monitoring, SLA tracking, dashboards


-- 3. quantileTiming: Optimized for response times (<30 sec)
SELECT
    game_id,
    quantileTiming(0.50)(response_time_ms) AS p50_timing,
    quantileTiming(0.95)(response_time_ms) AS p95_timing,
    quantileTiming(0.99)(response_time_ms) AS p99_timing
FROM api_requests
GROUP BY game_id;

-- Memory: Fixed, uses histogram buckets
-- Speed: Very fast
-- Use when: Response times known to be < 30 seconds


-- Pre-aggregation with states for dashboard
CREATE TABLE api_latency_hourly (
    hour DateTime,
    game_id UInt32,
    endpoint LowCardinality(String),
    
    request_count AggregateFunction(count, UInt64),
    latency_p50 AggregateFunction(quantileTDigest(0.5), UInt32),
    latency_p95 AggregateFunction(quantileTDigest(0.95), UInt32),
    latency_p99 AggregateFunction(quantileTDigest(0.99), UInt32)
)
ENGINE = AggregatingMergeTree()
ORDER BY (hour, game_id, endpoint);

-- Query for SLA dashboard
SELECT
    game_id,
    countMerge(request_count) AS total_requests,
    quantileTDigestMerge(0.5)(latency_p50) AS p50_ms,
    quantileTDigestMerge(0.95)(latency_p95) AS p95_ms,
    quantileTDigestMerge(0.99)(latency_p99) AS p99_ms
FROM api_latency_hourly
WHERE hour >= now() - INTERVAL 24 HOUR
GROUP BY game_id;
