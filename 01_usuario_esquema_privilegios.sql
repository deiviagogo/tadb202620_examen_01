/*
====================================================================
 Examen No. 1 - Logica Almacenada en Base de Datos
 Cadena de frio de medicamentos - Distri-Cold
 Motor: Microsoft SQL Server 2025 (Docker local)
 Autor: Juan José Arango Ocampo - 000549306
 Archivo: 01_usuario_esquema_privilegios.sql
 Descripcion: Creacion de la base de datos, esquema, login/usuario de
              aplicacion y asignacion de privilegios minimos
              (principio de menor privilegio). Ejecutar conectado con
              el usuario administrativo "sa".
====================================================================
*/

-- 1. Base de datos del proyecto
IF DB_ID('districold') IS NULL
BEGIN
    CREATE DATABASE districold;
END
GO

USE districold;
GO

-- 2. Esquema dedicado del dominio
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'districold')
BEGIN
    EXEC('CREATE SCHEMA districold');
END
GO

-- 3. Login + usuario de aplicacion (no sysadmin) para uso desde el IDE / backend
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'app_districold')
BEGIN
    CREATE LOGIN app_districold WITH PASSWORD = 'CambieEstaClave_2026!', CHECK_POLICY = ON;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'app_districold')
BEGIN
    CREATE USER app_districold FOR LOGIN app_districold WITH DEFAULT_SCHEMA = districold;
END
GO

-- 4. Privilegios minimos: CRUD sobre el esquema districold, sin DDL ni roles de servidor
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA :: districold TO app_districold;
GRANT EXECUTE ON SCHEMA :: districold TO app_districold;
GO
