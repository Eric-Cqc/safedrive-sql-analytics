-- SafeDrive SQL Analytics: deterministic structural, fixture, and trigger assertions

DROP PROCEDURE IF EXISTS run_safedrive_assertions;

DELIMITER $$

CREATE PROCEDURE run_safedrive_assertions()
BEGIN
    DECLARE v_count INT DEFAULT 0;
    DECLARE v_avg DECIMAL(3,2) DEFAULT 0.00;
    DECLARE v_after DECIMAL(3,2) DEFAULT 0.00;

    SELECT COUNT(*)
      INTO v_count
      FROM information_schema.tables
     WHERE table_schema = DATABASE()
       AND table_type = 'BASE TABLE'
       AND table_name IN (
           'Customer', 'Brandmodel', 'Vehicle', 'order', 'Driver',
           'Assignment', 'Rating', 'Payment', 'Incident',
           'ParkingCustody', 'Reimbursement'
       );
    IF v_count <> 11 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Expected all eleven project tables';
    END IF;

    SELECT COUNT(*) INTO v_count FROM Customer;
    IF v_count <> 6 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unexpected Customer fixture count';
    END IF;

    SELECT COUNT(*) INTO v_count FROM Brandmodel;
    IF v_count <> 8 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unexpected Brandmodel fixture count';
    END IF;

    SELECT COUNT(*) INTO v_count FROM Vehicle;
    IF v_count <> 8 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unexpected Vehicle fixture count';
    END IF;

    SELECT COUNT(*) INTO v_count FROM `order`;
    IF v_count <> 15 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unexpected order fixture count';
    END IF;

    SELECT COUNT(*) INTO v_count FROM Driver;
    IF v_count <> 6 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unexpected Driver fixture count';
    END IF;

    SELECT COUNT(*) INTO v_count FROM Assignment;
    IF v_count <> 12 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unexpected Assignment fixture count';
    END IF;

    SELECT COUNT(*) INTO v_count FROM Rating;
    IF v_count <> 10 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unexpected Rating fixture count';
    END IF;

    SELECT COUNT(*) INTO v_count FROM Payment;
    IF v_count <> 13 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unexpected Payment fixture count';
    END IF;

    SELECT COUNT(*) INTO v_count FROM Incident;
    IF v_count <> 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unexpected Incident fixture count';
    END IF;

    SELECT COUNT(*) INTO v_count FROM ParkingCustody;
    IF v_count <> 9 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unexpected ParkingCustody fixture count';
    END IF;

    SELECT COUNT(*) INTO v_count FROM Reimbursement;
    IF v_count <> 4 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unexpected Reimbursement fixture count';
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM Customer
     WHERE phone NOT REGEXP '^555-01[0-9]{2}$';
    IF v_count <> 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer phone fixture is not synthetic';
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM Driver
     WHERE phone NOT REGEXP '^555-01[0-9]{2}$';
    IF v_count <> 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Driver phone fixture is not synthetic';
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM `order`
     WHERE request_time > TIMESTAMP('2025-11-15 12:00:00');
    IF v_count <> 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fixture contains a timestamp after as_of';
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM information_schema.TRIGGERS
     WHERE TRIGGER_SCHEMA = DATABASE()
       AND TRIGGER_NAME = 'update_driver_avg_rating';
    IF v_count <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Expected idempotent rating trigger';
    END IF;

    SELECT avg_rating INTO v_avg FROM Driver WHERE driver_id = 1;
    IF v_avg <> 4.50 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Driver 001 trigger average mismatch';
    END IF;
    SELECT avg_rating INTO v_avg FROM Driver WHERE driver_id = 2;
    IF v_avg <> 4.00 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Driver 002 trigger average mismatch';
    END IF;
    SELECT avg_rating INTO v_avg FROM Driver WHERE driver_id = 3;
    IF v_avg <> 4.50 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Driver 003 trigger average mismatch';
    END IF;
    SELECT avg_rating INTO v_avg FROM Driver WHERE driver_id = 4;
    IF v_avg <> 5.00 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Driver 004 trigger average mismatch';
    END IF;
    SELECT avg_rating INTO v_avg FROM Driver WHERE driver_id = 5;
    IF v_avg <> 3.50 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Driver 005 trigger average mismatch';
    END IF;
    SELECT avg_rating INTO v_avg FROM Driver WHERE driver_id = 6;
    IF v_avg <> 4.00 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Driver 006 trigger average mismatch';
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM `order` AS o
      JOIN Payment AS p ON p.order_id = o.order_id
     WHERE o.status = 'completed'
       AND p.status = 'pending'
       AND o.request_time >= DATE_SUB(TIMESTAMP('2025-11-15 12:00:00'), INTERVAL 7 DAY)
       AND o.request_time <= DATE_SUB(TIMESTAMP('2025-11-15 12:00:00'), INTERVAL 24 HOUR)
       AND o.request_time <= TIMESTAMP('2025-11-15 12:00:00');
    IF v_count <> 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Scenario 10 rolling-window boundary mismatch';
    END IF;

    START TRANSACTION;
    INSERT INTO Rating (rating_id, assignment_id, stars, content)
    VALUES (99, 10, 5, 'Rollback-scoped trigger assertion.');
    SELECT avg_rating INTO v_after FROM Driver WHERE driver_id = 6;
    IF v_after <> 4.50 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Rating insert did not update driver average';
    END IF;
    ROLLBACK;

    SELECT COUNT(*) INTO v_count FROM Rating WHERE assignment_id = 10;
    IF v_count <> 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Trigger assertion insert was not rolled back';
    END IF;
END$$

DELIMITER ;

CALL run_safedrive_assertions();
DROP PROCEDURE IF EXISTS run_safedrive_assertions;
SELECT 'ASSERTIONS_PASS' AS status;
