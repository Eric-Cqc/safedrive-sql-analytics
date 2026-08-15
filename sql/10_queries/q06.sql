-- Business question 6: Which completed orders belong to VIP customers?
-- Technique: an equi-join with categorical filtering.

SET @as_of = TIMESTAMP('2025-11-15 12:00:00');

SELECT
    c.name AS customer_name,
    o.order_id,
    o.request_time,
    o.pickup_location,
    o.dropoff_location,
    o.service_type
FROM Customer AS c
JOIN `order` AS o
    ON o.customer_id = c.customer_id
WHERE c.membership_tier = 'VIP'
  AND o.status = 'completed'
  AND o.request_time <= @as_of
ORDER BY o.request_time DESC, o.order_id DESC;
