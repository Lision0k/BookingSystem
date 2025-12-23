-- Создание базы данных
CREATE DATABASE IF NOT EXISTS `BookingSystem` 
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `BookingSystem`;

-- Таблица пользователей
CREATE TABLE IF NOT EXISTS `Users` (
    `Id` INT PRIMARY KEY AUTO_INCREMENT,
    `Login` VARCHAR(50) UNIQUE NOT NULL,
    `PasswordHash` VARCHAR(255) NOT NULL,
    `Role` ENUM('Client', 'Master') NOT NULL,
    `FullName` VARCHAR(100) NOT NULL,
    `Phone` VARCHAR(20) NOT NULL,
    `CreatedAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `IsActive` BOOLEAN DEFAULT TRUE,
    INDEX `idx_login` (`Login`),
    INDEX `idx_role` (`Role`)
);

-- Таблица мастеров (расширение Users)
CREATE TABLE IF NOT EXISTS `Masters` (
    `UserId` INT PRIMARY KEY,
    `Specialization` TEXT,
    `Experience` INT DEFAULT 0,
    `PhotoPath` VARCHAR(255),
    `Description` TEXT,
    FOREIGN KEY (`UserId`) REFERENCES `Users`(`Id`) ON DELETE CASCADE
);

-- Таблица услуг
CREATE TABLE IF NOT EXISTS `Services` (
    `Id` INT PRIMARY KEY AUTO_INCREMENT,
    `Name` VARCHAR(100) NOT NULL,
    `Description` TEXT,
    `DurationMinutes` INT NOT NULL DEFAULT 60,
    `MasterId` INT NOT NULL,
    `IsActive` BOOLEAN DEFAULT TRUE,
    `CreatedAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`MasterId`) REFERENCES `Masters`(`UserId`) ON DELETE CASCADE,
    INDEX `idx_master` (`MasterId`),
    INDEX `idx_active` (`IsActive`)
);

-- Таблица записей
CREATE TABLE IF NOT EXISTS `Appointments` (
    `Id` INT PRIMARY KEY AUTO_INCREMENT,
    `ClientId` INT NOT NULL,
    `MasterId` INT NOT NULL,
    `ServiceId` INT NOT NULL,
    `DateTimeStart` DATETIME NOT NULL,
    `DateTimeEnd` DATETIME NOT NULL,
    `Status` ENUM('Active', 'Cancelled', 'Completed') DEFAULT 'Active',
    `Notes` TEXT,
    `CreatedAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `CancelledAt` DATETIME,
    FOREIGN KEY (`ClientId`) REFERENCES `Users`(`Id`),
    FOREIGN KEY (`MasterId`) REFERENCES `Masters`(`UserId`),
    FOREIGN KEY (`ServiceId`) REFERENCES `Services`(`Id`),
    INDEX `idx_client` (`ClientId`),
    INDEX `idx_master_date` (`MasterId`, `DateTimeStart`),
    INDEX `idx_status` (`Status`),
    INDEX `idx_datetime` (`DateTimeStart`, `DateTimeEnd`),
    UNIQUE KEY `uq_master_time` (`MasterId`, `DateTimeStart`, `Status`),
    CHECK (`DateTimeEnd` > `DateTimeStart`)
);

-- Создание пользователя для приложения (с ограниченными правами)
CREATE USER 'booking_user'@'localhost' IDENTIFIED BY 'SecurePass123!';
GRANT SELECT, INSERT, UPDATE, DELETE ON `BookingSystem`.* TO 'booking_user'@'localhost';
FLUSH PRIVILEGES;

-- Триггер для автоматического расчета DateTimeEnd при вставке
DELIMITER //
CREATE TRIGGER CalculateAppointmentEndTime
BEFORE INSERT ON Appointments
FOR EACH ROW
BEGIN
    -- Если DateTimeEnd не указан, рассчитываем его на основе услуги
    IF NEW.DateTimeEnd IS NULL OR NEW.DateTimeEnd <= NEW.DateTimeStart THEN
        SET NEW.DateTimeEnd = DATE_ADD(
            NEW.DateTimeStart, 
            INTERVAL (
                SELECT DurationMinutes 
                FROM Services 
                WHERE Id = NEW.ServiceId
            ) MINUTE
        );
    END IF;
END//
DELIMITER ;

-- Триггер для обновления времени окончания при изменении времени начала или услуги
DELIMITER //
CREATE TRIGGER UpdateAppointmentEndTime
BEFORE UPDATE ON Appointments
FOR EACH ROW
BEGIN
    -- Если изменилось время начала или услуга
    IF OLD.DateTimeStart <> NEW.DateTimeStart OR OLD.ServiceId <> NEW.ServiceId THEN
        SET NEW.DateTimeEnd = DATE_ADD(
            NEW.DateTimeStart, 
            INTERVAL (
                SELECT DurationMinutes 
                FROM Services 
                WHERE Id = NEW.ServiceId
            ) MINUTE
        );
    END IF;
END//
DELIMITER ;