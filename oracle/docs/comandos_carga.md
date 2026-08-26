# RUNBOOK — Oracle Database Free 26ai (Docker local)

Checklist ejecutable, en orden, para reconstruir el entorno de Oracle desde cero. Cada bloque es un comando que se lanza desde la raíz del repositorio (donde está `docker-compose.yml`). Marca cada casilla al ejecutarlo — así se usó realmente para producir los resultados de `../resultados/`.

- [x] **PASO 0 — Arranque del contenedor**
  ```bash
  docker compose up -d oracle-districold
  docker logs -f districold-oracle
  ```
  Esperar `DATABASE IS READY TO USE!` en el log. `Ctrl+C` para salir del `-f` (el contenedor sigue corriendo).

- [x] **PASO 1 — Usuario y privilegios de aplicación** (conectado como `system`)
  ```bash
  docker exec -it districold-oracle sqlplus system/ClaveAdmin_2026!@//localhost:1521/FREEPDB1 \
    @/opt/oracle/scripts_examen/01_usuario_esquema_privilegios.sql
  ```
  Crea `app_districold`, dueño de su propio esquema, sin rol DBA.

- [x] **PASO 2 — Estructuras del modelo** (conectado como `app_districold` de aquí en adelante)
  ```bash
  docker exec -it districold-oracle sqlplus app_districold/CambieEstaClave_2026!@//localhost:1521/FREEPDB1 \
    @/opt/oracle/scripts_examen/02_secuencias_tablas.sql
  ```
  > Nota de depuración real: una primera versión de este script fallaba con `ORA-01408: such column list already indexed` al crear explícitamente un índice sobre `(almacen_id, fecha_hora)` de `lectura_temperatura` — Oracle ya había generado un índice único implícito para la restricción `UNIQUE` sobre esas mismas columnas. Se eliminó el índice redundante.

- [x] **PASO 3 — Vistas de consulta (Etapa 4)**
  ```bash
  docker exec -it districold-oracle sqlplus app_districold/CambieEstaClave_2026!@//localhost:1521/FREEPDB1 \
    @/opt/oracle/scripts_examen/03_vistas.sql
  ```

- [x] **PASO 4 — Funciones y procedimientos (Etapa 3)**
  ```bash
  docker exec -it districold-oracle sqlplus app_districold/CambieEstaClave_2026!@//localhost:1521/FREEPDB1 \
    @/opt/oracle/scripts_examen/04_funciones_procedimientos.sql
  ```

- [x] **PASO 5 — Carga de 1000 registros (staging + SQL\*Loader + distribución 3FN)**

  Este paso alterna dos herramientas de línea de comandos (`sqlplus` y `sqlldr`), por eso `05_carga_datos.sql` está dividido internamente en **PASO 1** (crear staging vacío) y **PASO 2** (distribuir + limpiar), con el `sqlldr` corriendo entre medio:

  ```bash
  # 5.1 Crear tabla de staging vacía (bloque "PASO 1" del archivo)
  docker exec -it districold-oracle sqlplus app_districold/CambieEstaClave_2026!@//localhost:1521/FREEPDB1 \
    @/opt/oracle/scripts_examen/05_carga_datos_paso1_staging.sql

  # 5.2 SQL*Loader: CSV -> staging
  docker exec -it districold-oracle sqlldr app_districold/CambieEstaClave_2026!@//localhost:1521/FREEPDB1 \
    control=/opt/oracle/scripts_examen/05_carga_datos.ctl \
    data=/opt/oracle/scripts_examen/datos_cadena_frio.csv \
    log=/opt/oracle/scripts_examen/05_carga_datos.log \
    bad=/opt/oracle/scripts_examen/05_carga_datos.bad

  # 5.3 Distribuir staging -> modelo 3FN + limpiar (bloque "PASO 2" del archivo)
  docker exec -it districold-oracle sqlplus app_districold/CambieEstaClave_2026!@//localhost:1521/FREEPDB1 \
    @/opt/oracle/scripts_examen/05_carga_datos_paso2_distribucion.sql
  ```

  **Resultado real del log de SQL\*Loader:** `1000 Rows successfully loaded. 0 rejected. 0 discarded.`

  **Conteos post-distribución (idénticos, por diseño, a los de la solución en SQL Server sobre el mismo CSV):**

  | fabricante | forma_farmaceutica | ciudad | tipo_almacen | medicamento | lote | almacen | existencia | lectura_temperatura |
  |---:|---:|---:|---:|---:|---:|---:|---:|---:|
  | 18 | 6 | 10 | 3 | 67 | 259 | 25 | 1000 | 1000 |

- [x] **PASO 6 — Consultas de exploración (Etapa 4)**
  ```bash
  docker exec -it districold-oracle sqlplus app_districold/CambieEstaClave_2026!@//localhost:1521/FREEPDB1 \
    @/opt/oracle/scripts_examen/06_consultas_exploracion.sql
  ```
  Salida real en `../resultados/resultado_pregunta_{A,B,C}.csv`.

- [x] **PASO 7 — Función analítica de la Etapa 5**
  ```bash
  docker exec -it districold-oracle sqlplus app_districold/CambieEstaClave_2026!@//localhost:1521/FREEPDB1 \
    @/opt/oracle/scripts_examen/07_etapa5_window_functions_cte.sql
  ```
  Crea `fn_tendencia_temperatura_almacen` (retorna `SYS_REFCURSOR`) y la invoca con:
  ```sql
  VARIABLE cur REFCURSOR
  BEGIN
      :cur := fn_tendencia_temperatura_almacen;
  END;
  /
  PRINT cur
  ```
  162 filas de salida real en `../resultados/resultado_etapa5_tendencia_temperatura.csv`.

---

**Estado:** los 8 pasos anteriores fueron ejecutados de punta a punta contra un contenedor real de `gvenzl/oracle-free:latest` antes de armar esta entrega. Nada en `../resultados/` es dato de ejemplo.
