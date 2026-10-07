-- Script de restauracion 
-- orden de restauracion: FULL -> DIFFERENTIAL -> LOG

-- mostramos los nombres logicos de los archivos del backup
RESTORE FILELISTONLY
FROM DISK = 'C:\Backups\DataSalud_DIRESA_FULL.bak';
GO

-- restauramos el backup FULL en una base de prueba sin afectar la original
USE master;
GO

RESTORE DATABASE DataSalud_DIRESA_TEST
FROM DISK = 'C:\Backups\DataSalud_DIRESA_FULL.bak'
WITH
    MOVE 'DataSalud_DIRESA'
    TO 'C:\Program Files\Microsoft SQL Server\MSSQL\Data\DataSalud_DIRESA_TEST.mdf',

    MOVE 'DataSalud_DIRESA_log'
    TO 'C:\Program Files\Microsoft SQL Server\MSSQL\Data\DataSalud_DIRESA_TEST_log.ldf',

    NORECOVERY,
    REPLACE,
    STATS = 10;

-- restauramos el backup DIFFERENTIAL todavia sin recuperar
RESTORE DATABASE DataSalud_DIRESA_TEST
FROM DISK = 'C:\Backups\DataSalud_DIRESA_DIFF.bak'
WITH
    NORECOVERY,
    STATS = 10;

-- restauramos el backup LOG este vez con recovery para dejar la base operativa
RESTORE LOG DataSalud_DIRESA_TEST
FROM DISK = 'C:\Backups\DataSalud_DIRESA_LOG.trn'
WITH
    RECOVERY,
    STATS = 10;

-- verificamos que la base restaurada existe
SELECT
    name,
    state_desc
FROM sys.databases
WHERE name = 'DataSalud_DIRESA_TEST';

-- verificamos la integridad de la base restaurada
DBCC CHECKDB ('DataSalud_DIRESA_TEST')
WITH NO_INFOMSGS;

-- comparamos la cantidad de registros contra la base original
SELECT
    'establecimientos' AS tabla,
    COUNT(*) AS cantidad
FROM DataSalud_DIRESA_TEST.dbo.establecimientos

UNION ALL

SELECT
    'atenciones',
    COUNT(*)
FROM DataSalud_DIRESA_TEST.dbo.atenciones;

-- SELECT physical_name FROM sys.master_files WHERE database_id = DB_ID('DataSalud_DIRESA');
-- para ver la ruta 