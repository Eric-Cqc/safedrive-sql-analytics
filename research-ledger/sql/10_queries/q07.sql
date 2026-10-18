-- q07: How do service-type rating means compare when review coverage is visible?
-- Synthetic coursework. Bounds [lower, as_of), Asia/Hong_Kong wall time.
SET time_zone = '+08:00';
SET @as_of = COALESCE(@as_of, TIMESTAMP('2025-11-15 12:00:00'));
SELECT service_type,COUNT(*) completed_orders,COUNT(CASE WHEN rated_at<@as_of THEN rating_id END) review_count,
 ROUND(COUNT(CASE WHEN rated_at<@as_of THEN rating_id END)/COUNT(*),4) review_coverage,
 ROUND(AVG(CASE WHEN rated_at<@as_of THEN stars END),2) avg_rating,
 MIN(CASE WHEN rated_at<@as_of THEN stars END) min_rating,MAX(CASE WHEN rated_at<@as_of THEN stars END) max_rating,
 GROUP_CONCAT(order_id ORDER BY order_id) order_ids
FROM v_order_evidence WHERE completed_at<@as_of GROUP BY service_type ORDER BY avg_rating DESC,service_type;
