-- q02: How do driver service cohorts differ from cash collected and refunded in the last 30 days?
-- Synthetic coursework. Bounds [lower, as_of), Asia/Hong_Kong wall time.
SET time_zone = '+08:00';
SET @as_of = COALESCE(@as_of, TIMESTAMP('2025-11-15 12:00:00'));
SET @service_days = COALESCE(@service_days,30);
WITH metrics AS (
 SELECT d.driver_id,d.name driver_name,
 SUM(CASE WHEN e.completed_at>=DATE_SUB(@as_of,INTERVAL @service_days DAY) AND e.completed_at<@as_of THEN 1 ELSE 0 END) completed_orders,
 SUM(CASE WHEN e.completed_at>=DATE_SUB(@as_of,INTERVAL @service_days DAY) AND e.completed_at<@as_of THEN
    CASE WHEN e.payment_time<@as_of THEN e.final_fee ELSE 0 END-CASE WHEN e.refund_time<@as_of THEN e.refund_amount ELSE 0 END ELSE 0 END) service_cohort_net_paid_asof,
 SUM(CASE WHEN e.completed_at<@as_of AND e.payment_time>=DATE_SUB(@as_of,INTERVAL @service_days DAY) AND e.payment_time<@as_of THEN e.final_fee ELSE 0 END) cash_collected_window,
 SUM(CASE WHEN e.completed_at<@as_of AND e.refund_time>=DATE_SUB(@as_of,INTERVAL @service_days DAY) AND e.refund_time<@as_of THEN e.refund_amount ELSE 0 END) refunds_window,
 SUM(CASE WHEN e.completed_at>=DATE_SUB(@as_of,INTERVAL @service_days DAY) AND e.completed_at<@as_of THEN e.measured_km END) measured_km,
 SUM(CASE WHEN e.completed_at>=DATE_SUB(@as_of,INTERVAL @service_days DAY) AND e.completed_at<@as_of AND e.measured_km IS NULL THEN 1 ELSE 0 END) missing_km_orders,
 GROUP_CONCAT(CASE WHEN e.completed_at>=DATE_SUB(@as_of,INTERVAL @service_days DAY) AND e.completed_at<@as_of THEN e.order_id END ORDER BY e.order_id) order_ids
 FROM Driver d LEFT JOIN v_order_evidence e ON e.driver_id=d.driver_id GROUP BY d.driver_id,d.name
)
SELECT *, cash_collected_window-refunds_window net_cash_window FROM metrics
ORDER BY completed_orders DESC,service_cohort_net_paid_asof DESC,driver_id;
