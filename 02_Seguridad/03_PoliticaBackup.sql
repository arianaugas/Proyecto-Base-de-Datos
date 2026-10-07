-- Politica de respaldo FULL + DIFFERENTIAL + LOG
-- configuramos el modelo de recuperacion FULL
USE master;
GO

ALTER DATABASE DataSalud_DIRESA
SET RECOVERY FULL;
GO

-- backup FULL
BACKUP DATABASE DataSalud_DIRESA
TO DISK = 'C:\Backups\DataSalud_DIRESA_FULL.bak'
WITH
    INIT,
    CHECKSUM,
    COMPRESSION,
    STATS = 10;
GO

-- backup DIFFERENTIAL
BACKUP DATABASE DataSalud_DIRESA
TO DISK = 'C:\Backups\DataSalud_DIRESA_DIFF.bak'
WITH
    DIFFERENTIAL,
    INIT,
    CHECKSUM,
    COMPRESSION,
    STATS = 10;
GO

-- backup LOG
--se usa NOINIT para no borrar los respaldos anteriores y poder recuperar la información hasta un momento especifico
BACKUP LOG DataSalud_DIRESA
TO DISK = 'C:\Backups\DataSalud_DIRESA_LOG.trn'
WITH
    NOINIT,
    CHECKSUM,
    COMPRESSION,
    STATS = 10;
GO

-- verificamos que el backup FULL sea valido
RESTORE VERIFYONLY
FROM DISK = 'C:\Backups\DataSalud_DIRESA_FULL.bak'
WITH CHECKSUM;

-- vemos los ultimos backups realizados, ya con los tres tipos
SELECT
    database_name,
    backup_start_date,
    backup_finish_date,
    type,
    CASE
        WHEN type = 'D' THEN 'FULL'
        WHEN type = 'I' THEN 'DIFFERENTIAL'
        WHEN type = 'L' THEN 'LOG'
    END AS tipo_backup
FROM msdb.dbo.backupset
WHERE database_name = 'DataSalud_DIRESA'
ORDER BY backup_finish_date DESC;
GO
