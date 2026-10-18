-- q10: Which completed services in seven days remain unsettled for strictly more than 24 hours?
-- Synthetic coursework. Bounds [lower, as_of), Asia/Hong_Kong wall time.
SET time_zone = '+08:00';
SET @as_of = COALESCE(@as_of, TIMESTAMP('2025-11-15 12:00:00'));
SET @unpaid_days=COALESCE(@unpaid_days,7);
SET @overdue_hours=COALESCE(@overdue_hours,24);
SELECT e.order_id,e.customer_id,c.name customer_name,e.completed_at,e.quoted_fee,
 CASE WHEN e.payment_id IS NULL THEN 'missing' ELSE 'pending' END payment_state_asof,
 ROUND(TIMESTAMPDIFF(SECOND,e.completed_at,@as_of)/3600,4) hours_since_completion,
 e.order_id AS order_ids
FROM v_order_evidence e JOIN Customer c ON c.customer_id=e.customer_id
WHERE e.completed_at>=DATE_SUB(@as_of,INTERVAL @unpaid_days DAY) AND e.completed_at<@as_of
 AND e.completed_at<DATE_SUB(@as_of,INTERVAL @overdue_hours HOUR)
 AND (e.payment_id IS NULL OR e.payment_time IS NULL OR e.payment_time>=@as_of)
ORDER BY e.completed_at,e.order_id;
