-- Verificaciones finales de cumplimiento

USE DataSalud_DIRESA;
GO

-- verificamos los usuarios y roles creados
SELECT
    dp.name AS usuario,
    r.name AS rol
FROM sys.database_role_members AS drm
INNER JOIN sys.database_principals AS r
    ON r.principal_id = drm.role_principal_id
INNER JOIN sys.database_principals AS dp
    ON dp.principal_id = drm.member_principal_id
WHERE r.name IN (
    'rol_administrador',
    'rol_analista',
    'rol_auditor'
);

-- verificamos que los logins tengan politica de contraseña activa
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

-- verificamos que existan los tres tipos de backup de la base
SELECT
    database_name,
    backup_start_date,
    backup_finish_date,
    type
FROM msdb.dbo.backupset
WHERE database_name = 'DataSalud_DIRESA'
ORDER BY backup_finish_date DESC;

-- verificamos que exista la tabla de auditoria
SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'auditoria'
AND TABLE_NAME = 'log_auditoria';

-- verificamos que los triggers de auditoria esten activos
SELECT
    t.name AS trigger_nombre,
    OBJECT_NAME(t.parent_id) AS tabla_asociada,
    t.is_disabled
FROM sys.triggers t
WHERE t.name IN (
    'trg_auditoria_establecimientos',
    'trg_auditoria_atenciones'
);

-- verificamos que el indice de la consulta critica exista
SELECT
    i.name AS indice,
    OBJECT_NAME(i.object_id) AS tabla,
    i.type_desc
FROM sys.indexes i
WHERE i.name = 'IX_atenciones_anio_mes_establecimiento';
