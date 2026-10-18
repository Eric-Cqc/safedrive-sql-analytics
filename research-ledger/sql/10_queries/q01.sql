-- q01: Which customers have a high share of completed orders with a known high-severity incident?
-- Synthetic coursework. Bounds [lower, as_of), Asia/Hong_Kong wall time.
SET time_zone = '+08:00';
SET @as_of = COALESCE(@as_of, TIMESTAMP('2025-11-15 12:00:00'));
SET @severity = COALESCE(@severity, 4);
SET @incident_threshold = COALESCE(@incident_threshold, 0.30);
WITH metrics AS (
 SELECT c.customer_id, c.name customer_name,
 COUNT(DISTINCT o.order_id) completed_orders,
 COUNT(DISTINCT i.incident_id) incident_events,
 COUNT(DISTINCT CASE WHEN i.severity>=@severity THEN i.incident_id END) high_severity_events,
 COUNT(DISTINCT CASE WHEN i.severity>=@severity THEN o.order_id END) affected_orders,
 GROUP_CONCAT(DISTINCT o.order_id ORDER BY o.order_id) order_ids
 FROM Customer c LEFT JOIN `order` o ON o.customer_id=c.customer_id AND o.completed_at<@as_of
 LEFT JOIN Incident i ON i.order_id=o.order_id AND i.recorded_at<@as_of
 GROUP BY c.customer_id,c.name
)
SELECT *, ROUND(affected_orders/NULLIF(completed_orders,0),4) affected_order_rate
FROM metrics WHERE affected_orders/NULLIF(completed_orders,0)>=@incident_threshold ORDER BY customer_id;
