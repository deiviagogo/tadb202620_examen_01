/*
====================================================================
 Examen No. 1 - Logica Almacenada en Base de Datos
 Cadena de frio de medicamentos - Distri-Cold
 Motor: Microsoft SQL Server 2025 (Docker local)
 Autor: Juan José Arango Ocampo - 000549306
 Archivo: 07_etapa5_window_functions_cte.sql
 Descripcion: Etapa 5 - Funcion con Common Table Expressions (CTE)
              y Window Functions.

 Pregunta en lenguaje natural:
 "Para cada almacen, ¿cual es la tendencia mensual de su temperatura
  promedio (comparada con el mes anterior y con una media movil de
  3 meses), y como se ubica ese almacen en un ranking de estabilidad
  termica (menor variabilidad) dentro de su propia ciudad?"

 Justificacion (faceta poco explorada del dominio):
 Las preguntas mas habituales sobre este dominio giran en torno a
 catalogos estaticos (que medicamento, que lote, que existencia hay).
 Lo que casi nunca se analiza es el comportamiento TEMPORAL de la
 cadena de frio por almacen: si un almacen se esta "deteriorando"
 mes a mes (temperatura promedio en aumento) y si, comparado con los
 demas almacenes de su misma ciudad, es de los mas estables o de los
 mas erraticos. Esta vista de tendencia + ranking es justo lo que un
 gerente de operaciones necesitaria para decidir en que almacen
 invertir en mantenimiento de refrigeracion.
====================================================================
*/

USE districold;
GO

-- ============================================================
-- FUNCION: fn_tendencia_temperatura_almacen
-- Funcion de tabla en linea (inline TVF) que usa CTE para agregar
-- lecturas por almacen/mes, y Window Functions (LAG, AVG OVER ROWS,
-- STDEV, RANK OVER PARTITION) para calcular tendencia mes a mes,
-- media movil de 3 meses y ranking de estabilidad termica dentro
-- de la ciudad.
-- ============================================================
CREATE OR ALTER FUNCTION districold.fn_tendencia_temperatura_almacen ()
RETURNS TABLE
AS
RETURN
    WITH lecturas_mes AS (
        -- CTE 1: agregacion mensual de lecturas por almacen
        SELECT
            a.almacen_id,
            a.nombre                                              AS almacen_nombre,
            c.nombre                                               AS ciudad_nombre,
            DATEFROMPARTS(YEAR(lt.fecha_hora), MONTH(lt.fecha_hora), 1) AS mes,
            AVG(lt.temperatura_c)                                  AS temp_promedio_mes
        FROM districold.lectura_temperatura lt
        JOIN districold.almacen a ON a.almacen_id = lt.almacen_id
        JOIN districold.ciudad c  ON c.ciudad_id = a.ciudad_id
        GROUP BY a.almacen_id, a.nombre, c.nombre,
                 DATEFROMPARTS(YEAR(lt.fecha_hora), MONTH(lt.fecha_hora), 1)
    ),
    tendencia AS (
        -- CTE 2: Window Functions sobre la serie mensual por almacen
        SELECT
            almacen_id,
            almacen_nombre,
            ciudad_nombre,
            mes,
            temp_promedio_mes,
            LAG(temp_promedio_mes) OVER (
                PARTITION BY almacen_id ORDER BY mes
            )                                                      AS temp_promedio_mes_anterior,
            temp_promedio_mes - LAG(temp_promedio_mes) OVER (
                PARTITION BY almacen_id ORDER BY mes
            )                                                      AS variacion_vs_mes_anterior,
            AVG(temp_promedio_mes) OVER (
                PARTITION BY almacen_id ORDER BY mes
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            )                                                      AS media_movil_3_meses
        FROM lecturas_mes
    ),
    variabilidad AS (
        -- CTE 3: variabilidad global del almacen (Window Function)
        SELECT DISTINCT
            t.almacen_id,
            t.ciudad_nombre,
            STDEVP(t.temp_promedio_mes) OVER (PARTITION BY t.almacen_id) AS desviacion_estandar_almacen
        FROM tendencia t
    ),
    estabilidad AS (
        -- CTE 4: ranking de estabilidad dentro de la ciudad (Window Function
        -- aplicada sobre el resultado ya materializado de la CTE anterior)
        SELECT
            v.almacen_id,
            v.desviacion_estandar_almacen,
            RANK() OVER (
                PARTITION BY v.ciudad_nombre
                ORDER BY v.desviacion_estandar_almacen ASC
            ) AS ranking_estabilidad_ciudad
        FROM variabilidad v
    )
    SELECT
        t.almacen_id,
        t.almacen_nombre,
        t.ciudad_nombre,
        t.mes,
        ROUND(t.temp_promedio_mes, 2)              AS temp_promedio_mes,
        ROUND(t.temp_promedio_mes_anterior, 2)     AS temp_promedio_mes_anterior,
        ROUND(t.variacion_vs_mes_anterior, 2)      AS variacion_vs_mes_anterior,
        ROUND(t.media_movil_3_meses, 2)            AS media_movil_3_meses,
        ROUND(e.desviacion_estandar_almacen, 2)    AS desviacion_estandar_almacen,
        e.ranking_estabilidad_ciudad
    FROM tendencia t
    JOIN estabilidad e ON e.almacen_id = t.almacen_id;
GO

-- ============================================================
-- Consulta que utiliza la funcion creada
-- ============================================================
SELECT *
FROM districold.fn_tendencia_temperatura_almacen()
ORDER BY ciudad_nombre, ranking_estabilidad_ciudad, almacen_nombre, mes;
GO
