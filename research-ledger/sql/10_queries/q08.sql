-- q08: Which customers repeat positive-net settled purchases, and how does that differ from vehicle reuse?
-- Synthetic coursework. Bounds [lower, as_of), Asia/Hong_Kong wall time.
SET time_zone = '+08:00';
SET @as_of = COALESCE(@as_of, TIMESTAMP('2025-11-15 12:00:00'));
SET @purchase_months=COALESCE(@purchase_months,3);
WITH paid_orders AS (
 SELECT * FROM v_order_evidence WHERE completed_at<@as_of
 AND request_time>=DATE_SUB(@as_of,INTERVAL @purchase_months MONTH) AND request_time<@as_of
 AND payment_time<@as_of AND final_fee-CASE WHEN refund_time<@as_of THEN refund_amount ELSE 0 END>0
), stats AS (
 SELECT c.customer_id,c.name customer_name,c.membership_tier,COUNT(*) paid_orders,
 COUNT(DISTINCT e.vehicle_id) vehicle_count,SUM(e.final_fee-CASE WHEN e.refund_time<@as_of THEN e.refund_amount ELSE 0 END) net_paid_asof,
 GROUP_CONCAT(e.order_id ORDER BY e.order_id) order_ids
 FROM Customer c JOIN paid_orders e ON e.customer_id=c.customer_id GROUP BY c.customer_id,c.name,c.membership_tier
)
SELECT *,ROUND((paid_orders-1)/paid_orders,4) repeat_order_share,
 ROUND((paid_orders-vehicle_count)/paid_orders,4) extra_vehicle_order_share FROM stats WHERE paid_orders>1
ORDER BY repeat_order_share DESC,customer_id;
