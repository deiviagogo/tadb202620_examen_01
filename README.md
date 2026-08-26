# tadb202620_examen_01 — Cadena de frío Distri-Cold

Examen No. 1 (20%) — Lógica Almacenada en Base de Datos
Curso: Tópicos Avanzados de Base de Datos — Periodo 202620
Docente: Juan Darío Rodas M.

## Integrantes y motor de base de datos asignado

| Integrante | ID SIGAA | Motor de base de datos | NRC |
|---|---|---|---|
| David Vallejo García | 000551513 | Oracle Database Free 26ai | [NRC] |
| Juan José Arango Ocampo | 000549306 | Microsoft SQL Server 2025 (Developer) | [NRC] |

> Cada integrante trabajó de forma independiente su motor de base de datos, tal como exige el enunciado para trabajo en pareja. El trabajo se entrega como una sola unidad.
>
> **Infraestructura:** ambos motores se desplegaron en contenedores **Docker locales** (sin bonificación de despliegue en la nube). Ver [`docker-compose.yml`](../docker-compose.yml) en la raíz del repositorio.

## Contenido del repositorio

```
entrega/
├── README.md
├── .gitignore
├── diagrama/
│   └── modelo_relacional.png            # ERD (aplica a ambos motores, mismo modelo lógico)
├── oracle/
│   ├── docs/
│   │   ├── 01_abastecimiento_conexion_oracle.md   # Etapas 1 y 2 (agregar capturas + exportar a PDF)
│   │   ├── 02_interaccion_ia_oracle.md            # Evidencia de uso de IA (PENDIENTE: agregar capturas)
│   │   └── comandos_carga.md                      # Comandos docker/sqlplus/sqlldr usados
│   ├── sql/
│   │   ├── 01_usuario_esquema_privilegios.sql
│   │   ├── 02_secuencias_tablas.sql
│   │   ├── 03_vistas.sql
│   │   ├── 04_funciones_procedimientos.sql
│   │   ├── 05_carga_datos.sql
│   │   ├── 05_carga_datos.ctl                     # Control file de SQL*Loader
│   │   ├── 06_consultas_exploracion.sql
│   │   ├── 07_etapa5_window_functions_cte.sql
│   │   └── datos_cadena_frio.csv
│   └── resultados/
│       ├── resultado_pregunta_A.csv
│       ├── resultado_pregunta_B.csv
│       ├── resultado_pregunta_C.csv
│       └── resultado_etapa5_tendencia_temperatura.csv
└── sqlserver/
    ├── docs/
    │   ├── 01_abastecimiento_conexion_sqlserver.md
    │   ├── 02_interaccion_ia_sqlserver.md
    │   └── comandos_carga.md
    ├── sql/
    │   ├── 01_usuario_esquema_privilegios.sql
    │   ├── 02_secuencias_tablas.sql
    │   ├── 03_vistas.sql
    │   ├── 04_funciones_procedimientos.sql
    │   ├── 05_carga_datos.sql
    │   ├── 06_consultas_exploracion.sql
    │   ├── 07_etapa5_window_functions_cte.sql
    │   └── datos_cadena_frio.csv
    └── resultados/
        ├── resultado_pregunta_A.csv
        ├── resultado_pregunta_B.csv
        ├── resultado_pregunta_C.csv
        └── resultado_etapa5_tendencia_temperatura.csv
```

## Dominio del problema

Ver la descripción completa en el enunciado del examen. En resumen: "Distri-Cold" distribuye medicamentos termosensibles y necesita centralizar en una base de datos relacional la cadena de frío (fabricante, medicamento, lote, almacén, existencias por almacén y lecturas de temperatura), reemplazando hojas de cálculo dispersas.

## Modelo de datos (común a ambos motores, normalizado en 3FN)

Entidades: `fabricante`, `forma_farmaceutica`, `medicamento`, `lote`, `ciudad`, `tipo_almacen`, `almacen`, `existencia` (relación N:M lote–almacén), `lectura_temperatura` (lecturas independientes de la existencia, tal como exige el dominio del problema). Ver diagrama en [`diagrama/modelo_relacional.png`](diagrama/modelo_relacional.png).

## Resumen de la solución por motor

### Oracle Database Free 26ai (David Vallejo García)

- **Infraestructura:** contenedor Docker (`gvenzl/oracle-free:latest`), PDB `FREEPDB1`, puerto TCP 1521.
- **Seguridad:** usuario de aplicación `app_districold`, dueño de su propio esquema, con privilegios mínimos (`CREATE SESSION`, `CREATE TABLE`, `CREATE VIEW`, `CREATE SEQUENCE`, `CREATE PROCEDURE`, `CREATE TRIGGER`; sin rol DBA).
- **Carga de datos:** 1000 registros de `datos_cadena_frio.csv` cargados vía SQL*Loader (`05_carga_datos.ctl`) a tabla de staging y distribuidos al modelo 3FN (`05_carga_datos.sql`).
- **Particularidad de Oracle:** las secuencias se asignan a la PK mediante triggers `BEFORE INSERT` (Oracle no soporta `DEFAULT nextval` de forma nativa en todas las versiones del motor libre usado aquí).
- **Etapa 5:** función `fn_tendencia_temperatura_almacen` que retorna un `SYS_REFCURSOR` construido con una cláusula `WITH` (CTE) encadenada de 4 niveles y funciones de ventana (`LAG`, `AVG() OVER (... ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)`, `STDDEV_POP() OVER (...)`, `RANK() OVER (PARTITION BY ciudad ...)`).

### Microsoft SQL Server 2025 — Developer (Juan José Arango Ocampo)

- **Infraestructura:** contenedor Docker (`mcr.microsoft.com/mssql/server:2025-latest`, `MSSQL_PID=Developer`), puerto TCP 1433.
- **Seguridad:** login/usuario de aplicación `app_districold` con privilegios mínimos sobre el esquema `districold` (`SELECT/INSERT/UPDATE/DELETE/EXECUTE`), sin rol `sysadmin`.
- **Carga de datos:** 1000 registros de `datos_cadena_frio.csv` cargados vía `BULK INSERT` a tabla de staging y distribuidos al modelo 3FN (`05_carga_datos.sql`).
- **Etapa 5:** función de tabla en línea (inline TVF) `fn_tendencia_temperatura_almacen` con una cláusula `WITH` (CTE) encadenada de 4 niveles y funciones de ventana (`LAG`, `AVG() OVER (... ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)`, `STDEVP() OVER (...)`, `RANK() OVER (PARTITION BY ciudad ...)`).

**Pregunta de Etapa 5 (compartida por ambos motores, mismo insight):**
*"Para cada almacén, ¿cuál es la tendencia mensual de su temperatura promedio (comparada con el mes anterior y con una media móvil de 3 meses), y cómo se ubica ese almacén en un ranking de estabilidad térmica (menor variabilidad) dentro de su propia ciudad?"*

Justificación: las preguntas típicas de este dominio (qué medicamento, qué lote, qué existencia) ya están cubiertas en la etapa 4. Lo que no se explora habitualmente es el comportamiento **temporal** de la cadena de frío por almacén — si se está deteriorando mes a mes y cómo se compara contra almacenes similares de su ciudad. Esa es la faceta de "insight" que aporta valor estratégico real.

## Cómo reproducir la carga

Ver `oracle/docs/comandos_carga.md` y `sqlserver/docs/comandos_carga.md` para los comandos completos usados con Docker.

```bash
# Desde la raíz del repositorio (junto a docker-compose.yml)
docker compose up -d
```

Todos los scripts fueron **validados y ejecutados de extremo a extremo** localmente contra Oracle Database Free 26ai y SQL Server 2025 (contenedores Docker `gvenzl/oracle-free:latest` y `mcr.microsoft.com/mssql/server:2025-latest`) antes de la entrega. Conteos verificados en ambos motores (idénticos, mismo dataset origen): 18 fabricantes, 6 formas farmacéuticas, 10 ciudades, 3 tipos de almacén, 67 medicamentos, 259 lotes, 25 almacenes, 1000 existencias, 1000 lecturas de temperatura. Los archivos en `resultados/` de cada motor son la salida real de esa ejecución, no datos de ejemplo.
