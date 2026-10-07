-- Permisos del administrador, analista y auditor
USE DataSalud_DIRESA;
GO

-- Permisos del administrador
-- puede administrar objetos de la base de datos
GRANT CREATE TABLE TO rol_administrador;

GRANT ALTER ON SCHEMA::dbo
TO rol_administrador;

GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_administrador;

GRANT VIEW DEFINITION TO rol_administrador;

-- puede consultar informacion de rendimiento
GRANT VIEW DATABASE STATE
TO rol_administrador;

-- puede ejecutar los backups de la politica de respaldo
GRANT BACKUP DATABASE, BACKUP LOG TO rol_administrador;

-- el administrador no puede modificar la bitacora de auditoria
DENY INSERT, UPDATE, DELETE
ON dbo.log_auditoria
TO rol_administrador;

-- Permisos del analista
-- puede consultar establecimientos
GRANT SELECT
ON dbo.establecimientos
TO rol_analista;

-- puede consultar atenciones
GRANT SELECT
ON dbo.atenciones
TO rol_analista;

-- puede consultar los catalogos
GRANT SELECT ON dbo.grupos_edad TO rol_analista;
GRANT SELECT ON dbo.servicios TO rol_analista;
GRANT SELECT ON dbo.planes_seguro TO rol_analista;
GRANT SELECT ON dbo.niveles_eess TO rol_analista;

-- el analista no puede modificar informacion
DENY INSERT, UPDATE, DELETE
ON dbo.establecimientos
TO rol_analista;

DENY INSERT, UPDATE, DELETE
ON dbo.atenciones
TO rol_analista;

-- el analista no puede acceder a la auditoria
DENY SELECT
ON dbo.log_auditoria
TO rol_analista;


-- Permisos del auditor
-- puede consultar la bitacora de auditoria
GRANT SELECT
ON dbo.log_auditoria
TO rol_auditor;

-- puede consultar la estructura de la base
GRANT VIEW DEFINITION TO rol_auditor;

-- el auditor no puede modificar informacion
DENY INSERT, UPDATE, DELETE
ON SCHEMA::dbo
TO rol_auditor;


-- mostramos los permisos asignados a los tres roles
SELECT
    USER_NAME(grantee_principal_id) AS rol,
    permission_name,
    state_desc,
    class_desc
FROM sys.database_permissions
WHERE USER_NAME(grantee_principal_id) IN (
    'rol_administrador',
    'rol_analista',
    'rol_auditor'
)
ORDER BY rol;
