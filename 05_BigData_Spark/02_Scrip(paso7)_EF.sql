/* ============================================================================
   PASO 7 - BIG DATA: benchmark SQL Server vs Spark
   Proyecto: DataSalud Peru (CIIN1021P) - DIRESA La Libertad
   Carpeta del repositorio: BigData/

   Objetivo:
     Medir la MISMA consulta que se ejecuta en Spark (atenciones por provincia
     y categoria de establecimiento) con volumen creciente (factores 1 a 80).

   Requisitos:
     - Base DataSalud_DIRESA restaurada en la misma instancia.
     - Ejecutar por bloques (1 y 2). El bloque 2 tarda varios minutos.

   Salida:
     Una fila por factor con: filas, suma de control, primera corrida (s) y
     mediana de las corridas 2 a 4 (s). La suma de control debe coincidir con
     'Total atenciones' de la tabla de Spark en cada factor.

   Nota: el bloque 1 crea una base aparte para no tocar DataSalud_DIRESA y para
   poder usar recovery SIMPLE (evita que el log crezca con millones de filas).
   ============================================================================ */


/* ---------------------------------------------------------------------------
   BLOQUE 1: base de pruebas aislada (se puede re-ejecutar)
   --------------------------------------------------------------------------- */
USE master;
GO
IF DB_ID('DataSalud_BENCH') IS NULL
    CREATE DATABASE DataSalud_BENCH;
GO
ALTER DATABASE DataSalud_BENCH SET RECOVERY SIMPLE;
GO
USE DataSalud_BENCH;
GO
DROP TABLE IF EXISTS dbo.establecimientos;
DROP TABLE IF EXISTS dbo.atenciones_base;

SELECT id_establecimiento, provincia, categoria
INTO dbo.establecimientos
FROM DataSalud_DIRESA.dbo.establecimientos;

SELECT anio, mes, id_establecimiento, id_nivel, id_plan, id_servicio,
       sexo, id_grupo_edad, cantidad_atenciones
INTO dbo.atenciones_base
FROM DataSalud_DIRESA.dbo.atenciones;      -- sin id_atencion: evita la columna IDENTITY
GO

-- Verificacion (deben dar 36004 y 256448; la suma debe dar 2488976)
SELECT COUNT(*) AS filas_establecimientos FROM dbo.establecimientos;
SELECT COUNT(*) AS filas_atenciones       FROM dbo.atenciones_base;
SELECT SUM(CAST(cantidad_atenciones AS BIGINT)) AS total_factor_1 FROM dbo.atenciones_base;
GO


/* ---------------------------------------------------------------------------
   BLOQUE 2: benchmark - mismos factores que Spark
   Criterio: 4 corridas por factor; se reporta la primera por separado y la
   mediana de las corridas 2 a 4 (igual que la funcion medir() del notebook).
   --------------------------------------------------------------------------- */
USE DataSalud_BENCH;
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#res') IS NOT NULL DROP TABLE #res;
CREATE TABLE #res (factor INT, filas BIGINT, total BIGINT, corrida INT, ms DECIMAL(12,3));

DECLARE @factor INT, @corrida INT, @t0 DATETIME2(7), @ms DECIMAL(12,3),
        @filas BIGINT, @total BIGINT;

DECLARE fac CURSOR FOR SELECT v FROM (VALUES (1),(5),(10),(20),(40),(80)) AS f(v);
OPEN fac; FETCH NEXT FROM fac INTO @factor;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF OBJECT_ID('dbo.test_aten') IS NOT NULL DROP TABLE dbo.test_aten;

    -- Replica la tabla base 'factor' veces (simulacion de volumen)
    SELECT a.*
    INTO dbo.test_aten
    FROM dbo.atenciones_base a
    CROSS JOIN (SELECT TOP (@factor) 1 AS n
                FROM sys.all_objects x CROSS JOIN sys.all_objects y) k;

    -- Filas y suma de control (deben coincidir con 'Filas' y 'Total atenciones' de Spark)
    SELECT @filas = COUNT_BIG(*), @total = SUM(CAST(cantidad_atenciones AS BIGINT))
    FROM dbo.test_aten;

    SET @corrida = 1;
    WHILE @corrida <= 4
    BEGIN
        IF OBJECT_ID('tempdb..#tmp') IS NOT NULL DROP TABLE #tmp;
        SET @t0 = SYSDATETIME();

        -- El resultado va a una tabla temporal para no medir el dibujo de la grilla
        SELECT e.provincia, e.categoria,
               SUM(CAST(a.cantidad_atenciones AS BIGINT)) AS total_atenciones,
               COUNT(*) AS n_registros
        INTO #tmp
        FROM dbo.test_aten a
        JOIN dbo.establecimientos e ON a.id_establecimiento = e.id_establecimiento
        GROUP BY e.provincia, e.categoria
        ORDER BY total_atenciones DESC;

        SET @ms = DATEDIFF(MICROSECOND, @t0, SYSDATETIME()) / 1000.0;
        INSERT #res VALUES (@factor, @filas, @total, @corrida, @ms);
        SET @corrida += 1;
    END
    FETCH NEXT FROM fac INTO @factor;
END
CLOSE fac; DEALLOCATE fac;
DROP TABLE dbo.test_aten;

-- Resultado: pasar sqlserver_mediana_s al diccionario 'sqlserver' del notebook
WITH med AS (
    SELECT DISTINCT factor,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ms) OVER (PARTITION BY factor) AS med_ms
    FROM #res WHERE corrida > 1
)
SELECT r.factor,
       MAX(r.filas) AS filas,
       MAX(r.total) AS total_atenciones,
       CAST(MAX(CASE WHEN r.corrida = 1 THEN r.ms END)/1000.0 AS DECIMAL(10,3)) AS primera_s,
       CAST(MAX(m.med_ms)/1000.0 AS DECIMAL(10,3)) AS sqlserver_mediana_s
FROM #res r JOIN med m ON m.factor = r.factor
GROUP BY r.factor ORDER BY r.factor;
GO


/* ---------------------------------------------------------------------------
   LIMPIEZA (ejecutar solo al terminar de medir)
   --------------------------------------------------------------------------- */
-- USE master;
-- GO
-- DROP DATABASE DataSalud_BENCH;
