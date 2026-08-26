/*
====================================================================
 Examen No. 1 - Logica Almacenada en Base de Datos
 Cadena de frio de medicamentos - Distri-Cold
 Motor: Microsoft SQL Server 2025 (Docker local)
 Autor: Juan José Arango Ocampo - 000549306
 Archivo: 05_carga_datos.sql
 Descripcion: Carga del archivo datos_cadena_frio.csv (1000 registros)
              a una tabla de staging desnormalizada, y posterior
              distribucion hacia el modelo 3FN.

 Ejecucion: el archivo CSV debe existir dentro del contenedor en
 /var/opt/mssql/scripts_examen/datos_cadena_frio.csv (ver
 docker-compose.yml, que monta entrega/sqlserver/sql como volumen).
====================================================================
*/

USE districold;
GO

-- =========================
-- Staging (tal cual el CSV origen)
-- =========================
IF OBJECT_ID('districold.stg_cadena_frio', 'U') IS NOT NULL
    DROP TABLE districold.stg_cadena_frio;

CREATE TABLE districold.stg_cadena_frio (
    fabricante_nombre               VARCHAR(120),
    medicamento_nombre              VARCHAR(150),
    forma_farmaceutica              VARCHAR(60),
    temperatura_min_c               NUMERIC(5,2),
    temperatura_max_c               NUMERIC(5,2),
    lote_codigo                     VARCHAR(20),
    lote_fecha_fabricacion          DATE,
    lote_fecha_vencimiento          DATE,
    almacen_nombre                  VARCHAR(120),
    almacen_ciudad                  VARCHAR(80),
    almacen_tipo                    VARCHAR(60),
    existencia_cantidad_disponible  INT,
    lectura_fecha_hora              DATETIME2,
    lectura_temperatura_c           NUMERIC(5,2)
);
GO

BULK INSERT districold.stg_cadena_frio
FROM '/var/opt/mssql/scripts_examen/datos_cadena_frio.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
-- Nota: la opcion CODEPAGE no esta soportada por BULK INSERT en la
-- version de SQL Server para Linux (usada en el contenedor Docker);
-- el motor toma como entrada UTF-8 por defecto en este entorno.
GO

-- =========================
-- Catalogos
-- =========================
INSERT INTO districold.fabricante (nombre)
SELECT DISTINCT fabricante_nombre FROM districold.stg_cadena_frio s
WHERE NOT EXISTS (SELECT 1 FROM districold.fabricante f WHERE f.nombre = s.fabricante_nombre);

INSERT INTO districold.forma_farmaceutica (nombre)
SELECT DISTINCT forma_farmaceutica FROM districold.stg_cadena_frio s
WHERE NOT EXISTS (SELECT 1 FROM districold.forma_farmaceutica ff WHERE ff.nombre = s.forma_farmaceutica);

INSERT INTO districold.ciudad (nombre)
SELECT DISTINCT almacen_ciudad FROM districold.stg_cadena_frio s
WHERE NOT EXISTS (SELECT 1 FROM districold.ciudad c WHERE c.nombre = s.almacen_ciudad);

INSERT INTO districold.tipo_almacen (nombre)
SELECT DISTINCT almacen_tipo FROM districold.stg_cadena_frio s
WHERE NOT EXISTS (SELECT 1 FROM districold.tipo_almacen ta WHERE ta.nombre = s.almacen_tipo);
GO

-- =========================
-- Medicamento
-- =========================
INSERT INTO districold.medicamento (nombre, forma_farmaceutica_id, fabricante_id, temperatura_min_c, temperatura_max_c)
SELECT DISTINCT
    s.medicamento_nombre,
    ff.forma_farmaceutica_id,
    f.fabricante_id,
    s.temperatura_min_c,
    s.temperatura_max_c
FROM districold.stg_cadena_frio s
JOIN districold.fabricante f              ON f.nombre = s.fabricante_nombre
JOIN districold.forma_farmaceutica ff     ON ff.nombre = s.forma_farmaceutica
WHERE NOT EXISTS (
    SELECT 1 FROM districold.medicamento m
    WHERE m.nombre = s.medicamento_nombre AND m.fabricante_id = f.fabricante_id
);
GO

-- =========================
-- Lote
-- =========================
INSERT INTO districold.lote (codigo, medicamento_id, fecha_fabricacion, fecha_vencimiento)
SELECT DISTINCT
    s.lote_codigo,
    m.medicamento_id,
    s.lote_fecha_fabricacion,
    s.lote_fecha_vencimiento
FROM districold.stg_cadena_frio s
JOIN districold.fabricante f    ON f.nombre = s.fabricante_nombre
JOIN districold.medicamento m   ON m.nombre = s.medicamento_nombre AND m.fabricante_id = f.fabricante_id
WHERE NOT EXISTS (SELECT 1 FROM districold.lote l WHERE l.codigo = s.lote_codigo);
GO

-- =========================
-- Almacen
-- =========================
INSERT INTO districold.almacen (nombre, ciudad_id, tipo_almacen_id)
SELECT DISTINCT
    s.almacen_nombre,
    c.ciudad_id,
    ta.tipo_almacen_id
FROM districold.stg_cadena_frio s
JOIN districold.ciudad c          ON c.nombre = s.almacen_ciudad
JOIN districold.tipo_almacen ta   ON ta.nombre = s.almacen_tipo
WHERE NOT EXISTS (SELECT 1 FROM districold.almacen a WHERE a.nombre = s.almacen_nombre);
GO

-- =========================
-- Existencia (lote x almacen)
-- =========================
INSERT INTO districold.existencia (lote_id, almacen_id, cantidad_disponible)
SELECT
    l.lote_id,
    a.almacen_id,
    s.existencia_cantidad_disponible
FROM districold.stg_cadena_frio s
JOIN districold.lote l     ON l.codigo = s.lote_codigo
JOIN districold.almacen a  ON a.nombre = s.almacen_nombre
WHERE NOT EXISTS (
    SELECT 1 FROM districold.existencia e
    WHERE e.lote_id = l.lote_id AND e.almacen_id = a.almacen_id
);
GO

-- =========================
-- Lectura de temperatura (independiente de la existencia)
-- =========================
INSERT INTO districold.lectura_temperatura (almacen_id, fecha_hora, temperatura_c)
SELECT
    a.almacen_id,
    s.lectura_fecha_hora,
    s.lectura_temperatura_c
FROM districold.stg_cadena_frio s
JOIN districold.almacen a ON a.nombre = s.almacen_nombre
WHERE NOT EXISTS (
    SELECT 1 FROM districold.lectura_temperatura lt
    WHERE lt.almacen_id = a.almacen_id AND lt.fecha_hora = s.lectura_fecha_hora
);
GO

-- =========================
-- Limpieza de staging
-- =========================
DROP TABLE IF EXISTS districold.stg_cadena_frio;
GO
