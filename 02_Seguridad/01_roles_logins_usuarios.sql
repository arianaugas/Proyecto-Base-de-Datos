-- Roles, logins y usuarios
-- Roles de base de datos
USE DataSalud_DIRESA;
GO

-- creamos los tres roles solicitados
CREATE ROLE rol_administrador;
CREATE ROLE rol_analista;
CREATE ROLE rol_auditor;

-- verificamos que los roles fueron creados
SELECT name
FROM sys.database_principals
WHERE type = 'R'
AND name IN ('rol_administrador', 'rol_analista', 'rol_auditor');


-- Logins con politica de contraseña activada desde el inicio
USE master;
GO

-- check_policy y check_expiration quedan activos desde la creacion
CREATE LOGIN login_administrador
WITH PASSWORD = 'Administrador2026!',
CHECK_POLICY = ON,
CHECK_EXPIRATION = ON;

CREATE LOGIN login_analista
WITH PASSWORD = 'Analista2026!',
CHECK_POLICY = ON,
CHECK_EXPIRATION = ON;

CREATE LOGIN login_auditor
WITH PASSWORD = 'Auditor2026!',
CHECK_POLICY = ON,
CHECK_EXPIRATION = ON;

-- verificamos los logins y que la politica quedo activa
SELECT
    name AS login,
    is_policy_checked,
    is_expiration_checked,
    is_disabled
FROM sys.sql_logins
WHERE name IN (
    'login_administrador',
    'login_analista',
    'login_auditor'
);


-- Usuarios de base de datos y asignacion a roles
USE DataSalud_DIRESA;
GO

CREATE USER user_administrador
FOR LOGIN login_administrador;

CREATE USER user_analista
FOR LOGIN login_analista;

CREATE USER user_auditor
FOR LOGIN login_auditor;


-- asignamos cada usuario a su rol
ALTER ROLE rol_administrador
ADD MEMBER user_administrador;

ALTER ROLE rol_analista
ADD MEMBER user_analista;

ALTER ROLE rol_auditor
ADD MEMBER user_auditor;

-- verificamos LOGIN -> USER -> ROLE
SELECT
    SUSER_SNAME(dp.sid) AS [LOGIN],
    dp.name AS [USER],
    r.name AS [ROLE]
FROM sys.database_principals dp
LEFT JOIN sys.database_role_members drm
    ON drm.member_principal_id = dp.principal_id
LEFT JOIN sys.database_principals r
    ON r.principal_id = drm.role_principal_id
WHERE dp.name IN (
    'user_administrador',
    'user_analista',
    'user_auditor'
);
