-- q05: Do current rating summaries match recomputation, and which ratings were known at as_of?
-- Synthetic coursework. Bounds [lower, as_of), Asia/Hong_Kong wall time.
SET time_zone = '+08:00';
SET @as_of = COALESCE(@as_of, TIMESTAMP('2025-11-15 12:00:00'));
SELECT d.driver_id,d.name driver_name,d.avg_rating current_summary_avg,d.rating_count current_summary_count,
 ROUND(AVG(r.stars),2) current_recomputed_avg,COUNT(r.rating_id) current_recomputed_count,
 ROUND(AVG(CASE WHEN r.rated_at<@as_of THEN r.stars END),2) asof_avg,
 COUNT(CASE WHEN r.rated_at<@as_of THEN r.rating_id END) asof_rating_count,
 GROUP_CONCAT(CASE WHEN r.rated_at<@as_of THEN a.order_id END ORDER BY a.order_id) order_ids
FROM Driver d LEFT JOIN Assignment a ON a.driver_id=d.driver_id
LEFT JOIN Rating r ON r.assignment_id=a.assignment_id
GROUP BY d.driver_id,d.name,d.avg_rating,d.rating_count ORDER BY d.driver_id;
