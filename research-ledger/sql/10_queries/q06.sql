-- q06: Which completed orders belong to customers currently classified as VIP?
-- Synthetic coursework. Bounds [lower, as_of), Asia/Hong_Kong wall time.
SET time_zone = '+08:00';
SET @as_of = COALESCE(@as_of, TIMESTAMP('2025-11-15 12:00:00'));
SELECT c.name customer_name,e.order_id,e.request_time,e.completed_at,e.pickup_location,e.dropoff_location,e.service_type,
 CASE WHEN e.payment_id IS NULL THEN 'missing' WHEN e.payment_time IS NULL OR e.payment_time>=@as_of THEN 'pending'
 WHEN e.refund_time<@as_of THEN 'refunded' ELSE 'paid' END payment_state_asof,
 CASE WHEN e.payment_time<@as_of THEN e.final_fee ELSE 0 END-CASE WHEN e.refund_time<@as_of THEN e.refund_amount ELSE 0 END net_paid_asof,
 e.measured_km,e.order_id AS order_ids
FROM Customer c JOIN v_order_evidence e ON e.customer_id=c.customer_id
WHERE c.membership_tier='VIP' AND e.completed_at<@as_of ORDER BY e.completed_at DESC,e.order_id DESC;
