-- CollapsingMergeTree: Handle Row Updates and Deletes
-- Use case: Event corrections, state changes that need to "undo" previous values

CREATE TABLE campaign_state_changes (
    campaign_id UInt32,
    changed_at DateTime64(3),

    -- State attributes
    status LowCardinality(String),  -- 'active', 'paused', 'completed'
    daily_budget Decimal64(2),
    bid_amount Decimal64(4),

    -- Sign column: 1 = insert, -1 = cancel previous row
    sign Int8
)
ENGINE = CollapsingMergeTree(sign)
ORDER BY (campaign_id, changed_at);

-- Initial state
INSERT INTO campaign_state_changes VALUES
    (123, '2024-06-15 10:00:00', 'active', 1000.00, 2.50, 1);

-- To update: insert cancellation (-1) then new state (+1)
INSERT INTO campaign_state_changes VALUES
    (123, '2024-06-15 10:00:00', 'active', 1000.00, 2.50, -1),  -- Cancel old
    (123, '2024-06-15 14:00:00', 'paused', 1000.00, 2.50, 1);   -- New state

-- After merge, the canceled rows disappear
-- Query current state (use FINAL or GROUP BY with sign)
SELECT
    campaign_id,
    argMax(status, changed_at) AS current_status,
    argMax(daily_budget, changed_at) AS current_budget
FROM campaign_state_changes
GROUP BY campaign_id
HAVING SUM(sign) > 0;  -- Only campaigns with net positive rows

-- Why CollapsingMergeTree?
-- ✓ True "updates" without rewriting entire partitions
-- ✓ Supports counting unique states over time
-- ✓ Efficient for CDC streams with before/after images
-- ✗ More complex insert logic (must track previous state)
-- ✗ Consider ReplacingMergeTree for simpler "latest value" cases
