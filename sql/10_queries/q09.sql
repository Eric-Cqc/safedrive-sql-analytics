-- Business question 9: What is the distribution of vehicles across brands and models?
-- Technique: self-join to the brand parent and grouped counting.

SET @as_of = TIMESTAMP('2025-11-15 12:00:00');

SELECT
    b.parent_id AS brand_id,
    bp.name AS brand_name,
    b.id AS model_id,
    b.name AS model_name,
    COUNT(v.vehicle_id) AS vehicle_count
FROM Vehicle AS v
JOIN Brandmodel AS b
    ON b.id = v.model_id
LEFT JOIN Brandmodel AS bp
    ON bp.id = b.parent_id
GROUP BY b.parent_id, bp.name, b.id, b.name
ORDER BY brand_id, model_id;
