-- SafeDrive SQL Analytics: idempotent trigger definition
-- Re-running this file replaces only this project trigger in the selected database.

DROP TRIGGER IF EXISTS update_driver_avg_rating;

DELIMITER $$

CREATE TRIGGER update_driver_avg_rating
AFTER INSERT ON Rating
FOR EACH ROW
BEGIN
    DECLARE v_driver_id INT;

    SELECT a.driver_id
      INTO v_driver_id
      FROM Assignment AS a
     WHERE a.assignment_id = NEW.assignment_id;

    UPDATE Driver
       SET avg_rating = COALESCE(
           (SELECT ROUND(AVG(r.stars), 2)
              FROM Rating AS r
              JOIN Assignment AS a2
                ON a2.assignment_id = r.assignment_id
             WHERE a2.driver_id = v_driver_id),
           0.00)
     WHERE driver_id = v_driver_id;
END$$

DELIMITER ;
