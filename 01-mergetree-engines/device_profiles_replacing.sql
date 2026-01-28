-- ReplacingMergeTree: Automatic Deduplication for Latest State
-- Use case: Device profiles, user attributes, campaign settings

CREATE TABLE device_profiles (
    device_id String,
    updated_at DateTime64(3),
    
    -- Attributes that change over time
    country LowCardinality(String),
    device_type LowCardinality(String),
    os_version LowCardinality(String),
    app_version LowCardinality(String),
    
    -- Frequency capping state
    last_impression_time DateTime64(3),
    impressions_today UInt32,
    
    -- Consent/privacy
    gdpr_consent UInt8,
    ccpa_opt_out UInt8
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY device_id;

-- How it works:
-- 1. INSERT new row with same device_id
-- 2. During background merge, ClickHouse keeps only the row
--    with the highest updated_at value per device_id
-- 3. Old rows are automatically discarded

-- Example: Device moves from US to UK
INSERT INTO device_profiles VALUES
    ('abc123', '2024-06-15 10:00:00', 'US', 'mobile', '17.0', '2.1', now(), 5, 1, 0);

-- Later, device location changes
INSERT INTO device_profiles VALUES
    ('abc123', '2024-06-15 14:00:00', 'UK', 'mobile', '17.0', '2.1', now(), 8, 1, 0);

-- After merge, only the UK row exists
-- Query with FINAL to get latest even before merge:
SELECT * FROM device_profiles FINAL WHERE device_id = 'abc123';

-- Why ReplacingMergeTree for device profiles?
-- ✓ Simple "upsert" semantics without explicit UPDATE
-- ✓ No need to track previous state
-- ✓ Storage automatically cleaned during merges
-- ✓ Works well with CDC streams (just emit current state)
-- ✗ FINAL keyword has performance cost on large tables
-- ✗ No access to historical states after merge
