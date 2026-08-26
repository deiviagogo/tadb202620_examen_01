/*
====================================================================
 Examen No. 1 - Logica Almacenada en Base de Datos
 Cadena de frio de medicamentos - Distri-Cold
 Motor: Microsoft SQL Server 2025 (Docker local)
 Autor: Juan José Arango Ocampo - 000549306
 Archivo: 06_consultas_exploracion.sql
 Descripcion: Etapa 4 - Consultas SQL de exploracion del modelo.
====================================================================
*/

USE districold;
GO

-- ============================================================
-- Pregunta A: ¿En que condiciones de temperatura debe
-- conservarse cada medicamento?
-- Salida: nombre del medicamento, forma farmaceutica,
--         temperatura minima, temperatura maxima
-- ============================================================
SELECT
    medicamento_nombre,
    forma_farmaceutica,
    temperatura_min_c,
    temperatura_max_c
FROM districold.vw_condiciones_medicamento
ORDER BY medicamento_nombre;
GO

-- ============================================================
-- Pregunta B: ¿Que lotes existen de cada medicamento y cuando
-- vencen?
-- Salida: nombre del medicamento, codigo de lote,
--         fecha de fabricacion, fecha de vencimiento
-- ============================================================
SELECT
    medicamento_nombre,
    lote_codigo,
    fecha_fabricacion,
    fecha_vencimiento
FROM districold.vw_lotes_medicamento
ORDER BY medicamento_nombre, fecha_vencimiento;
GO

-- ============================================================
-- Pregunta C: ¿En que almacenes hay unidades disponibles de
-- cada lote y cuantas?
-- Salida: nombre del almacen, ciudad, tipo de almacen,
--         codigo del lote, nombre del medicamento,
--         cantidad disponible
-- ============================================================
SELECT
    almacen_nombre,
    almacen_ciudad,
    almacen_tipo,
    lote_codigo,
    medicamento_nombre,
    cantidad_disponible
FROM districold.vw_existencia_almacen
ORDER BY almacen_nombre, lote_codigo;
GO
