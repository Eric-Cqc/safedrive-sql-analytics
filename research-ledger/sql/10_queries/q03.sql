-- q03: Which routes occur most often among distinct completed orders at each custody partner?
-- Synthetic coursework. Bounds [lower, as_of), Asia/Hong_Kong wall time.
SET time_zone = '+08:00';
SET @as_of = COALESCE(@as_of, TIMESTAMP('2025-11-15 12:00:00'));
SET @custody_days=COALESCE(@custody_days,14);
SET @top_routes=COALESCE(@top_routes,5);
WITH route_counts AS (
 SELECT pc.partner_name,e.pickup_location,e.dropoff_location,COUNT(DISTINCT e.order_id) order_count,
 COUNT(*) custody_episodes,GROUP_CONCAT(DISTINCT e.order_id ORDER BY e.order_id) order_ids
 FROM ParkingCustody pc JOIN v_order_evidence e ON e.assignment_id=pc.assignment_id
 WHERE e.completed_at<@as_of AND pc.check_in_time>=DATE_SUB(@as_of,INTERVAL @custody_days DAY) AND pc.check_in_time<@as_of
 GROUP BY pc.partner_name,e.pickup_location,e.dropoff_location
), ranked AS (
 SELECT *,ROW_NUMBER() OVER (PARTITION BY partner_name ORDER BY order_count DESC,pickup_location,dropoff_location) route_rank FROM route_counts
)
SELECT * FROM ranked WHERE route_rank<=@top_routes ORDER BY partner_name,route_rank;
