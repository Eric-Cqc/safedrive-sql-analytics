-- SafeDrive SQL Analytics: schema
-- Run this file after selecting the caller's database with mysql --database=DB.
-- It deliberately does not CREATE or USE a database.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TRIGGER IF EXISTS update_driver_avg_rating;

DROP TABLE IF EXISTS Reimbursement;
DROP TABLE IF EXISTS ParkingCustody;
DROP TABLE IF EXISTS Incident;
DROP TABLE IF EXISTS Payment;
DROP TABLE IF EXISTS Rating;
DROP TABLE IF EXISTS Assignment;
DROP TABLE IF EXISTS `order`;
DROP TABLE IF EXISTS Vehicle;
DROP TABLE IF EXISTS Driver;
DROP TABLE IF EXISTS Brandmodel;
DROP TABLE IF EXISTS Customer;

SET FOREIGN_KEY_CHECKS = 1;

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
    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
    CONSTRAINT fk_order_vehicle
        FOREIGN KEY (vehicle_id) REFERENCES Vehicle(vehicle_id)
) ENGINE = InnoDB;

CREATE TABLE Driver (
    driver_id INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    cert_id VARCHAR(50) NOT NULL UNIQUE,
    status ENUM('active', 'suspended') NOT NULL,
    avg_rating DECIMAL(3,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT chk_driver_avg_rating CHECK (avg_rating BETWEEN 0.00 AND 5.00)
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
    CONSTRAINT fk_reimbursement_assignment
        FOREIGN KEY (assignment_id) REFERENCES Assignment(assignment_id)
) ENGINE = InnoDB;
