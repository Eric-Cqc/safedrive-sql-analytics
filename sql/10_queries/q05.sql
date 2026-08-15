-- Business question 5: What driver rating averages are maintained by the insert trigger?
-- Technique: trigger-maintained summary plus an independent aggregate cross-check.

SET @as_of = TIMESTAMP('2025-11-15 12:00:00');

SELECT
    d.driver_id,
    d.name AS driver_name,
    d.avg_rating AS trigger_avg_rating,
    COALESCE(ROUND(AVG(r.stars), 2), 0.00) AS recomputed_avg_rating,
    COUNT(r.rating_id) AS rating_count
FROM Driver AS d
LEFT JOIN Assignment AS a
    ON a.driver_id = d.driver_id
LEFT JOIN Rating AS r
    ON r.assignment_id = a.assignment_id
GROUP BY d.driver_id, d.name, d.avg_rating
ORDER BY d.driver_id;
