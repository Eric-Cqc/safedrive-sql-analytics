-- Business question 4: Which completed services started late, and how many nearby assignments did that driver have?
-- Technique: a correlated subquery and TIMESTAMPDIFF().

SET @as_of = TIMESTAMP('2025-11-15 12:00:00');

SELECT
    o.order_id,
    o.scheduled_start,
    a.start_time,
    TIMESTAMPDIFF(MINUTE, o.scheduled_start, a.start_time) AS late_minutes,
    d.driver_id,
    d.name AS driver_name,
    (
        SELECT COUNT(*)
        FROM Assignment AS a2
        JOIN `order` AS o2
            ON o2.order_id = a2.order_id
        WHERE a2.driver_id = d.driver_id
          AND a2.start_time BETWEEN DATE_SUB(o.scheduled_start, INTERVAL 1 HOUR)
                                AND DATE_ADD(o.scheduled_start, INTERVAL 1 HOUR)
    ) AS near_orders
FROM `order` AS o
JOIN Assignment AS a
    ON a.order_id = o.order_id
JOIN Driver AS d
    ON d.driver_id = a.driver_id
WHERE o.status = 'completed'
  AND a.start_time > o.scheduled_start
  AND a.start_time <= @as_of
ORDER BY o.order_id;
