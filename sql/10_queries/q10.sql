-- Business question 10: Which completed orders are unpaid, older than 24 hours, and still within seven days of as_of?
-- Technique: fixed-time rolling-window predicates, joins, and elapsed-time calculation.

SET @as_of = TIMESTAMP('2025-11-15 12:00:00');

SELECT
    o.order_id,
    o.customer_id,
    c.name AS customer_name,
    c.phone,
    p.quoted_fee,
    p.payment_time,
    TIMESTAMPDIFF(HOUR, o.request_time, @as_of) AS hours_since_request
FROM `order` AS o
JOIN Payment AS p
    ON p.order_id = o.order_id
JOIN Customer AS c
    ON c.customer_id = o.customer_id
WHERE o.status = 'completed'
  AND p.status = 'pending'
  AND o.request_time >= DATE_SUB(@as_of, INTERVAL 7 DAY)
  AND o.request_time <= DATE_SUB(@as_of, INTERVAL 24 HOUR)
  AND o.request_time <= @as_of
ORDER BY hours_since_request DESC, o.order_id;
