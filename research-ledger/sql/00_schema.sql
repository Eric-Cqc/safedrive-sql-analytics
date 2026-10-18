-- Fresh, caller-selected disposable synthetic schema only. Never drops existing tables.
SET NAMES utf8mb4;
SET time_zone = '+08:00';

CREATE TABLE Customer (
    customer_id INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    license_number VARCHAR(50) NOT NULL UNIQUE,
    membership_tier ENUM('normal', 'corporate', 'VIP') NOT NULL
) ENGINE = InnoDB;

CREATE TABLE Brandmodel (
    id INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    parent_id INT NULL,
    CONSTRAINT fk_brandmodel_parent
        FOREIGN KEY (parent_id) REFERENCES Brandmodel(id)
) ENGINE = InnoDB;

CREATE TABLE Vehicle (
    vehicle_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    plate_no VARCHAR(30) NOT NULL UNIQUE,
    model_id INT NOT NULL,
    `year` YEAR NOT NULL,
    color VARCHAR(20) NOT NULL,
    insurance VARCHAR(80) NOT NULL,
    registered_at DATETIME NOT NULL,
    UNIQUE KEY uq_vehicle_owner (vehicle_id, customer_id),
    CONSTRAINT fk_vehicle_customer
        FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
    CONSTRAINT fk_vehicle_model
        FOREIGN KEY (model_id) REFERENCES Brandmodel(id)
) ENGINE = InnoDB;

CREATE TABLE `order` (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    vehicle_id INT NOT NULL,
    pickup_location VARCHAR(255) NOT NULL,
    dropoff_location VARCHAR(255) NOT NULL,
    request_time DATETIME NOT NULL,
    scheduled_start DATETIME NOT NULL,
    service_type ENUM('drive_now', 'next_day', 'overnight') NOT NULL,
    status ENUM('pending', 'assigned', 'cancelled', 'completed') NOT NULL,
    completed_at DATETIME NULL,
    cancelled_at DATETIME NULL,
    KEY ix_order_completed (completed_at, customer_id),
    KEY ix_order_request (request_time, customer_id),
    CONSTRAINT chk_order_times CHECK (scheduled_start >= request_time AND (completed_at IS NULL OR completed_at >= scheduled_start) AND (cancelled_at IS NULL OR cancelled_at >= request_time)),
    CONSTRAINT chk_order_state CHECK ((status = 'completed') = (completed_at IS NOT NULL) AND (status = 'cancelled') = (cancelled_at IS NOT NULL)),
    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
    CONSTRAINT fk_order_vehicle
        FOREIGN KEY (vehicle_id, customer_id) REFERENCES Vehicle(vehicle_id, customer_id)
) ENGINE = InnoDB;

CREATE TABLE Driver (
    driver_id INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    cert_id VARCHAR(50) NOT NULL UNIQUE,
    status ENUM('active', 'suspended') NOT NULL,
    avg_rating DECIMAL(3,2) NULL DEFAULT NULL,
    rating_count INT NOT NULL DEFAULT 0,
    rating_sum INT NOT NULL DEFAULT 0,
    CONSTRAINT chk_driver_avg_rating CHECK ((rating_count = 0 AND rating_sum = 0 AND avg_rating IS NULL) OR (rating_count > 0 AND rating_sum BETWEEN rating_count AND rating_count * 5 AND avg_rating IS NOT NULL AND avg_rating = ROUND(rating_sum / rating_count, 2)))
) ENGINE = InnoDB;

CREATE TABLE Assignment (
    assignment_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    driver_id INT NOT NULL,
    assign_time DATETIME NOT NULL,
    start_time DATETIME NULL,
    end_time DATETIME NULL,
    odometer_before INT NULL,
    odometer_after INT NULL,
    vehicle_condition_before TEXT NULL,
    vehicle_condition_after TEXT NULL,
    outcome ENUM('successful', 'customer no-show', 'refused') NOT NULL,
    successful_order_id INT GENERATED ALWAYS AS (CASE WHEN outcome = 'successful' THEN order_id ELSE NULL END) STORED,
    UNIQUE KEY uq_successful_order (successful_order_id),
    KEY ix_driver_start (driver_id, start_time),
    CONSTRAINT chk_assignment_times CHECK ((start_time IS NULL OR start_time >= assign_time) AND (end_time IS NULL OR (start_time IS NOT NULL AND end_time >= start_time)) AND (outcome <> 'successful' OR (start_time IS NOT NULL AND end_time IS NOT NULL))),
    CONSTRAINT chk_assignment_odometer CHECK (
        (odometer_before IS NULL AND odometer_after IS NULL)
        OR (odometer_before IS NOT NULL AND odometer_after IS NOT NULL AND odometer_before >= 0 AND odometer_after >= odometer_before)
    ),
    CONSTRAINT fk_assignment_order
        FOREIGN KEY (order_id) REFERENCES `order`(order_id),
    CONSTRAINT fk_assignment_driver
        FOREIGN KEY (driver_id) REFERENCES Driver(driver_id)
) ENGINE = InnoDB;

CREATE TABLE Rating (
    rating_id INT PRIMARY KEY,
    assignment_id INT NOT NULL UNIQUE,
    stars INT NOT NULL,
    content TEXT NULL,
    rated_at DATETIME NOT NULL,
    KEY ix_rating_time (rated_at),
    CONSTRAINT chk_rating_stars CHECK (stars BETWEEN 1 AND 5),
    CONSTRAINT fk_rating_assignment
        FOREIGN KEY (assignment_id) REFERENCES Assignment(assignment_id)
) ENGINE = InnoDB;

CREATE TABLE Payment (
    payment_id INT PRIMARY KEY,
    order_id INT NOT NULL UNIQUE,
    quoted_fee DECIMAL(10,2) NOT NULL,
    final_fee DECIMAL(10,2) NULL,
    method ENUM('credit card', 'corporate invoice', 'cash') NOT NULL,
    payment_time DATETIME NULL,
    status ENUM('pending', 'paid', 'refunded') NOT NULL,
    refund_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    refund_time DATETIME NULL,
    KEY ix_payment_time (payment_time),
    KEY ix_refund_time (refund_time),
    CONSTRAINT chk_payment_amounts CHECK (quoted_fee >= 0 AND (final_fee IS NULL OR final_fee >= 0) AND refund_amount >= 0 AND (refund_amount = 0 OR (final_fee IS NOT NULL AND refund_amount <= final_fee))),
    CONSTRAINT chk_payment_state CHECK ((status = 'pending' AND final_fee IS NULL AND payment_time IS NULL AND refund_amount = 0 AND refund_time IS NULL) OR (status = 'paid' AND final_fee IS NOT NULL AND payment_time IS NOT NULL AND refund_amount = 0 AND refund_time IS NULL) OR (status = 'refunded' AND final_fee IS NOT NULL AND payment_time IS NOT NULL AND refund_amount > 0 AND refund_time IS NOT NULL AND refund_time >= payment_time)),
    CONSTRAINT fk_payment_order
        FOREIGN KEY (order_id) REFERENCES `order`(order_id)
) ENGINE = InnoDB;

CREATE TABLE Incident (
    incident_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    reporter ENUM('customer', 'driver') NOT NULL,
    category ENUM('unsafe driving', 'vehicle damage', 'payment dispute', 'harassment') NOT NULL,
    description TEXT NOT NULL,
    severity INT NOT NULL,
    resolution TEXT NOT NULL,
    recorded_at DATETIME NOT NULL,
    KEY ix_incident_time (recorded_at, order_id),
    CONSTRAINT chk_incident_severity CHECK (severity BETWEEN 1 AND 5),
    CONSTRAINT fk_incident_order
        FOREIGN KEY (order_id) REFERENCES `order`(order_id)
) ENGINE = InnoDB;

CREATE TABLE ParkingCustody (
    custody_id INT PRIMARY KEY,
    assignment_id INT NOT NULL,
    partner_name VARCHAR(100) NOT NULL,
    check_in_time DATETIME NOT NULL,
    check_out_time DATETIME NULL,
    liability_limit DECIMAL(10,2) NOT NULL,
    fee DECIMAL(10,2) NULL,
    CONSTRAINT chk_custody CHECK (liability_limit >= 0 AND (fee IS NULL OR fee >= 0) AND (check_out_time IS NULL OR check_out_time >= check_in_time)),
    CONSTRAINT fk_custody_assignment
        FOREIGN KEY (assignment_id) REFERENCES Assignment(assignment_id)
) ENGINE = InnoDB;

CREATE TABLE Reimbursement (
    reimbursement_id INT PRIMARY KEY,
    assignment_id INT NOT NULL,
    transport_mode ENUM('taxi', 'metro', 'company shuttle') NOT NULL,
    claimed_amount DECIMAL(10,2) NOT NULL,
    status ENUM('submitted', 'approved', 'rejected') NOT NULL,
    submit_time DATETIME NOT NULL,
    approve_time DATETIME NULL,
    CONSTRAINT chk_reimbursement CHECK (claimed_amount >= 0 AND (approve_time IS NULL OR approve_time >= submit_time) AND (status <> 'approved' OR approve_time IS NOT NULL)),
    CONSTRAINT fk_reimbursement_assignment
        FOREIGN KEY (assignment_id) REFERENCES Assignment(assignment_id)
) ENGINE = InnoDB;
