/*
====================================================================
 Examen No. 1 - Logica Almacenada en Base de Datos
 Cadena de frio de medicamentos - Distri-Cold
 Motor: Microsoft SQL Server 2025 (Docker local)
 Autor: Juan José Arango Ocampo - 000549306
 Archivo: 03_vistas.sql
 Descripcion: Vistas de apoyo a las preguntas de exploracion del
              modelo (etapa 4) y a los reportes CRUD.
====================================================================
*/

USE districold;
GO

-- Pregunta A: condiciones de temperatura de conservacion por medicamento
CREATE OR ALTER VIEW districold.vw_condiciones_medicamento AS
SELECT
    m.medicamento_id,
    m.nombre                       AS medicamento_nombre,
    ff.nombre                      AS forma_farmaceutica,
    m.temperatura_min_c,
    m.temperatura_max_c
FROM districold.medicamento m
JOIN districold.forma_farmaceutica ff ON ff.forma_farmaceutica_id = m.forma_farmaceutica_id;
GO

-- Pregunta B: lotes existentes por medicamento y sus fechas
CREATE OR ALTER VIEW districold.vw_lotes_medicamento AS
SELECT
    m.medicamento_id,
    m.nombre                       AS medicamento_nombre,
    l.lote_id,
    l.codigo                       AS lote_codigo,
    l.fecha_fabricacion,
    l.fecha_vencimiento
FROM districold.lote l
JOIN districold.medicamento m ON m.medicamento_id = l.medicamento_id;
GO

-- Pregunta C: existencias disponibles por almacen y lote
CREATE OR ALTER VIEW districold.vw_existencia_almacen AS
SELECT
    a.almacen_id,
    a.nombre                       AS almacen_nombre,
    c.nombre                       AS almacen_ciudad,
    ta.nombre                      AS almacen_tipo,
    l.lote_id,
    l.codigo                       AS lote_codigo,
    m.medicamento_id,
    m.nombre                       AS medicamento_nombre,
    e.cantidad_disponible
FROM districold.existencia e
JOIN districold.almacen a       ON a.almacen_id = e.almacen_id
JOIN districold.ciudad c        ON c.ciudad_id = a.ciudad_id
JOIN districold.tipo_almacen ta ON ta.tipo_almacen_id = a.tipo_almacen_id
JOIN districold.lote l          ON l.lote_id = e.lote_id
JOIN districold.medicamento m   ON m.medicamento_id = l.medicamento_id;
GO

-- Apoyo: ultima lectura de temperatura registrada por almacen
-- (SQL Server no tiene DISTINCT ON: se usa ROW_NUMBER() particionado)
CREATE OR ALTER VIEW districold.vw_ultima_lectura_almacen AS
WITH lecturas_rankeadas AS (
    SELECT
        lt.almacen_id,
        a.nombre        AS almacen_nombre,
        lt.fecha_hora,
        lt.temperatura_c,
        ROW_NUMBER() OVER (PARTITION BY lt.almacen_id ORDER BY lt.fecha_hora DESC) AS rn
    FROM districold.lectura_temperatura lt
    JOIN districold.almacen a ON a.almacen_id = lt.almacen_id
)
SELECT almacen_id, almacen_nombre, fecha_hora, temperatura_c
FROM lecturas_rankeadas
WHERE rn = 1;
GO
