-- Live MySQL assertions. All mutation probes roll back; no business database is involved.
DROP PROCEDURE IF EXISTS run_safedrive_assertions;
DELIMITER $$
CREATE PROCEDURE run_safedrive_assertions()
BEGIN
 DECLARE n INT DEFAULT 0;
 DECLARE rejected BOOLEAN DEFAULT FALSE;
 IF (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_type='BASE TABLE')<>11 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Expected eleven tables';
 END IF;
 IF (SELECT COUNT(*) FROM `order`)<>33 OR (SELECT COUNT(*) FROM Rating)<>13 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fixture row count mismatch';
 END IF;
 SELECT COUNT(*) INTO n FROM Driver d LEFT JOIN (
  SELECT a.driver_id,COUNT(*) cnt,SUM(r.stars) total,ROUND(AVG(r.stars),2) mean
  FROM Rating r JOIN Assignment a ON a.assignment_id=r.assignment_id GROUP BY a.driver_id
 ) r ON r.driver_id=d.driver_id
 WHERE d.rating_count<>COALESCE(r.cnt,0) OR d.rating_sum<>COALESCE(r.total,0) OR NOT(d.avg_rating<=>r.mean);
 IF n<>0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Current trigger summaries differ from ratings'; END IF;
 SELECT COUNT(*) INTO n FROM `order` o LEFT JOIN Assignment a ON a.order_id=o.order_id AND a.outcome='successful'
 WHERE o.completed_at IS NOT NULL AND (a.assignment_id IS NULL OR a.end_time<>o.completed_at);
 IF n<>0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Completed order and successful assignment disagree'; END IF;
 IF (SELECT COUNT(*) FROM Incident WHERE order_id=2 AND severity>=4)<>2 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Duplicate-incident scenario missing';
 END IF;
 START TRANSACTION;
 INSERT INTO Rating (rating_id,assignment_id,stars,content,rated_at) VALUES (999,10,5,'Rollback test.','2025-11-14 00:00:00');
 IF (SELECT avg_rating FROM Driver WHERE driver_id=6)<>4.50 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Insert trigger failed';
 END IF;
 UPDATE Rating SET stars=1 WHERE rating_id=999;
 IF (SELECT avg_rating FROM Driver WHERE driver_id=6)<>2.50 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Update trigger failed';
 END IF;
 DELETE FROM Rating WHERE rating_id=999;
 IF (SELECT avg_rating FROM Driver WHERE driver_id=6)<>4.00 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Delete trigger failed';
 END IF;
 DELETE FROM Rating WHERE rating_id=9;
 IF (SELECT avg_rating FROM Driver WHERE driver_id=6) IS NOT NULL OR (SELECT rating_count FROM Driver WHERE driver_id=6)<>0 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Empty-rating summary must be NULL';
 END IF;
 ROLLBACK;
 START TRANSACTION;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE Assignment SET odometer_after=odometer_before-1 WHERE assignment_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Negative distance accepted'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE Assignment SET odometer_after=NULL WHERE assignment_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Half-missing odometer accepted'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE `order` SET vehicle_id=3 WHERE order_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Wrong vehicle owner accepted'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE Payment SET refund_amount=999,refund_time='2025-11-15 00:00:00',status='refunded' WHERE payment_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Excess refund accepted'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE Payment SET payment_time=NULL WHERE payment_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Paid without settlement time accepted'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE Rating SET rated_at='2025-11-01 00:00:00' WHERE rating_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rating before completion accepted'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE Assignment SET driver_id=2 WHERE assignment_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rated assignment identity changed'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE Assignment SET end_time='2025-11-10 17:00:00' WHERE assignment_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Impossible assignment time accepted'; END IF;
 -- Additional guards; execute through the guarded verifier and retain its source hashes.
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE Driver SET avg_rating=NULL WHERE driver_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Nonempty rating summary accepted NULL'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE Assignment SET end_time=DATE_ADD(end_time,INTERVAL 1 SECOND) WHERE assignment_id=31;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unrated successful completion changed'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  DELETE FROM Assignment WHERE assignment_id=31;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Successful service erased'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE `order` SET completed_at=DATE_ADD(completed_at,INTERVAL 1 SECOND) WHERE order_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Order and assignment completion diverged'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE `order` SET request_time=DATE_SUB(request_time,INTERVAL 1 SECOND) WHERE order_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Assigned request clock changed'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE Payment SET final_fee=final_fee+1 WHERE payment_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Recorded settlement amount changed'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE Payment SET payment_time=DATE_ADD(payment_time,INTERVAL 1 SECOND) WHERE payment_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Recorded settlement time changed'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  DELETE FROM Payment WHERE payment_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Recorded settlement erased'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE Payment SET refund_amount=1 WHERE order_id=23;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Recorded full refund changed'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE ParkingCustody SET check_in_time='2025-11-01 00:00:00' WHERE custody_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Custody preceded assignment'; END IF;
 SET rejected=FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET rejected=TRUE;
  UPDATE Reimbursement SET submit_time='2025-11-01 00:00:00' WHERE reimbursement_id=1;
 END;
 IF NOT rejected THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Reimbursement preceded assignment'; END IF;
 -- Positive controls: guards must still allow valid next events and unknown km.
 UPDATE Payment SET final_fee=final_fee WHERE payment_id=1;
 UPDATE Payment SET status='refunded',refund_amount=10,refund_time='2025-11-15 13:00:00' WHERE payment_id=1;
 UPDATE Payment SET status='paid',final_fee=100,payment_time='2025-11-15 13:00:00' WHERE payment_id=10;
 UPDATE Assignment SET odometer_before=NULL,odometer_after=NULL WHERE assignment_id=31;
 UPDATE ParkingCustody SET check_out_time=NULL WHERE custody_id=1;
 ROLLBACK;
 IF (SELECT status FROM Payment WHERE payment_id=1)<>'paid' OR (SELECT refund_amount FROM Payment WHERE payment_id=1)<>0 OR (SELECT status FROM Payment WHERE payment_id=10)<>'pending' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rollback did not restore payment facts';
 END IF;
 IF (SELECT avg_rating FROM Driver WHERE driver_id=6)<>4.00 OR (SELECT COUNT(*) FROM Rating)<>13 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rollback did not restore fixture';
 END IF;
END$$
DELIMITER ;
CALL run_safedrive_assertions();
DROP PROCEDURE run_safedrive_assertions;
SELECT 'ASSERTIONS_PASS' AS status;
