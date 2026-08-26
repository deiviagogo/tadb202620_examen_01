/*
====================================================================
 Examen No. 1 - Logica Almacenada en Base de Datos
 Cadena de frio de medicamentos - Distri-Cold
 Motor: Microsoft SQL Server 2025 (Docker local)
 Autor: Juan José Arango Ocampo - 000549306
 Archivo: 04_funciones_procedimientos.sql
 Descripcion: Funciones y procedimientos de apoyo a las acciones
              CRUD sobre el modelo (etapa 3).
====================================================================
*/

USE districold;
GO

-- ============================================================
-- FUNCION: fn_dias_para_vencer
-- Dado un lote, retorna los dias que faltan para su vencimiento
-- (negativo si ya vencio). Apoya reportes de decision (READ).
-- ============================================================
CREATE OR ALTER FUNCTION districold.fn_dias_para_vencer (@p_lote_id INT)
RETURNS INT
AS
BEGIN
    DECLARE @v_dias INT;

    SELECT @v_dias = DATEDIFF(DAY, CAST(GETDATE() AS DATE), fecha_vencimiento)
    FROM districold.lote
    WHERE lote_id = @p_lote_id;

    RETURN @v_dias;
END;
GO

-- ============================================================
-- FUNCION: fn_lectura_fuera_rango
-- Indica si una lectura de temperatura de un almacen esta fuera
-- del rango permitido de al menos uno de los medicamentos que
-- actualmente tiene en existencia.
-- ============================================================
CREATE OR ALTER FUNCTION districold.fn_lectura_fuera_rango (@p_almacen_id INT, @p_temperatura NUMERIC(5,2))
RETURNS BIT
AS
BEGIN
    DECLARE @v_resultado BIT = 0;

    IF EXISTS (
        SELECT 1
        FROM districold.existencia e
        JOIN districold.lote l ON l.lote_id = e.lote_id
        JOIN districold.medicamento m ON m.medicamento_id = l.medicamento_id
        WHERE e.almacen_id = @p_almacen_id
          AND (@p_temperatura < m.temperatura_min_c OR @p_temperatura > m.temperatura_max_c)
    )
        SET @v_resultado = 1;

    RETURN @v_resultado;
END;
GO

-- ============================================================
-- PROCEDIMIENTO: sp_registrar_lote (CREATE)
-- Registra un nuevo lote de un medicamento existente.
-- ============================================================
CREATE OR ALTER PROCEDURE districold.sp_registrar_lote
    @p_codigo               VARCHAR(20),
    @p_medicamento_id       INT,
    @p_fecha_fabricacion    DATE,
    @p_fecha_vencimiento    DATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO districold.lote (codigo, medicamento_id, fecha_fabricacion, fecha_vencimiento)
    VALUES (@p_codigo, @p_medicamento_id, @p_fecha_fabricacion, @p_fecha_vencimiento);
END;
GO

-- ============================================================
-- PROCEDIMIENTO: sp_actualizar_existencia (UPDATE / UPSERT)
-- Registra o actualiza la cantidad disponible de un lote en un
-- almacen determinado.
-- ============================================================
CREATE OR ALTER PROCEDURE districold.sp_actualizar_existencia
    @p_lote_id      INT,
    @p_almacen_id   INT,
    @p_cantidad     INT
AS
BEGIN
    SET NOCOUNT ON;
    MERGE districold.existencia AS destino
    USING (SELECT @p_lote_id AS lote_id, @p_almacen_id AS almacen_id) AS origen
        ON destino.lote_id = origen.lote_id AND destino.almacen_id = origen.almacen_id
    WHEN MATCHED THEN
        UPDATE SET cantidad_disponible = @p_cantidad
    WHEN NOT MATCHED THEN
        INSERT (lote_id, almacen_id, cantidad_disponible)
        VALUES (@p_lote_id, @p_almacen_id, @p_cantidad);
END;
GO

-- ============================================================
-- PROCEDIMIENTO: sp_registrar_lectura (CREATE)
-- Inserta una nueva lectura de temperatura para un almacen.
-- ============================================================
CREATE OR ALTER PROCEDURE districold.sp_registrar_lectura
    @p_almacen_id   INT,
    @p_fecha_hora   DATETIME2,
    @p_temperatura  NUMERIC(5,2)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO districold.lectura_temperatura (almacen_id, fecha_hora, temperatura_c)
    VALUES (@p_almacen_id, @p_fecha_hora, @p_temperatura);
END;
GO

-- ============================================================
-- PROCEDIMIENTO: sp_eliminar_lote (DELETE)
-- Elimina un lote y sus existencias asociadas de forma controlada.
-- ============================================================
CREATE OR ALTER PROCEDURE districold.sp_eliminar_lote
    @p_lote_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM districold.existencia WHERE lote_id = @p_lote_id;
    DELETE FROM districold.lote WHERE lote_id = @p_lote_id;
END;
GO
