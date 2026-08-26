# Etapas 1 y 2 — Abastecimiento y Conexión Remota (Oracle Database Free 26ai)

**Integrante:** David Vallejo García — ID SIGAA: 000551513
**Motor:** Oracle Database Free 26ai (imagen `gvenzl/oracle-free:latest`, equivalente a Oracle Free 23ai/26ai)
**Infraestructura:** Contenedor Docker local (no se usó nube; sin bonificación).

## Etapa 1 — Abastecimiento

1. Requisito: Docker Desktop instalado y en ejecución.
2. Se definió el servicio `oracle-districold` en [`docker-compose.yml`](../../../docker-compose.yml), en la raíz del repositorio, usando la imagen `gvenzl/oracle-free:latest`.
3. Levantamiento del contenedor:
   ```bash
   docker compose up -d oracle-districold
   ```
4. Verificación de que el contenedor está saludable (el healthcheck de la imagen valida que la instancia y el PDB `FREEPDB1` estén listos):
   ```bash
   docker compose ps
   docker logs -f districold-oracle   # esperar "DATABASE IS READY TO USE!"
   ```
5. Salida de `docker compose ps` mostrando el contenedor `districold-oracle` saludable, junto al de SQL Server del compañero de equipo — captura conjunta disponible en [`sqlserver/docs/01_abastecimiento_conexion_sqlserver.md`](../../sqlserver/docs/01_abastecimiento_conexion_sqlserver.md#etapa-1--abastecimiento) (un solo `docker compose ps` cubre ambos contenedores del equipo, no se duplica la imagen en las dos carpetas).

## Etapa 2 — Conexión remota externa

- **Usuario administrativo:** `system` (contraseña definida en `ORACLE_PASSWORD` del `docker-compose.yml`).
- **Puerto TCP habilitado:** `1521` en el host, mapeado al `1521` del contenedor.
- **PDB (contenedor conectable) de trabajo:** `FREEPDB1`.
- **Cadena de conexión JDBC:** `jdbc:oracle:thin:@localhost:1521/FREEPDB1`

> **Nota sobre las capturas de esta sección:** fueron tomadas durante las pruebas de conexión realizadas con DBeaver contra este mismo contenedor Oracle Free, en un momento en que el puerto del host estaba temporalmente mapeado a `1522` (para poder correr en paralelo, en la misma máquina de desarrollo, una segunda instancia de Oracle usada para pruebas). La configuración final de este equipo, documentada arriba y en `docker-compose.yml`, expone el mismo servicio `FREEPDB1` en el puerto `1521`. El procedimiento de conexión (Service Name, no SID; usuario `system`) es idéntico en ambos casos.

### Pasos de conexión desde un IDE externo (DBeaver)

1. Crear nueva conexión Oracle.
2. Host: `localhost`, Puerto: `1521` (`1522` en las capturas, ver nota arriba), Servicio (**Service Name**, no SID): `FREEPDB1`.
3. Usuario: `system`, contraseña: la definida en `ORACLE_PASSWORD`.
4. Probar conexión ("Test Connection") y guardar.

**1) Formulario de conexión**, con Host, Puerto, Database en modo **Service Name** = `FREEPDB1`, usuario `system`:

![Formulario de conexión Oracle en DBeaver con FREEPDB1 como Service Name](image.png)

**2) Prueba de conexión exitosa**, reportando la identificación completa del servidor Oracle y del driver JDBC:

![Prueba de conexión exitosa a Oracle desde DBeaver — Conectado](image-1.png)

**3) Consulta ejecutada con éxito** desde el editor SQL de DBeaver ya conectado:

```sql
SELECT * FROM v$version;
```

![Resultado de SELECT * FROM v$version ejecutado desde DBeaver conectado a Oracle](image-2.png)

### Incidente real durante la configuración de la conexión, y cómo se resolvió

Al configurar por primera vez la conexión en DBeaver se produjo el error:

```
ORA-12514: No se puede conectar a la base de datos: el servicio %s
no está registrado con el listener en %s.
```

**Diagnóstico:** se verificó, desde dentro del contenedor, qué servicios tenía realmente registrados el listener de Oracle:

```bash
docker exec districold-oracle lsnrctl status
```

La salida confirmó que el listener sí tenía registrado el servicio `freepdb1`, lo que descartaba un problema del lado del contenedor. El problema estaba en el formulario de conexión de DBeaver: el campo **Database** tenía el valor de plantilla que trae el driver Oracle, `ORCL`, en vez de `FREEPDB1`, aunque el desplegable de al lado ya estaba correctamente puesto en modo **Service Name**.

**Corrección aplicada:** se reemplazó `ORCL` por `FREEPDB1` en el campo Database, dejando el modo en "Service Name", y se repitió la prueba de conexión — con éxito, como muestran las capturas anteriores.

### Nota sobre cifrado en tránsito

Al tratarse de una instalación **local en Docker** (sin bonificación de nube), la conexión no sale de `localhost`, por lo que no se configuró TLS/SSL para el listener. La bonificación por conexión cifrada en la nube **no fue tomada** por este equipo en esta entrega.

## Aprovisionamiento del usuario de aplicación

Con la conexión como `system` ya validada, se ejecutó [`sql/01_usuario_esquema_privilegios.sql`](../sql/01_usuario_esquema_privilegios.sql) para crear el usuario de aplicación `app_districold` con privilegios mínimos (sin rol DBA). Ver detalle de privilegios otorgados en ese script.
