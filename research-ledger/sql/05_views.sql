-- One row per order; failed attempts, multiple incidents/custodies never multiply money.
CREATE OR REPLACE VIEW v_order_evidence AS
SELECT o.*, a.assignment_id, a.driver_id, a.assign_time, a.start_time, a.end_time,
       a.odometer_before, a.odometer_after,
       a.odometer_after-a.odometer_before AS measured_km,
       p.payment_id, p.quoted_fee, p.final_fee, p.payment_time, p.refund_amount, p.refund_time,
       p.status AS current_payment_status,
       r.rating_id, r.stars, r.rated_at
FROM `order` o
LEFT JOIN Assignment a ON a.order_id=o.order_id AND a.outcome='successful'
LEFT JOIN Payment p ON p.order_id=o.order_id
LEFT JOIN Rating r ON r.assignment_id=a.assignment_id;
