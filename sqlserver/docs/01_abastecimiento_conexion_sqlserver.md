# Etapas 1 y 2 — Abastecimiento y Conexión Remota (Microsoft SQL Server 2025)

**Integrante:** Juan José Arango Ocampo — ID SIGAA: 000549306
**Motor:** Microsoft SQL Server 2025, edición Developer (imagen `mcr.microsoft.com/mssql/server:2025-latest`)
**Infraestructura:** Contenedor Docker local (no se usó nube; sin bonificación).

## Etapa 1 — Abastecimiento

1. Requisito: Docker Desktop instalado y en ejecución.
2. Se definió el servicio `sqlserver-districold` en [`docker-compose.yml`](../../../docker-compose.yml), en la raíz del repositorio, usando la imagen `mcr.microsoft.com/mssql/server:2025-latest` con `MSSQL_PID=Developer` (edición gratuita para desarrollo/pruebas, con las mismas capacidades que Enterprise, restringida a uso no productivo).
3. Levantamiento del contenedor:
   ```bash
   docker compose up -d sqlserver-districold
   ```
4. Verificación de que el motor está listo:
   ```bash
   docker compose ps
   docker logs -f districold-sqlserver   # esperar "SQL Server is now ready for client connections"
   ```

**Evidencia — ambos contenedores del equipo corriendo** (`districold-sqlserver` sobre el puerto `1433`, junto a `districold-oracle` del compañero sobre el `1521`):

![docker compose ps mostrando ambos contenedores del equipo corriendo](image-4.png)

**Evidencia — log del contenedor con el mensaje de listo para conexiones:**

![Log de districold-sqlserver con el mensaje SQL Server is now ready for client connections](image-5.png)

## Etapa 2 — Conexión remota externa

- **Usuario administrativo:** `sa` (contraseña definida en `MSSQL_SA_PASSWORD` del `docker-compose.yml`).
- **Puerto TCP habilitado:** `1433` (puerto por defecto del motor SQL Server), publicado del contenedor al host mediante `ports: ["1433:1433"]` en `docker-compose.yml`.
- **Cadena de conexión:** `Server=localhost,1433;User Id=sa;Password=***;Encrypt=Optional`

### Pasos de conexión desde un IDE externo (DBeaver)

1. Crear nueva conexión **Microsoft SQL Server** (no el driver genérico de otro proveedor, ni MySQL — el ícono debe ser el logo oficial de Microsoft SQL Server).
2. Servidor: `localhost`, Puerto: `1433`, Database/Schema: `districold`.
3. Autenticación **SQL Server Authentication**, usuario `sa`, contraseña la definida en `MSSQL_SA_PASSWORD`.
4. Si el IDE exige "Trust Server Certificate", habilitarlo (certificado autofirmado local; no hay CA de confianza porque es una instancia local sin bonificación de nube).
5. Probar conexión y guardar.

**1) Formulario de conexión y prueba exitosa**, capturados en una misma ventana — host, puerto, base `districold`, usuario `sa`, y el detalle completo del servidor negociado (`Microsoft SQL Server 2025 (RTM-CU8)`, edición Enterprise Developer, driver JDBC 12.8):

![Formulario de conexión SQL Server en DBeaver y prueba de conexión exitosa](image.png)

**2) Consulta ejecutada con éxito** desde el editor SQL de DBeaver, ya conectado:

```sql
SELECT @@VERSION;
```

![Resultado de SELECT @@VERSION ejecutado desde DBeaver conectado a SQL Server](image-1.png)

**3) Exploración del esquema ya cargado**, confirmando desde el propio IDE que las 9 tablas del modelo 3FN existen dentro de la base `districold`:

![Listado de las 9 tablas del esquema districold vistas desde DBeaver](image-2.png)

**4) Detalle de columnas de una tabla del modelo** (`medicamento`), como evidencia adicional de que el modelo físico coincide con el diseño documentado en `../sql/02_secuencias_tablas.sql`:

![Columnas de la tabla medicamento vistas desde DBeaver](image-3.png)

> **Nota:** a diferencia de la conexión a Oracle (que sí presentó un incidente real, `ORA-12514`, documentado en `oracle/docs/01_abastecimiento_conexion_oracle.md`), la conexión a SQL Server se estableció exitosamente al primer intento — sin errores de configuración que depurar.

### Nota sobre cifrado en tránsito

Al tratarse de una instalación **local en Docker** (sin bonificación de nube), la conexión no sale de `localhost`, por lo que no se exigió verificación de certificado por una CA de confianza (`Trust Server Certificate` habilitado con el certificado autofirmado del propio contenedor). La bonificación por conexión cifrada verificada en la nube **no fue tomada** por este equipo en esta entrega.

### Creación de la base de datos, esquema y usuario de aplicación

Una vez conectado como `sa`, se ejecuta [`sql/01_usuario_esquema_privilegios.sql`](../sql/01_usuario_esquema_privilegios.sql) para crear la base `districold`, el esquema `districold` y el login/usuario de aplicación `app_districold` con privilegios mínimos (sin rol `sysadmin`).
