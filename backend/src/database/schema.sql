-- ==========================
-- GardenFlow Database Schema
-- ==========================
-- ⚠️  This script DROPS every table before recreating them : all data is lost.
-- It does not select a database : run it with `npm run db:reset` (uses DB_NAME from .env)
-- or `mysql -u <user> -p <database> < schema.sql`.
--
-- Conventions :
--   - hard delete everywhere, children are removed by ON DELETE CASCADE
--   - texts stored in the database (plant names, descriptions...) are in French,
--     other languages are provided by the Flutter translation files using plant.code

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS suggestion;
DROP TABLE IF EXISTS plant_association;
DROP TABLE IF EXISTS plant_period;
DROP TABLE IF EXISTS crop;
DROP TABLE IF EXISTS parcel;
DROP TABLE IF EXISTS garden;
DROP TABLE IF EXISTS plant;
DROP TABLE IF EXISTS user;
SET FOREIGN_KEY_CHECKS = 1;

-- =====
-- Users
-- =====
CREATE TABLE user (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    birthdate     DATE NULL,
    role          ENUM('user', 'admin') NOT NULL DEFAULT 'user',
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- =======
-- Gardens
-- =======
CREATE TABLE garden (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NOT NULL,
    name        VARCHAR(100) NOT NULL,
    location    VARCHAR(255) NULL,
    description TEXT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- =======
-- Parcels
-- =======
-- Dimensions and positions are in meters, relative to the garden's top-left corner.
CREATE TABLE parcel (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    garden_id INT NOT NULL,
    name      VARCHAR(100) NOT NULL,
    area_m2   DECIMAL(10,2) NULL,
    pos_x     DECIMAL(10,2) NOT NULL DEFAULT 0,
    pos_y     DECIMAL(10,2) NOT NULL DEFAULT 0,
    width     DECIMAL(10,2) NOT NULL DEFAULT 0,
    length    DECIMAL(10,2) NOT NULL DEFAULT 0,
    soil_type ENUM('standard', 'clay', 'sandy', 'loamy', 'humus', 'chalky') NOT NULL DEFAULT 'standard',
    sunlight  ENUM('low', 'medium', 'high')                                 NOT NULL DEFAULT 'medium',
    moisture  ENUM('low', 'medium', 'high')                                 NOT NULL DEFAULT 'medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (area_m2 IS NULL OR area_m2 >= 0),
    CHECK (width  >= 0),
    CHECK (length >= 0),
    FOREIGN KEY (garden_id) REFERENCES garden(id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ======
-- Plants
-- ======
-- Reference catalog, only admins can modify it.
-- `code` is a stable identifier used as translation key in the app (plants.<code>.name).
-- `family` is the botanical family (snake_case code, e.g. solanaceae), used for crop rotation
-- and translated in the app (plant_family_<family>).
-- `days_to_maturity` : approximate days from sowing / planting out to the first harvest.
-- The calendar (sowing, planting out, harvest) is in plant_period.
CREATE TABLE plant (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    code                VARCHAR(50)  NOT NULL UNIQUE,
    name                VARCHAR(100) NOT NULL,
    type                ENUM('vegetable', 'fruit', 'herb', 'flower') NOT NULL DEFAULT 'vegetable',
    family              VARCHAR(50)  NULL,
    description         TEXT NULL,
    days_to_maturity    SMALLINT UNSIGNED NULL,
    sunlight_need  ENUM('low', 'medium', 'high')                                 NOT NULL DEFAULT 'medium',
    water_need     ENUM('low', 'medium', 'high')                                 NOT NULL DEFAULT 'medium',
    preferred_soil ENUM('standard', 'clay', 'sandy', 'loamy', 'humus', 'chalky') NOT NULL DEFAULT 'standard',
    spacing_cm     SMALLINT UNSIGNED NOT NULL DEFAULT 20,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- =============
-- Plant periods
-- =============
-- Calendar of a plant : a plant can have several periods of each type
-- (e.g. spinach is sown outdoors in spring AND in autumn).
--   sow_indoor  : sowing under cover (the seedling is not in the parcel yet)
--   sow_outdoor : sowing directly in the ground
--   plant_out   : planting seedlings / bulbs / tubers in the ground
--   harvest     : harvest
-- Ranges may wrap around the year : start_month = 10 and end_month = 3 means "from October to March".
CREATE TABLE plant_period (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    plant_id    INT NOT NULL,
    type        ENUM('sow_indoor', 'sow_outdoor', 'plant_out', 'harvest') NOT NULL,
    start_month TINYINT NOT NULL CHECK (start_month BETWEEN 1 AND 12),
    end_month   TINYINT NOT NULL CHECK (end_month   BETWEEN 1 AND 12),
    KEY idx_plant_period_plant (plant_id),
    FOREIGN KEY (plant_id) REFERENCES plant(id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- =====
-- Crops
-- =====
-- A plant can't be deleted while it is used by a crop (ON DELETE RESTRICT) :
-- deleting a plant from the catalog must never delete users' crops.
CREATE TABLE crop (
    id                    INT AUTO_INCREMENT PRIMARY KEY,
    parcel_id             INT NOT NULL,
    plant_id              INT NOT NULL,
    sow_date              DATE NULL,
    expected_harvest_date DATE NULL,
    actual_harvest_date   DATE NULL,
    comment               TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (parcel_id) REFERENCES parcel(id) ON DELETE CASCADE,
    FOREIGN KEY (plant_id)  REFERENCES plant(id)  ON DELETE RESTRICT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ==================
-- Plant associations
-- ==================
-- Symmetric relation : the API always stores the pair with plant_id_1 < plant_id_2,
-- so the UNIQUE constraint also prevents (B, A) duplicates of (A, B).
-- (MySQL forbids a CHECK constraint on columns having ON DELETE CASCADE,
-- so the ordering is enforced by the API.)
CREATE TABLE plant_association (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    plant_id_1    INT NOT NULL,
    plant_id_2    INT NOT NULL,
    relation_type ENUM('positive', 'negative') NOT NULL,
    comment       TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_plant_pair (plant_id_1, plant_id_2),
    KEY idx_plant_id_2 (plant_id_2),
    FOREIGN KEY (plant_id_1) REFERENCES plant(id) ON DELETE CASCADE,
    FOREIGN KEY (plant_id_2) REFERENCES plant(id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
