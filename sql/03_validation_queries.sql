-- ============================================================
-- Project: Gestion Comercial Analytics
-- Script: 03_validation_queries.sql
-- Purpose: Track and execute SQL validation queries used during
--          database setup, data loading validation, and quality checks.
-- Author: Raul
-- ============================================================

-- ============================================================
-- 1. Select the working database
-- Description:
-- This command tells MySQL which database should be used for
-- the following queries.
-- ============================================================

USE gestion_comercial_db;


-- ============================================================
-- 2. Confirm that the database exists
-- Description:
-- This query checks whether the project database was created
-- successfully.
-- Expected result:
-- gestion_comercial_db
-- ============================================================

SHOW DATABASES LIKE 'gestion_comercial_db';


-- ============================================================
-- 3. Confirm the active database
-- Description:
-- This query returns the database currently selected in the session.
-- Expected result:
-- gestion_comercial_db
-- ============================================================

SELECT DATABASE() AS active_database;


-- ============================================================
-- 4. Show all tables in the project database
-- Description:
-- This query lists all tables created inside the selected database.
-- Expected tables:
-- operaciones
-- vendedor_region
-- presupuesto
-- ============================================================

SHOW TABLES;


-- ============================================================
-- 5. Review table structures
-- Description:
-- These commands show the columns, data types, null constraints,
-- keys, and default values for each table.
-- ============================================================

DESCRIBE operaciones;

DESCRIBE vendedor_region;

DESCRIBE presupuesto;


-- ============================================================
-- 6. Validate row counts after Python data load
-- Description:
-- This query checks how many records were loaded into each table.
-- Expected result:
-- operaciones: 999
-- vendedor_region: 19
-- presupuesto: 19
-- ============================================================

SELECT 'operaciones' AS table_name, COUNT(*) AS total_records
FROM operaciones

UNION ALL

SELECT 'vendedor_region' AS table_name, COUNT(*) AS total_records
FROM vendedor_region

UNION ALL

SELECT 'presupuesto' AS table_name, COUNT(*) AS total_records
FROM presupuesto;


-- ============================================================
-- 7. Preview loaded data
-- Description:
-- These queries display sample records from each table to visually
-- confirm that the data was loaded correctly.
-- ============================================================

SELECT *
FROM operaciones
LIMIT 10;

SELECT *
FROM vendedor_region
LIMIT 10;

SELECT *
FROM presupuesto
LIMIT 10;


-- ============================================================
-- 8. Validate sellers from operations against seller-region table
-- Description:
-- This query identifies sellers that exist in the operations table
-- but do not have a matching record in the seller-region table.
-- Expected result:
-- No rows returned.
-- ============================================================

SELECT DISTINCT o.vendedor
FROM operaciones o
LEFT JOIN vendedor_region vr
    ON o.vendedor = vr.vendedor
WHERE vr.vendedor IS NULL
ORDER BY o.vendedor;


-- ============================================================
-- 9. Validate sellers from operations against budget table
-- Description:
-- This query identifies sellers that exist in the operations table
-- but do not have a matching record in the budget table.
-- Expected result:
-- No rows returned.
-- ============================================================

SELECT DISTINCT o.vendedor
FROM operaciones o
LEFT JOIN presupuesto p
    ON o.vendedor = p.vendedor
WHERE p.vendedor IS NULL
ORDER BY o.vendedor;


-- ============================================================
-- 10. Check duplicate sellers in seller-region table
-- Description:
-- This query checks whether the seller-region dimension has
-- duplicated seller names.
-- Expected result:
-- No rows returned.
-- ============================================================

SELECT 
    vendedor,
    COUNT(*) AS total_records
FROM vendedor_region
GROUP BY vendedor
HAVING COUNT(*) > 1;


-- ============================================================
-- 11. Check duplicate sellers in budget table
-- Description:
-- This query checks whether the budget table has duplicated
-- seller names.
-- Expected result:
-- No rows returned.
-- ============================================================

SELECT 
    vendedor,
    COUNT(*) AS total_records
FROM presupuesto
GROUP BY vendedor
HAVING COUNT(*) > 1;


-- ============================================================
-- 12. Check duplicate operation IDs
-- Description:
-- This query checks whether the primary key from the operations
-- table has duplicated values.
-- Expected result:
-- No rows returned.
-- ============================================================

SELECT 
    guia,
    COUNT(*) AS total_records
FROM operaciones
GROUP BY guia
HAVING COUNT(*) > 1;


-- ============================================================
-- 13. Check for null values in critical operation fields
-- Description:
-- This query validates whether important columns have missing data.
-- Expected result:
-- All values should be 0.
-- ============================================================

SELECT
    SUM(CASE WHEN guia IS NULL THEN 1 ELSE 0 END) AS missing_guia,
    SUM(CASE WHEN fecha_operacion IS NULL THEN 1 ELSE 0 END) AS missing_fecha_operacion,
    SUM(CASE WHEN no_cliente IS NULL THEN 1 ELSE 0 END) AS missing_no_cliente,
    SUM(CASE WHEN vendedor IS NULL THEN 1 ELSE 0 END) AS missing_vendedor,
    SUM(CASE WHEN ingreso_operacion IS NULL THEN 1 ELSE 0 END) AS missing_ingreso_operacion,
    SUM(CASE WHEN tipo_cliente IS NULL THEN 1 ELSE 0 END) AS missing_tipo_cliente
FROM operaciones;


-- ============================================================
-- 14. Validate date range in operations
-- Description:
-- This query checks the minimum and maximum operation dates loaded
-- into the database.
-- Expected result:
-- Dates should match the period contained in the Excel file.
-- ============================================================

SELECT
    MIN(fecha_operacion) AS min_fecha_operacion,
    MAX(fecha_operacion) AS max_fecha_operacion
FROM operaciones;


-- ============================================================
-- 15. Validate total income
-- Description:
-- This query calculates the total commercial income loaded into
-- the operations table.
-- This is useful to compare against Python or Excel totals.
-- ============================================================

SELECT
    SUM(ingreso_operacion) AS total_ingreso_operacion
FROM operaciones;


-- ============================================================
-- 16. Validate number of unique clients and sellers
-- Description:
-- This query calculates how many unique clients and sellers exist
-- in the operations table.
-- ============================================================

SELECT
    COUNT(DISTINCT no_cliente) AS unique_clients,
    COUNT(DISTINCT vendedor) AS unique_sellers
FROM operaciones;


-- ============================================================
-- 17. Validate income by seller
-- Description:
-- This query summarizes total income by seller.
-- It is useful for checking whether the loaded data produces
-- reasonable business results.
-- ============================================================

SELECT
    vendedor,
    COUNT(*) AS total_operations,
    SUM(ingreso_operacion) AS total_income
FROM operaciones
GROUP BY vendedor
ORDER BY total_income DESC;


-- ============================================================
-- 18. Validate income by region
-- Description:
-- This query joins operations with the seller-region table to
-- summarize total income by commercial region.
-- ============================================================

SELECT
    vr.region,
    COUNT(*) AS total_operations,
    SUM(o.ingreso_operacion) AS total_income
FROM operaciones o
LEFT JOIN vendedor_region vr
    ON o.vendedor = vr.vendedor
GROUP BY vr.region
ORDER BY total_income DESC;


-- ============================================================
-- 19. Validate income by city
-- Description:
-- This query joins operations with the seller-region table to
-- summarize total income by city.
-- ============================================================

SELECT
    vr.ciudad,
    COUNT(*) AS total_operations,
    SUM(o.ingreso_operacion) AS total_income
FROM operaciones o
LEFT JOIN vendedor_region vr
    ON o.vendedor = vr.vendedor
GROUP BY vr.ciudad
ORDER BY total_income DESC;


-- ============================================================
-- 20. Validate income versus budget by seller
-- Description:
-- This query joins operations with the budget table and calculates
-- how much income each seller generated compared with their assigned
-- budget.
-- ============================================================

SELECT
    o.vendedor,
    SUM(o.ingreso_operacion) AS total_income,
    p.presupuesto,
    SUM(o.ingreso_operacion) / p.presupuesto AS budget_completion_ratio
FROM operaciones o
LEFT JOIN presupuesto p
    ON o.vendedor = p.vendedor
GROUP BY
    o.vendedor,
    p.presupuesto
ORDER BY budget_completion_ratio DESC;


-- ============================================================
-- 21. Validate monthly income
-- Description:
-- This query summarizes commercial income by month.
-- It is useful for validating future Power BI and Excel reports.
-- ============================================================

SELECT
    DATE_FORMAT(fecha_operacion, '%Y-%m') AS operation_month,
    COUNT(*) AS total_operations,
    SUM(ingreso_operacion) AS total_income
FROM operaciones
GROUP BY DATE_FORMAT(fecha_operacion, '%Y-%m')
ORDER BY operation_month;


-- ============================================================
-- 22. Validate income by customer type
-- Description:
-- This query summarizes commercial income by customer type.
-- ============================================================

SELECT
    tipo_cliente,
    COUNT(*) AS total_operations,
    SUM(ingreso_operacion) AS total_income
FROM operaciones
GROUP BY tipo_cliente
ORDER BY tipo_cliente;


-- ============================================================
-- 23. Full enriched data preview
-- Description:
-- This query joins the three core tables and previews the enriched
-- dataset that will later be used for analysis, reporting, and
-- Power BI dashboards.
-- ============================================================

SELECT
    o.guia,
    o.fecha_operacion,
    o.no_cliente,
    o.vendedor,
    vr.ciudad,
    vr.region,
    o.ingreso_operacion,
    o.tipo_cliente,
    p.presupuesto
FROM operaciones o
LEFT JOIN vendedor_region vr
    ON o.vendedor = vr.vendedor
LEFT JOIN presupuesto p
    ON o.vendedor = p.vendedor
LIMIT 20;