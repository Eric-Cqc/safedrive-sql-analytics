-- Idempotent summary maintenance and cross-table timestamp guards.
-- Serial UPDATE on Driver keeps count/sum/mean consistent across rating writers.
DROP TRIGGER IF EXISTS update_driver_avg_rating;
DROP TRIGGER IF EXISTS rating_after_update;
DROP TRIGGER IF EXISTS rating_after_delete;
DROP TRIGGER IF EXISTS rating_before_insert;
DROP TRIGGER IF EXISTS rating_before_update;
DROP TRIGGER IF EXISTS assignment_before_update;
DROP TRIGGER IF EXISTS assignment_before_insert;
DROP TRIGGER IF EXISTS payment_before_insert;
DROP TRIGGER IF EXISTS payment_before_update;
DROP TRIGGER IF EXISTS order_before_update;
DROP TRIGGER IF EXISTS assignment_before_delete;
DROP TRIGGER IF EXISTS payment_before_delete;
DROP TRIGGER IF EXISTS custody_before_insert;
DROP TRIGGER IF EXISTS custody_before_update;
DROP TRIGGER IF EXISTS reimbursement_before_insert;
DROP TRIGGER IF EXISTS reimbursement_before_update;

DELIMITER $$
CREATE TRIGGER rating_before_insert BEFORE INSERT ON Rating FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Assignment WHERE assignment_id=NEW.assignment_id AND outcome='successful' AND end_time <= NEW.rated_at) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rating requires a successful assignment ended by rated_at';
    END IF;
END$$
CREATE TRIGGER rating_before_update BEFORE UPDATE ON Rating FOR EACH ROW
BEGIN
    IF NEW.assignment_id <> OLD.assignment_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rating assignment identity is immutable';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Assignment WHERE assignment_id=NEW.assignment_id AND outcome='successful' AND end_time <= NEW.rated_at) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rating cannot precede service completion';
    END IF;
END$$
CREATE TRIGGER update_driver_avg_rating AFTER INSERT ON Rating FOR EACH ROW
BEGIN
    -- MySQL single-table UPDATE evaluates assignments left-to-right.
    UPDATE Driver SET rating_sum=rating_sum+NEW.stars, rating_count=rating_count+1,
        avg_rating=ROUND(rating_sum/rating_count,2)
    WHERE driver_id=(SELECT driver_id FROM Assignment WHERE assignment_id=NEW.assignment_id);
END$$
CREATE TRIGGER rating_after_update AFTER UPDATE ON Rating FOR EACH ROW
BEGIN
    UPDATE Driver SET rating_sum=rating_sum+NEW.stars-OLD.stars,
        avg_rating=ROUND(rating_sum/rating_count,2)
    WHERE driver_id=(SELECT driver_id FROM Assignment WHERE assignment_id=NEW.assignment_id);
END$$
CREATE TRIGGER rating_after_delete AFTER DELETE ON Rating FOR EACH ROW
BEGIN
    UPDATE Driver SET rating_sum=rating_sum-OLD.stars, rating_count=rating_count-1,
        avg_rating=IF(rating_count=0,NULL,ROUND(rating_sum/NULLIF(rating_count,0),2))
    WHERE driver_id=(SELECT driver_id FROM Assignment WHERE assignment_id=OLD.assignment_id);
END$$
CREATE TRIGGER assignment_before_insert BEFORE INSERT ON Assignment FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM `order` WHERE order_id=NEW.order_id AND request_time <= NEW.assign_time) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Assignment cannot precede order request';
    END IF;
    IF NEW.outcome='successful' AND NOT EXISTS
       (SELECT 1 FROM `order` WHERE order_id=NEW.order_id AND status='completed' AND completed_at=NEW.end_time) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Successful service must match order completion';
    END IF;
END$$
CREATE TRIGGER assignment_before_update BEFORE UPDATE ON Assignment FOR EACH ROW
BEGIN
    IF OLD.outcome='successful' AND
       (NEW.assignment_id <> OLD.assignment_id OR NEW.driver_id <> OLD.driver_id OR NEW.order_id <> OLD.order_id OR
        NEW.outcome <> OLD.outcome OR NEW.assign_time <> OLD.assign_time OR
        NOT (NEW.start_time <=> OLD.start_time) OR NOT (NEW.end_time <=> OLD.end_time)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Successful service identity and timestamps are immutable';
    END IF;
    IF EXISTS (SELECT 1 FROM Rating WHERE assignment_id=OLD.assignment_id) AND
       (NEW.driver_id <> OLD.driver_id OR NEW.order_id <> OLD.order_id OR NEW.outcome <> OLD.outcome OR NOT (NEW.end_time <=> OLD.end_time)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rated service identity and completion are immutable';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM `order` WHERE order_id=NEW.order_id AND request_time <= NEW.assign_time) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Assignment cannot precede order request';
    END IF;
    IF NEW.outcome='successful' AND NOT EXISTS
       (SELECT 1 FROM `order` WHERE order_id=NEW.order_id AND status='completed' AND completed_at=NEW.end_time) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Successful service must match order completion';
    END IF;
    IF EXISTS (SELECT 1 FROM ParkingCustody WHERE assignment_id=OLD.assignment_id AND check_in_time<NEW.assign_time) OR
       EXISTS (SELECT 1 FROM Reimbursement WHERE assignment_id=OLD.assignment_id AND submit_time<NEW.assign_time) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Assignment cannot follow dependent event';
    END IF;
END$$
CREATE TRIGGER assignment_before_delete BEFORE DELETE ON Assignment FOR EACH ROW
BEGIN
    IF OLD.outcome='successful' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Completed successful service cannot be erased';
    END IF;
END$$
CREATE TRIGGER order_before_update BEFORE UPDATE ON `order` FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM Assignment WHERE order_id=OLD.order_id) AND
       (NEW.order_id <> OLD.order_id OR NEW.customer_id <> OLD.customer_id OR NEW.vehicle_id <> OLD.vehicle_id OR
        NEW.request_time <> OLD.request_time OR NEW.scheduled_start <> OLD.scheduled_start) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Assigned order identity and request schedule are immutable';
    END IF;
    IF EXISTS (SELECT 1 FROM Assignment WHERE order_id=OLD.order_id AND outcome='successful') AND
       (NEW.status <> OLD.status OR NOT (NEW.completed_at <=> OLD.completed_at)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Completed order must retain successful service time';
    END IF;
    IF EXISTS (SELECT 1 FROM Payment WHERE order_id=OLD.order_id AND payment_time<NEW.request_time) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Request cannot follow recorded settlement';
    END IF;
END$$
CREATE TRIGGER payment_before_insert BEFORE INSERT ON Payment FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM `order` WHERE order_id=NEW.order_id AND (NEW.payment_time IS NULL OR request_time <= NEW.payment_time)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Settlement cannot precede order request';
    END IF;
END$$
CREATE TRIGGER payment_before_update BEFORE UPDATE ON Payment FOR EACH ROW
BEGIN
    IF NEW.payment_id <> OLD.payment_id OR NEW.order_id <> OLD.order_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Payment identity is immutable';
    END IF;
    IF OLD.payment_time IS NOT NULL AND
       (NOT (NEW.payment_time <=> OLD.payment_time) OR NOT (NEW.final_fee <=> OLD.final_fee)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Recorded settlement time and amount are immutable';
    END IF;
    IF OLD.refund_time IS NOT NULL AND
       (NOT (NEW.refund_time <=> OLD.refund_time) OR NEW.refund_amount <> OLD.refund_amount) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Recorded refund time and amount are immutable';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM `order` WHERE order_id=NEW.order_id AND (NEW.payment_time IS NULL OR request_time <= NEW.payment_time)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Settlement cannot precede order request';
    END IF;
END$$
CREATE TRIGGER payment_before_delete BEFORE DELETE ON Payment FOR EACH ROW
BEGIN
    IF OLD.payment_time IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Recorded settlement cannot be erased';
    END IF;
END$$
CREATE TRIGGER custody_before_insert BEFORE INSERT ON ParkingCustody FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Assignment WHERE assignment_id=NEW.assignment_id AND assign_time<=NEW.check_in_time) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Custody cannot precede assignment';
    END IF;
END$$
CREATE TRIGGER custody_before_update BEFORE UPDATE ON ParkingCustody FOR EACH ROW
BEGIN
    IF NEW.assignment_id <> OLD.assignment_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Custody assignment identity is immutable';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Assignment WHERE assignment_id=NEW.assignment_id AND assign_time<=NEW.check_in_time) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Custody cannot precede assignment';
    END IF;
END$$
CREATE TRIGGER reimbursement_before_insert BEFORE INSERT ON Reimbursement FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Assignment WHERE assignment_id=NEW.assignment_id AND assign_time<=NEW.submit_time) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Reimbursement cannot precede assignment';
    END IF;
END$$
CREATE TRIGGER reimbursement_before_update BEFORE UPDATE ON Reimbursement FOR EACH ROW
BEGIN
    IF NEW.assignment_id <> OLD.assignment_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Reimbursement assignment identity is immutable';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Assignment WHERE assignment_id=NEW.assignment_id AND assign_time<=NEW.submit_time) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Reimbursement cannot precede assignment';
    END IF;
END$$
DELIMITER ;
