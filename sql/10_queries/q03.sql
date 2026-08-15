-- Business question 3: What are the most common custody routes for each parking partner in the last 14 days?
-- Technique: CTEs and ROW_NUMBER() OVER for per-partner ranking.

SET @as_of = TIMESTAMP('2025-11-15 12:00:00');

WITH route_counts AS (
    SELECT
        pc.partner_name,
        o.pickup_location,
        o.dropoff_location,
        COUNT(*) AS pattern_count
    FROM ParkingCustody AS pc
    JOIN Assignment AS a
        ON a.assignment_id = pc.assignment_id
    JOIN `order` AS o
        ON o.order_id = a.order_id
    WHERE pc.check_in_time BETWEEN DATE_SUB(@as_of, INTERVAL 14 DAY) AND @as_of
    GROUP BY pc.partner_name, o.pickup_location, o.dropoff_location
),
ranked_routes AS (
    SELECT
        partner_name,
        pickup_location,
        dropoff_location,
        pattern_count,
        ROW_NUMBER() OVER (
            PARTITION BY partner_name
            ORDER BY pattern_count DESC, pickup_location, dropoff_location
        ) AS route_rank
    FROM route_counts
)
SELECT
    partner_name,
    pickup_location,
    dropoff_location,
    pattern_count,
    route_rank
FROM ranked_routes
WHERE route_rank <= 5
ORDER BY partner_name, route_rank;
