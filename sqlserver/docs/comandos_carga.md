# RUNBOOK — Microsoft SQL Server 2025, Developer Edition (Docker local)

Checklist ejecutable, en orden, para reconstruir el entorno de SQL Server desde cero. Cada bloque es un comando que se lanza desde la raíz del repositorio (donde está `docker-compose.yml`). A diferencia del runbook de Oracle (que alterna `sqlplus` y `sqlldr`), aquí **todo el proceso corre con un único cliente**, `sqlcmd`, incluida la carga masiva vía `BULK INSERT` embebida en el propio script `.sql`.

- [x] **PASO 0 — Arranque del contenedor**
  ```bash
  docker compose up -d sqlserver-districold
  docker logs -f districold-sqlserver
  ```
  Esperar `SQL Server is now ready for client connections.` en el log.

- [x] **PASO 1 — Base de datos, esquema y login/usuario de aplicación** (conectado como `sa`)
  ```bash
  docker exec -it districold-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'ClaveAdmin_2026!' -C \
    -i /var/opt/mssql/scripts_examen/01_usuario_esquema_privilegios.sql
  ```
  Crea la base `districold`, el esquema `districold` y el login `app_districold` sin rol `sysadmin`.

- [x] **PASO 2 — Estructuras del modelo (tablas con `IDENTITY`, restricciones, índices)**
  ```bash
  docker exec -it districold-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'ClaveAdmin_2026!' -C \
    -i /var/opt/mssql/scripts_examen/02_secuencias_tablas.sql
  ```
  A diferencia de Oracle (secuencia + trigger `BEFORE INSERT` explícitos), SQL Server resuelve el autoincremento de forma nativa con `IDENTITY(1,1)` en la columna — este script es más corto que su equivalente de Oracle, aunque produce el mismo modelo lógico de 9 tablas en 3FN.

- [x] **PASO 3 — Vistas de consulta (Etapa 4)**
  ```bash
  docker exec -it districold-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'ClaveAdmin_2026!' -C \
    -i /var/opt/mssql/scripts_examen/03_vistas.sql
  ```

- [x] **PASO 4 — Funciones y procedimientos T-SQL (Etapa 3)**
  ```bash
  docker exec -it districold-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'ClaveAdmin_2026!' -C \
    -i /var/opt/mssql/scripts_examen/04_funciones_procedimientos.sql
  ```

- [x] **PASO 5 — Carga de 1000 registros (staging + `BULK INSERT` + distribución 3FN, un solo script)**
  ```bash
  docker exec -it districold-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'ClaveAdmin_2026!' -C \
    -i /var/opt/mssql/scripts_examen/05_carga_datos.sql
  ```
  > **Incidente real de depuración:** la primera versión de este script incluía la opción `CODEPAGE = '65001'` en `BULK INSERT` (para forzar UTF-8), pero **`CODEPAGE` no está soportada por `BULK INSERT` en la build de SQL Server para Linux** usada en este contenedor — falla con `Msg 16202: Keyword or statement option 'CODEPAGE' is not supported on the 'Linux' platform.` Se quitó la opción y se verificó manualmente, consultando la tabla `ciudad` tras la carga, que los acentos (`Bogotá`, `Cúcuta`) llegaran correctos igualmente — el motor toma UTF-8 por defecto en este entorno.

  **Conteos post-distribución (idénticos, por diseño, a los de la solución en Oracle sobre el mismo CSV):**

  | fabricante | forma_farmaceutica | ciudad | tipo_almacen | medicamento | lote | almacen | existencia | lectura_temperatura |
  |---:|---:|---:|---:|---:|---:|---:|---:|---:|
  | 18 | 6 | 10 | 3 | 67 | 259 | 25 | 1000 | 1000 |

- [x] **PASO 6 — Consultas de exploración (Etapa 4)**
  ```bash
  docker exec -it districold-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'ClaveAdmin_2026!' -C \
    -i /var/opt/mssql/scripts_examen/06_consultas_exploracion.sql
  ```
  Salida real en `../resultados/resultado_pregunta_{A,B,C}.csv`.

- [x] **PASO 7 — Función analítica de la Etapa 5**
  ```bash
  docker exec -it districold-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'ClaveAdmin_2026!' -C \
    -i /var/opt/mssql/scripts_examen/07_etapa5_window_functions_cte.sql
  ```
  Crea `fn_tendencia_temperatura_almacen` como función de tabla en línea y la invoca con `SELECT * FROM districold.fn_tendencia_temperatura_almacen();`. 162 filas de salida real en `../resultados/resultado_etapa5_tendencia_temperatura.csv`, **numéricamente idénticas** a las de Oracle.

---

**Estado:** los 8 pasos anteriores fueron ejecutados de punta a punta contra un contenedor real de `mcr.microsoft.com/mssql/server:2025-latest` antes de armar esta entrega. Nada en `../resultados/` es dato de ejemplo.
