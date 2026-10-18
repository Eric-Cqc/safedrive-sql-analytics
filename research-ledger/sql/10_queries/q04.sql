-- q04: Which completed services exceed a lateness grace, and what other starts were nearby?
-- Synthetic coursework. Bounds [lower, as_of), Asia/Hong_Kong wall time.
SET time_zone = '+08:00';
SET @as_of = COALESCE(@as_of, TIMESTAMP('2025-11-15 12:00:00'));
SET @grace_minutes=COALESCE(@grace_minutes,0);
SELECT e.order_id,e.scheduled_start,e.start_time,
 ROUND(TIMESTAMPDIFF(SECOND,e.scheduled_start,e.start_time)/60,2) late_minutes,
 e.driver_id,d.name driver_name,
 (SELECT COUNT(DISTINCT a2.order_id) FROM Assignment a2 WHERE a2.driver_id=e.driver_id AND a2.order_id<>e.order_id
 AND a2.outcome='successful' AND a2.start_time>=DATE_SUB(e.scheduled_start,INTERVAL 1 HOUR)
 AND a2.start_time<=DATE_ADD(e.scheduled_start,INTERVAL 1 HOUR) AND a2.start_time<@as_of) other_nearby_orders,
 e.order_id AS order_ids
FROM v_order_evidence e JOIN Driver d ON d.driver_id=e.driver_id
WHERE e.completed_at<@as_of AND TIMESTAMPDIFF(SECOND,e.scheduled_start,e.start_time)>@grace_minutes*60
ORDER BY e.order_id;
