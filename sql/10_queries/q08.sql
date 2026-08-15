-- Business question 8: Which customers show repeat purchases in the three months before as_of?
-- Technique: distinct counting, ratios, GROUP BY, and a CTE.

SET @as_of = TIMESTAMP('2025-11-15 12:00:00');

WITH customer_order_stats AS (
    SELECT
        c.customer_id,
        c.name AS customer_name,
        c.membership_tier,
        COUNT(o.order_id) AS total_orders,
        COUNT(DISTINCT o.vehicle_id) AS vehicle_count
    FROM Customer AS c
    JOIN `order` AS o
        ON o.customer_id = c.customer_id
    WHERE o.request_time BETWEEN DATE_SUB(@as_of, INTERVAL 3 MONTH) AND @as_of
    GROUP BY c.customer_id, c.name, c.membership_tier
)
SELECT
    customer_name,
    membership_tier,
    total_orders,
    vehicle_count,
    ROUND(total_orders / vehicle_count, 2) AS orders_per_vehicle,
    ROUND((total_orders - vehicle_count) / total_orders, 2) AS repeat_purchase_rate
FROM customer_order_stats
WHERE total_orders > 1
ORDER BY repeat_purchase_rate DESC, customer_name;
