-- ============================================================
-- Project: Gestion Comercial Analytics
-- Script: 04_clean_views.sql
-- Purpose: Create clean and enriched SQL views for analysis,
--          reporting, and Power BI consumption.
-- Author: Raul
-- ============================================================

USE gestion_comercial_db;


-- ============================================================
-- View: vw_ventas_enriquecidas
-- Description:
-- This view joins the core operations table with seller-region
-- and budget information.
--
-- It provides a clean analytical dataset that can be consumed by:
-- - Python analysis scripts
-- - Excel report generation
-- - Power BI dashboards
-- - SQL KPI queries
--
-- Join strategy:
-- LEFT JOIN is used to preserve all operation records even if a
-- seller does not have a matching region or budget record.
-- ============================================================

CREATE OR REPLACE VIEW vw_ventas_enriquecidas AS
SELECT
    -- Operation identifiers
    o.guia,
    o.fecha_operacion,
    o.no_cliente,

    -- Date dimensions
    YEAR(o.fecha_operacion) AS anio_operacion,
    MONTH(o.fecha_operacion) AS mes_numero,
    DATE_FORMAT(o.fecha_operacion, '%Y-%m') AS mes_periodo,
    QUARTER(o.fecha_operacion) AS trimestre_numero,
    CONCAT(YEAR(o.fecha_operacion), '-Q', QUARTER(o.fecha_operacion)) AS trimestre_periodo,

    -- Commercial dimensions
    o.vendedor,
    vr.ciudad,
    vr.region,
    o.tipo_cliente,

    -- Financial metrics
    o.ingreso_operacion,
    p.presupuesto AS presupuesto_vendedor,

    -- Data quality flags
    CASE
        WHEN vr.vendedor IS NULL THEN 0
        ELSE 1
    END AS tiene_region_asignada,

    CASE
        WHEN p.vendedor IS NULL THEN 0
        ELSE 1
    END AS tiene_presupuesto_asignado

FROM operaciones o
LEFT JOIN vendedor_region vr
    ON o.vendedor = vr.vendedor
LEFT JOIN presupuesto p
    ON o.vendedor = p.vendedor;


-- ============================================================
-- View: vw_resumen_mensual
-- Description:
-- This view summarizes income and operations by month.
-- It is useful for quick SQL validation and Power BI trend charts.
-- ============================================================

CREATE OR REPLACE VIEW vw_resumen_mensual AS
SELECT
    anio_operacion,
    mes_numero,
    mes_periodo,
    COUNT(*) AS total_operaciones,
    COUNT(DISTINCT no_cliente) AS clientes_unicos,
    COUNT(DISTINCT vendedor) AS vendedores_activos,
    SUM(ingreso_operacion) AS ingreso_total,
    AVG(ingreso_operacion) AS ingreso_promedio_operacion
FROM vw_ventas_enriquecidas
GROUP BY
    anio_operacion,
    mes_numero,
    mes_periodo;


-- ============================================================
-- View: vw_resumen_vendedor
-- Description:
-- This view summarizes commercial performance by seller.
-- It includes income, number of operations, unique clients,
-- assigned budget, and budget completion percentage.
-- ============================================================

CREATE OR REPLACE VIEW vw_resumen_vendedor AS
SELECT
    vendedor,
    ciudad,
    region,
    presupuesto_vendedor,
    COUNT(*) AS total_operaciones,
    COUNT(DISTINCT no_cliente) AS clientes_unicos,
    SUM(ingreso_operacion) AS ingreso_total,
    AVG(ingreso_operacion) AS ingreso_promedio_operacion,

    CASE
        WHEN presupuesto_vendedor IS NULL OR presupuesto_vendedor = 0 THEN NULL
        ELSE SUM(ingreso_operacion) / presupuesto_vendedor
    END AS cumplimiento_presupuesto

FROM vw_ventas_enriquecidas
GROUP BY
    vendedor,
    ciudad,
    region,
    presupuesto_vendedor;


-- ============================================================
-- View: vw_resumen_region
-- Description:
-- This view summarizes commercial performance by region.
-- It is useful for executive dashboards and regional comparison.
-- ============================================================

CREATE OR REPLACE VIEW vw_resumen_region AS
SELECT
    region,
    COUNT(*) AS total_operaciones,
    COUNT(DISTINCT no_cliente) AS clientes_unicos,
    COUNT(DISTINCT vendedor) AS vendedores_activos,
    SUM(ingreso_operacion) AS ingreso_total,
    AVG(ingreso_operacion) AS ingreso_promedio_operacion
FROM vw_ventas_enriquecidas
GROUP BY
    region;


-- ============================================================
-- View: vw_resumen_ciudad
-- Description:
-- This view summarizes commercial performance by city.
-- It supports geographical and branch-level analysis.
-- ============================================================

CREATE OR REPLACE VIEW vw_resumen_ciudad AS
SELECT
    ciudad,
    region,
    COUNT(*) AS total_operaciones,
    COUNT(DISTINCT no_cliente) AS clientes_unicos,
    COUNT(DISTINCT vendedor) AS vendedores_activos,
    SUM(ingreso_operacion) AS ingreso_total,
    AVG(ingreso_operacion) AS ingreso_promedio_operacion
FROM vw_ventas_enriquecidas
GROUP BY
    ciudad,
    region;