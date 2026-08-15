-- Business question 2: Which drivers delivered the most successful service and paid revenue in the last 30 days?
-- Technique: CTEs, joins, conditional date windows, and aggregations.

SET @as_of = TIMESTAMP('2025-11-15 12:00:00');

WITH recent_success AS (
    SELECT
        d.driver_id,
        d.name AS driver_name,
        COUNT(*) AS successful_assignments
    FROM Driver AS d
    JOIN Assignment AS a
        ON a.driver_id = d.driver_id
    JOIN `order` AS o
        ON o.order_id = a.order_id
    WHERE a.outcome = 'successful'
      AND o.status = 'completed'
      AND a.assign_time BETWEEN DATE_SUB(@as_of, INTERVAL 30 DAY) AND @as_of
    GROUP BY d.driver_id, d.name
),
recent_revenue AS (
    SELECT
        d.driver_id,
        SUM(p.final_fee) AS paid_revenue
    FROM Driver AS d
    JOIN Assignment AS a
        ON a.driver_id = d.driver_id
    JOIN `order` AS o
        ON o.order_id = a.order_id
    JOIN Payment AS p
        ON p.order_id = o.order_id
    WHERE a.outcome = 'successful'
      AND o.status = 'completed'
      AND p.status = 'paid'
      AND a.assign_time BETWEEN DATE_SUB(@as_of, INTERVAL 30 DAY) AND @as_of
    GROUP BY d.driver_id
)
SELECT
    rs.driver_id,
    rs.driver_name,
    rs.successful_assignments,
    ROUND(COALESCE(rr.paid_revenue, 0.00), 2) AS paid_revenue
FROM recent_success AS rs
LEFT JOIN recent_revenue AS rr
    ON rr.driver_id = rs.driver_id
ORDER BY rs.successful_assignments DESC, paid_revenue DESC, rs.driver_id;
