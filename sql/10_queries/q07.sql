-- Business question 7: How do customer ratings compare across service types?
-- Technique: grouped aggregations with average, count, minimum, and maximum.

SET @as_of = TIMESTAMP('2025-11-15 12:00:00');

SELECT
    o.service_type,
    ROUND(AVG(r.stars), 2) AS avg_rating,
    COUNT(r.rating_id) AS review_count,
    MIN(r.stars) AS min_rating,
    MAX(r.stars) AS max_rating
FROM Rating AS r
JOIN Assignment AS a
    ON a.assignment_id = r.assignment_id
JOIN `order` AS o
    ON o.order_id = a.order_id
WHERE o.status = 'completed'
  AND o.request_time <= @as_of
GROUP BY o.service_type
ORDER BY avg_rating DESC, o.service_type;
