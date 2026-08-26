/*
====================================================================
 Examen No. 1 - Logica Almacenada en Base de Datos
 Cadena de frio de medicamentos - Distri-Cold
 Motor: Microsoft SQL Server 2025 (Docker local)
 Autor: Juan José Arango Ocampo - 000549306
 Archivo: 02_secuencias_tablas.sql
 Descripcion: Modelo de datos normalizado en 3FN.

 Justificacion de normalizacion (3FN):
  - forma_farmaceutica, fabricante, ciudad y tipo_almacen se separan
    en catalogos propios porque son valores repetidos y determinados
    por una clave distinta a la de la entidad que los referencia
    (evita dependencias transitivas).
  - medicamento depende funcionalmente solo de su propia clave
    (medicamento_id): nombre, forma_farmaceutica_id, fabricante_id,
    temperatura_min_c, temperatura_max_c.
  - lote depende solo de lote_id (codigo, medicamento_id, fechas).
  - almacen depende solo de almacen_id (nombre, ciudad_id, tipo_almacen_id).
  - existencia modela la relacion N:M entre lote y almacen (cantidad
    disponible es un atributo de la relacion, no de lote ni de almacen).
  - lectura_temperatura es independiente de existencia/lote, tal como
    lo exige el enunciado (lecturas continuas del almacen sin importar
    que lotes haya en ese momento en la bodega).
====================================================================
*/

USE districold;
GO

-- =========================
-- Secuencias
-- =========================
IF OBJECT_ID('districold.seq_fabricante', 'SO') IS NULL CREATE SEQUENCE districold.seq_fabricante AS INT START WITH 1 INCREMENT BY 1;
IF OBJECT_ID('districold.seq_forma_farmaceutica', 'SO') IS NULL CREATE SEQUENCE districold.seq_forma_farmaceutica AS INT START WITH 1 INCREMENT BY 1;
IF OBJECT_ID('districold.seq_ciudad', 'SO') IS NULL CREATE SEQUENCE districold.seq_ciudad AS INT START WITH 1 INCREMENT BY 1;
IF OBJECT_ID('districold.seq_tipo_almacen', 'SO') IS NULL CREATE SEQUENCE districold.seq_tipo_almacen AS INT START WITH 1 INCREMENT BY 1;
IF OBJECT_ID('districold.seq_medicamento', 'SO') IS NULL CREATE SEQUENCE districold.seq_medicamento AS INT START WITH 1 INCREMENT BY 1;
IF OBJECT_ID('districold.seq_lote', 'SO') IS NULL CREATE SEQUENCE districold.seq_lote AS INT START WITH 1 INCREMENT BY 1;
IF OBJECT_ID('districold.seq_almacen', 'SO') IS NULL CREATE SEQUENCE districold.seq_almacen AS INT START WITH 1 INCREMENT BY 1;
IF OBJECT_ID('districold.seq_existencia', 'SO') IS NULL CREATE SEQUENCE districold.seq_existencia AS INT START WITH 1 INCREMENT BY 1;
IF OBJECT_ID('districold.seq_lectura_temp', 'SO') IS NULL CREATE SEQUENCE districold.seq_lectura_temp AS BIGINT START WITH 1 INCREMENT BY 1;
GO

-- =========================
-- Catalogos
-- =========================
IF OBJECT_ID('districold.fabricante', 'U') IS NULL
CREATE TABLE districold.fabricante (
    fabricante_id   INT PRIMARY KEY DEFAULT NEXT VALUE FOR districold.seq_fabricante,
    nombre          VARCHAR(120) NOT NULL UNIQUE
);
GO

IF OBJECT_ID('districold.forma_farmaceutica', 'U') IS NULL
CREATE TABLE districold.forma_farmaceutica (
    forma_farmaceutica_id INT PRIMARY KEY DEFAULT NEXT VALUE FOR districold.seq_forma_farmaceutica,
    nombre                VARCHAR(60) NOT NULL UNIQUE
);
GO

IF OBJECT_ID('districold.ciudad', 'U') IS NULL
CREATE TABLE districold.ciudad (
    ciudad_id       INT PRIMARY KEY DEFAULT NEXT VALUE FOR districold.seq_ciudad,
    nombre          VARCHAR(80) NOT NULL UNIQUE
);
GO

IF OBJECT_ID('districold.tipo_almacen', 'U') IS NULL
CREATE TABLE districold.tipo_almacen (
    tipo_almacen_id INT PRIMARY KEY DEFAULT NEXT VALUE FOR districold.seq_tipo_almacen,
    nombre          VARCHAR(60) NOT NULL UNIQUE
);
GO

-- =========================
-- Entidades principales
-- =========================
IF OBJECT_ID('districold.medicamento', 'U') IS NULL
CREATE TABLE districold.medicamento (
    medicamento_id          INT PRIMARY KEY DEFAULT NEXT VALUE FOR districold.seq_medicamento,
    nombre                  VARCHAR(150) NOT NULL,
    forma_farmaceutica_id   INT NOT NULL REFERENCES districold.forma_farmaceutica(forma_farmaceutica_id),
    fabricante_id           INT NOT NULL REFERENCES districold.fabricante(fabricante_id),
    temperatura_min_c       NUMERIC(5,2) NOT NULL,
    temperatura_max_c       NUMERIC(5,2) NOT NULL,
    CONSTRAINT uq_medicamento UNIQUE (nombre, fabricante_id),
    CONSTRAINT ck_medicamento_rango_temp CHECK (temperatura_min_c < temperatura_max_c)
);
GO

IF OBJECT_ID('districold.lote', 'U') IS NULL
CREATE TABLE districold.lote (
    lote_id                 INT PRIMARY KEY DEFAULT NEXT VALUE FOR districold.seq_lote,
    codigo                  VARCHAR(20) NOT NULL UNIQUE,
    medicamento_id          INT NOT NULL REFERENCES districold.medicamento(medicamento_id),
    fecha_fabricacion       DATE NOT NULL,
    fecha_vencimiento       DATE NOT NULL,
    CONSTRAINT ck_lote_fechas CHECK (fecha_vencimiento > fecha_fabricacion)
);
GO

IF OBJECT_ID('districold.almacen', 'U') IS NULL
CREATE TABLE districold.almacen (
    almacen_id              INT PRIMARY KEY DEFAULT NEXT VALUE FOR districold.seq_almacen,
    nombre                  VARCHAR(120) NOT NULL UNIQUE,
    ciudad_id               INT NOT NULL REFERENCES districold.ciudad(ciudad_id),
    tipo_almacen_id         INT NOT NULL REFERENCES districold.tipo_almacen(tipo_almacen_id)
);
GO

-- Relacion N:M lote <-> almacen, con atributo propio (cantidad_disponible)
IF OBJECT_ID('districold.existencia', 'U') IS NULL
CREATE TABLE districold.existencia (
    existencia_id           INT PRIMARY KEY DEFAULT NEXT VALUE FOR districold.seq_existencia,
    lote_id                 INT NOT NULL REFERENCES districold.lote(lote_id),
    almacen_id              INT NOT NULL REFERENCES districold.almacen(almacen_id),
    cantidad_disponible     INT NOT NULL,
    CONSTRAINT uq_existencia_lote_almacen UNIQUE (lote_id, almacen_id),
    CONSTRAINT ck_existencia_cantidad CHECK (cantidad_disponible >= 0)
);
GO

-- Lecturas de temperatura del almacen, independientes de los lotes
IF OBJECT_ID('districold.lectura_temperatura', 'U') IS NULL
CREATE TABLE districold.lectura_temperatura (
    lectura_id              BIGINT PRIMARY KEY DEFAULT NEXT VALUE FOR districold.seq_lectura_temp,
    almacen_id              INT NOT NULL REFERENCES districold.almacen(almacen_id),
    fecha_hora              DATETIME2 NOT NULL,
    temperatura_c           NUMERIC(5,2) NOT NULL,
    CONSTRAINT uq_lectura_almacen_fecha UNIQUE (almacen_id, fecha_hora)
);
GO

-- =========================
-- Indices de apoyo a consultas frecuentes
-- =========================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_lote_medicamento')
    CREATE INDEX ix_lote_medicamento ON districold.lote(medicamento_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_existencia_almacen')
    CREATE INDEX ix_existencia_almacen ON districold.existencia(almacen_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_existencia_lote')
    CREATE INDEX ix_existencia_lote ON districold.existencia(lote_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_lectura_almacen_fecha')
    CREATE INDEX ix_lectura_almacen_fecha ON districold.lectura_temperatura(almacen_id, fecha_hora);
GO
