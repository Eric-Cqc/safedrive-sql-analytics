-- SafeDrive SQL Analytics: fully synthetic seed data
-- All timestamps are bounded by the fixed project as_of: 2025-11-15 12:00:00.
-- Load after 00_schema.sql and 20_trigger.sql so Driver.avg_rating is trigger-maintained.

SET NAMES utf8mb4;
START TRANSACTION;

INSERT INTO Customer (customer_id, name, phone, license_number, membership_tier) VALUES
    (1, 'Customer 001', '555-0101', 'TEST-CUST-001', 'VIP'),
    (2, 'Customer 002', '555-0102', 'TEST-CUST-002', 'normal'),
    (3, 'Customer 003', '555-0103', 'TEST-CUST-003', 'corporate'),
    (4, 'Customer 004', '555-0104', 'TEST-CUST-004', 'VIP'),
    (5, 'Customer 005', '555-0105', 'TEST-CUST-005', 'normal'),
    (6, 'Customer 006', '555-0106', 'TEST-CUST-006', 'corporate');

INSERT INTO Brandmodel (id, name, parent_id) VALUES
    (1, 'Brand Alpha', NULL),
    (2, 'Brand Beta', NULL),
    (3, 'Brand Gamma', NULL);

INSERT INTO Brandmodel (id, name, parent_id) VALUES
    (4, 'Model Alpha One', 1),
    (5, 'Model Alpha Two', 1),
    (6, 'Model Beta One', 2),
    (7, 'Model Beta Two', 2),
    (8, 'Model Gamma One', 3);

INSERT INTO Vehicle
    (vehicle_id, customer_id, plate_no, model_id, `year`, color, insurance)
VALUES
    (1, 1, 'TEST-PLATE-001', 4, 2021, 'Silver', 'TEST-POLICY-001'),
    (2, 1, 'TEST-PLATE-002', 5, 2022, 'Blue', 'TEST-POLICY-002'),
    (3, 2, 'TEST-PLATE-003', 6, 2020, 'Gray', 'TEST-POLICY-003'),
    (4, 2, 'TEST-PLATE-004', 7, 2019, 'White', 'TEST-POLICY-004'),
    (5, 3, 'TEST-PLATE-005', 8, 2023, 'Black', 'TEST-POLICY-005'),
    (6, 4, 'TEST-PLATE-006', 4, 2021, 'Red', 'TEST-POLICY-006'),
    (7, 5, 'TEST-PLATE-007', 5, 2020, 'White', 'TEST-POLICY-007'),
    (8, 6, 'TEST-PLATE-008', 6, 2022, 'Green', 'TEST-POLICY-008');

INSERT INTO Driver (driver_id, name, phone, cert_id, status, avg_rating) VALUES
    (1, 'Driver 001', '555-0107', 'TEST-LIC-001', 'active', 0.00),
    (2, 'Driver 002', '555-0108', 'TEST-LIC-002', 'active', 0.00),
    (3, 'Driver 003', '555-0109', 'TEST-LIC-003', 'active', 0.00),
    (4, 'Driver 004', '555-0110', 'TEST-LIC-004', 'active', 0.00),
    (5, 'Driver 005', '555-0111', 'TEST-LIC-005', 'active', 0.00),
    (6, 'Driver 006', '555-0112', 'TEST-LIC-006', 'active', 0.00);

INSERT INTO `order`
    (order_id, customer_id, vehicle_id, pickup_location, dropoff_location,
     request_time, scheduled_start, service_type, status)
VALUES
    (1, 1, 1, 'Zone A Gate', 'Zone B Hub',
        '2025-11-10 17:50:00', '2025-11-10 18:00:00', 'drive_now', 'completed'),
    (2, 1, 2, 'Zone B Gate', 'Zone C Hub',
        '2025-11-12 20:00:00', '2025-11-12 20:30:00', 'overnight', 'completed'),
    (3, 1, 1, 'Zone A Gate', 'Zone B Hub',
        '2025-11-14 09:00:00', '2025-11-14 09:30:00', 'next_day', 'completed'),
    (4, 2, 3, 'Zone C Gate', 'Zone D Hub',
        '2025-11-11 16:00:00', '2025-11-11 18:00:00', 'overnight', 'completed'),
    (5, 2, 4, 'Zone B Gate', 'Zone C Hub',
        '2025-11-13 07:30:00', '2025-11-13 08:00:00', 'drive_now', 'completed'),
    (6, 2, 3, 'Zone B Gate', 'Zone D Hub',
        '2025-11-14 22:00:00', '2025-11-14 22:30:00', 'overnight', 'completed'),
    (7, 3, 5, 'Zone A Gate', 'Zone C Hub',
        '2025-11-05 12:00:00', '2025-11-05 13:00:00', 'next_day', 'completed'),
    (8, 3, 5, 'Zone C Gate', 'Zone D Hub',
        '2025-11-14 10:00:00', '2025-11-14 10:30:00', 'drive_now', 'completed'),
    (9, 4, 6, 'Zone D Gate', 'Zone E Hub',
        '2025-11-08 19:00:00', '2025-11-08 19:30:00', 'overnight', 'completed'),
    (10, 4, 6, 'Zone D Gate', 'Zone F Hub',
        '2025-11-13 21:00:00', '2025-11-13 21:30:00', 'drive_now', 'completed'),
    (11, 5, 7, 'Zone E Gate', 'Zone F Hub',
        '2025-11-07 18:00:00', '2025-11-07 18:30:00', 'next_day', 'completed'),
    (12, 5, 7, 'Zone E Gate', 'Zone G Hub',
        '2025-11-13 08:00:00', '2025-11-13 08:30:00', 'drive_now', 'assigned'),
    (13, 6, 8, 'Zone F Gate', 'Zone G Hub',
        '2025-11-14 08:00:00', '2025-11-14 08:30:00', 'overnight', 'completed'),
    (14, 6, 8, 'Zone F Gate', 'Zone H Hub',
        '2025-11-14 23:00:00', '2025-11-14 23:30:00', 'drive_now', 'pending'),
    (15, 2, 3, 'Zone B Gate', 'Zone A Hub',
        '2025-11-04 10:00:00', '2025-11-04 11:00:00', 'overnight', 'cancelled');

INSERT INTO Assignment
    (assignment_id, order_id, driver_id, assign_time, start_time, end_time,
     odometer_before, odometer_after, vehicle_condition_before,
     vehicle_condition_after, outcome)
VALUES
    (1, 1, 1, '2025-11-10 17:55:00', '2025-11-10 18:08:00', '2025-11-10 18:50:00',
        10000, 10042, 'No visible issues.', 'No visible issues.', 'successful'),
    (2, 2, 1, '2025-11-12 20:10:00', '2025-11-12 20:32:00', '2025-11-12 23:00:00',
        20000, 20120, 'No visible issues.', 'No visible issues.', 'successful'),
    (3, 3, 2, '2025-11-14 09:20:00', '2025-11-14 09:25:00', '2025-11-14 10:45:00',
        30000, 30068, 'No visible issues.', 'No visible issues.', 'successful'),
    (4, 4, 2, '2025-11-11 18:05:00', '2025-11-11 18:20:00', '2025-11-11 19:10:00',
        40000, 40050, 'Minor surface mark recorded.', 'Minor surface mark recorded.', 'successful'),
    (5, 5, 3, '2025-11-13 07:50:00', '2025-11-13 08:10:00', '2025-11-13 09:00:00',
        50000, 50045, 'No visible issues.', 'No visible issues.', 'successful'),
    (6, 6, 3, '2025-11-14 22:20:00', '2025-11-14 22:31:00', '2025-11-14 23:40:00',
        60000, 60072, 'No visible issues.', 'No visible issues.', 'successful'),
    (7, 7, 4, '2025-11-05 12:50:00', '2025-11-05 13:05:00', '2025-11-05 14:15:00',
        70000, 70070, 'No visible issues.', 'No visible issues.', 'successful'),
    (8, 8, 4, '2025-11-14 10:20:00', '2025-11-14 10:45:00', '2025-11-14 11:40:00',
        80000, 80055, 'No visible issues.', 'No visible issues.', 'successful'),
    (9, 9, 5, '2025-11-08 19:20:00', '2025-11-08 19:40:00', '2025-11-08 21:50:00',
        90000, 90110, 'No visible issues.', 'No visible issues.', 'successful'),
    (10, 10, 6, '2025-11-13 21:20:00', '2025-11-13 21:35:00', '2025-11-13 22:30:00',
        100000, 100054, 'No visible issues.', 'No visible issues.', 'successful'),
    (11, 11, 6, '2025-11-07 18:20:00', '2025-11-07 18:40:00', '2025-11-07 19:50:00',
        110000, 11066, 'No visible issues.', 'No visible issues.', 'successful'),
    (12, 13, 5, '2025-11-14 08:20:00', '2025-11-14 08:25:00', '2025-11-14 09:20:00',
        120000, 12055, 'No visible issues.', 'No visible issues.', 'successful');

INSERT INTO Rating (rating_id, assignment_id, stars, content) VALUES
    (1, 1, 5, 'Synthetic rating: clear service.'),
    (2, 2, 4, 'Synthetic rating: dependable service.'),
    (3, 3, 5, 'Synthetic rating: smooth handoff.'),
    (4, 4, 3, 'Synthetic rating: acceptable service.'),
    (5, 5, 4, 'Synthetic rating: timely completion.'),
    (6, 6, 5, 'Synthetic rating: careful completion.'),
    (7, 7, 5, 'Synthetic rating: clear communication.'),
    (8, 9, 4, 'Synthetic rating: steady service.'),
    (9, 11, 4, 'Synthetic rating: reliable completion.'),
    (10, 12, 3, 'Synthetic rating: service completed.');

INSERT INTO Payment
    (payment_id, order_id, quoted_fee, final_fee, method, payment_time, status)
VALUES
    (1, 1, 88.00, 88.00, 'credit card', '2025-11-10 18:51:00', 'paid'),
    (2, 2, 126.00, 126.00, 'credit card', '2025-11-12 23:01:00', 'paid'),
    (3, 3, 72.00, 72.00, 'corporate invoice', '2025-11-14 10:46:00', 'paid'),
    (4, 4, 154.00, 154.00, 'cash', '2025-11-11 19:11:00', 'paid'),
    (5, 5, 66.00, 66.00, 'credit card', '2025-11-13 09:01:00', 'paid'),
    (6, 6, 110.00, 110.00, 'credit card', '2025-11-14 23:41:00', 'paid'),
    (7, 7, 180.00, NULL, 'corporate invoice', NULL, 'pending'),
    (8, 8, 95.00, NULL, 'credit card', NULL, 'pending'),
    (9, 9, 140.00, 140.00, 'credit card', '2025-11-08 21:51:00', 'paid'),
    (10, 10, 108.00, NULL, 'cash', NULL, 'pending'),
    (11, 11, 84.00, 84.00, 'credit card', '2025-11-07 19:51:00', 'paid'),
    (12, 12, 60.00, NULL, 'credit card', NULL, 'pending'),
    (13, 13, 95.00, 95.00, 'corporate invoice', '2025-11-14 09:21:00', 'paid');

INSERT INTO Incident
    (incident_id, order_id, reporter, category, description, severity, resolution)
VALUES
    (1, 1, 'driver', 'unsafe driving', 'Synthetic low-severity review flag.', 2, 'Reviewed with service team.'),
    (2, 2, 'customer', 'unsafe driving', 'Synthetic high-severity safety flag.', 4, 'Safety coaching recorded.'),
    (3, 4, 'customer', 'vehicle damage', 'Synthetic high-severity condition flag.', 5, 'Inspection completed.'),
    (4, 7, 'driver', 'payment dispute', 'Synthetic billing review flag.', 3, 'Billing review opened.'),
    (5, 8, 'customer', 'harassment', 'Synthetic conduct review flag.', 4, 'Case review opened.');

INSERT INTO ParkingCustody
    (custody_id, assignment_id, partner_name, check_in_time, check_out_time, liability_limit, fee)
VALUES
    (1, 1, 'Partner Hub Alpha', '2025-11-10 19:00:00', '2025-11-10 19:20:00', 3000.00, 22.00),
    (2, 3, 'Partner Hub Alpha', '2025-11-14 09:40:00', '2025-11-14 10:00:00', 3000.00, 22.00),
    (3, 7, 'Partner Hub Alpha', '2025-11-05 13:15:00', '2025-11-05 13:35:00', 3000.00, 22.00),
    (4, 2, 'Partner Hub Beta', '2025-11-12 20:40:00', '2025-11-12 21:00:00', 4200.00, 28.00),
    (5, 5, 'Partner Hub Beta', '2025-11-13 08:20:00', '2025-11-13 08:40:00', 4200.00, 28.00),
    (6, 6, 'Partner Hub Beta', '2025-11-14 22:45:00', '2025-11-14 23:05:00', 4200.00, 30.00),
    (7, 4, 'Partner Hub Gamma', '2025-11-11 18:30:00', '2025-11-11 18:50:00', 5200.00, 34.00),
    (8, 8, 'Partner Hub Gamma', '2025-11-14 10:55:00', '2025-11-14 11:15:00', 5200.00, 34.00),
    (9, 9, 'Partner Hub Gamma', '2025-11-08 20:00:00', '2025-11-08 20:20:00', 5200.00, 36.00);

INSERT INTO Reimbursement
    (reimbursement_id, assignment_id, transport_mode, claimed_amount, status, submit_time, approve_time)
VALUES
    (1, 1, 'metro', 12.00, 'approved', '2025-11-10 19:30:00', '2025-11-10 20:00:00'),
    (2, 2, 'taxi', 35.00, 'approved', '2025-11-12 23:10:00', '2025-11-13 09:00:00'),
    (3, 5, 'company shuttle', 18.00, 'submitted', '2025-11-13 09:10:00', NULL),
    (4, 9, 'metro', 10.00, 'approved', '2025-11-08 22:00:00', '2025-11-09 09:00:00');

COMMIT;
