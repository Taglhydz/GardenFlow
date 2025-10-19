-- ==========================
-- GardenFlow Database Schema
-- ==========================

CREATE DATABASE IF NOT EXISTS gardenflow;
USE gardenflow;

-- =====
-- Users
-- =====
CREATE TABLE user (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    email    VARCHAR(150) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
	birthdate DATE,
    role ENUM('user', 'admin') DEFAULT 'user',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL
);

-- =======
-- Gardens
-- =======
CREATE TABLE garden (
    id      INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name     VARCHAR(100),
    location VARCHAR(255),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE
);

-- =======
-- Parcels
-- =======
CREATE TABLE parcel (
    id 		  INT AUTO_INCREMENT PRIMARY KEY,
    garden_id INT NOT NULL,
    name VARCHAR(100),
    area_m2 DECIMAL(10,2),
    pos_x   DECIMAL(10,2) DEFAULT 0,
    pos_y   DECIMAL(10,2) DEFAULT 0,
    width   DECIMAL(10,2) DEFAULT 0,
    length  DECIMAL(10,2) DEFAULT 0,
    soil_type ENUM('standard', 'clay', 'sandy', 'loamy', 'humus', 'chalky') DEFAULT 'standard',
    sunlight  ENUM('low', 'medium', 'high'								  ) DEFAULT 'medium',
    moisture  ENUM('low', 'medium', 'high'					 			  ) DEFAULT 'medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    FOREIGN KEY (garden_id) REFERENCES garden(id) ON DELETE CASCADE
);

-- ======
-- Plants
-- ======
CREATE TABLE plant (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50),
    description TEXT,
    sow_start_month     TINYINT CHECK (sow_start_month     BETWEEN 1 AND 12),
    sow_end_month       TINYINT CHECK (sow_end_month       BETWEEN 1 AND 12),
    harvest_start_month TINYINT CHECK (harvest_start_month BETWEEN 1 AND 12),
    harvest_end_month   TINYINT CHECK (harvest_end_month   BETWEEN 1 AND 12),
    sunlight_need  ENUM('low', 'medium', 'high'								   ) DEFAULT 'medium',
    water_need 	   ENUM('low', 'medium', 'high'								   ) DEFAULT 'medium',
    preferred_soil ENUM('standard', 'clay', 'sandy', 'loamy', 'humus', 'chalky') DEFAULT 'standard',
    spacing_cm INT DEFAULT 20,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL
);

-- =====
-- Crops
-- =====
CREATE TABLE crop (
    id 		  INT AUTO_INCREMENT PRIMARY KEY,
    parcel_id INT NOT NULL,
    plant_id  INT NOT NULL,
    sow_date 			  DATE,
    expected_harvest_date DATE,
    actual_harvest_date   DATE,
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    FOREIGN KEY (parcel_id) REFERENCES parcel(id) ON DELETE CASCADE,
    FOREIGN KEY (plant_id)  REFERENCES plant(id)  ON DELETE CASCADE
);

-- ==================
-- Plant associations
-- ==================
CREATE TABLE plant_association (
    id INT AUTO_INCREMENT PRIMARY KEY,
    plant_id_1 INT NOT NULL,
    plant_id_2 INT NOT NULL,
    relation_type ENUM('positive', 'negative') NOT NULL,
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    FOREIGN KEY (plant_id_1) REFERENCES plant(id) ON DELETE CASCADE,
    FOREIGN KEY (plant_id_2) REFERENCES plant(id) ON DELETE CASCADE
);

-- ===========
-- Suggestions
-- ===========
CREATE TABLE suggestion (
    id 		  INT AUTO_INCREMENT PRIMARY KEY,
    user_id   INT,
    parcel_id INT,
    plant_id  INT,
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    FOREIGN KEY (user_id)   REFERENCES user(id)   ON DELETE SET NULL,
    FOREIGN KEY (parcel_id) REFERENCES parcel(id) ON DELETE CASCADE,
    FOREIGN KEY (plant_id)  REFERENCES plant(id)  ON DELETE CASCADE
);
