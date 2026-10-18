-- q09: What is the registered fleet distribution, including models with zero vehicles?
-- Synthetic coursework. Bounds [lower, as_of), Asia/Hong_Kong wall time.
SET time_zone = '+08:00';
SET @as_of = COALESCE(@as_of, TIMESTAMP('2025-11-15 12:00:00'));
SELECT b.id brand_id,b.name brand_name,m.id model_id,m.name model_name,COUNT(v.vehicle_id) vehicle_count,
 GROUP_CONCAT(v.vehicle_id ORDER BY v.vehicle_id) vehicle_ids
FROM Brandmodel b JOIN Brandmodel m ON m.parent_id=b.id
LEFT JOIN Vehicle v ON v.model_id=m.id AND v.registered_at<@as_of
GROUP BY b.id,b.name,m.id,m.name ORDER BY brand_id,model_id;
