-- ============================================================
-- Project: Gestion Comercial Analytics
-- Script: 02_create_tables.sql
-- Purpose: Create core tables for the commercial analytics database
-- Author: Raul
-- ============================================================

USE gestion_comercial_db;

-- ============================================================
-- Table: operaciones
-- Description: Main table containing commercial operations
-- Source: Excel sheet "BD"
-- ============================================================

CREATE TABLE IF NOT EXISTS operaciones (
    guia INT PRIMARY KEY,
    fecha_operacion DATE NOT NULL,
    no_cliente INT NOT NULL,
    vendedor VARCHAR(100) NOT NULL,
    ingreso_operacion DECIMAL(15,2) NOT NULL,
    tipo_cliente INT NOT NULL
);

-- ============================================================
-- Table: vendedor_region
-- Description: Commercial seller dimension with city and region
-- Source: Excel sheet "Ciudad-Region"
-- ============================================================

CREATE TABLE IF NOT EXISTS vendedor_region (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre_original VARCHAR(150) NOT NULL,
    vendedor VARCHAR(100) NOT NULL,
    ciudad VARCHAR(100) NOT NULL,
    region VARCHAR(100) NOT NULL
);

-- ============================================================
-- Table: presupuesto
-- Description: Budget assigned to each seller
-- Source: Excel sheet "Presupuesto"
-- ============================================================

CREATE TABLE IF NOT EXISTS presupuesto (
    id INT AUTO_INCREMENT PRIMARY KEY,
    vendedor_original VARCHAR(150) NOT NULL,
    vendedor VARCHAR(100) NOT NULL,
    presupuesto DECIMAL(15,2) NOT NULL
);