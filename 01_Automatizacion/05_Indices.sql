-- Consulta critica: plan de ejecucion, indice y metricas

USE DataSalud_DIRESA;
GO

-- medicion ANTES del indice
-- consulta base
SELECT
    e.departamento,
    e.id_establecimiento,
    e.nombre,
    SUM(a.cantidad_atenciones) AS total_atenciones
FROM atenciones AS a
INNER JOIN establecimientos AS e
    ON e.id_establecimiento = a.id_establecimiento
WHERE a.anio = 2024
GROUP BY
    e.departamento,
    e.id_establecimiento,
    e.nombre
ORDER BY total_atenciones DESC;

-- activamos metricas de lecturas y tiempo (evidencia numerica)
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    e.departamento,
    e.id_establecimiento,
    e.nombre,
    SUM(a.cantidad_atenciones) AS total_atenciones
FROM atenciones AS a
INNER JOIN establecimientos AS e
    ON e.id_establecimiento = a.id_establecimiento
WHERE a.anio = 2024
GROUP BY
    e.departamento,
    e.id_establecimiento,
    e.nombre
ORDER BY total_atenciones DESC;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

-- activamos la captura del plan de ejecución para guardar evidencia y comprobar cómo se realiza la consulta antes de crear el índice.
SET STATISTICS XML ON;

SELECT
    e.departamento,
    e.id_establecimiento,
    e.nombre,
    SUM(a.cantidad_atenciones) AS total_atenciones
FROM atenciones AS a
INNER JOIN establecimientos AS e
    ON e.id_establecimiento = a.id_establecimiento
WHERE a.anio = 2024
GROUP BY
    e.departamento,
    e.id_establecimiento,
    e.nombre
ORDER BY total_atenciones DESC;

SET STATISTICS XML OFF;


-- creacion del indice
CREATE NONCLUSTERED INDEX IX_atenciones_anio_mes_establecimiento
ON dbo.atenciones(anio, mes,id_establecimiento)
INCLUDE (cantidad_atenciones);

GO

-- actualizamos las estadisticas de la tabla
UPDATE STATISTICS dbo.atenciones
WITH FULLSCAN;


-- medicion DESPUES del indice

-- metricas numericas
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    e.departamento,
    e.id_establecimiento,
    e.nombre,
    SUM(a.cantidad_atenciones) AS total_atenciones
FROM atenciones AS a
INNER JOIN establecimientos AS e
    ON e.id_establecimiento = a.id_establecimiento
WHERE a.anio = 2024
GROUP BY
    e.departamento,
    e.id_establecimiento,
    e.nombre
ORDER BY total_atenciones DESC;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

-- plan de ejecucion real despues del indice
-- después de crear el índice el plan debe mostrar una búsqueda más eficiente (Index Seek) en lugar de revisar toda la tabla (Scan)
SET STATISTICS XML ON;

SELECT
    e.departamento,
    e.id_establecimiento,
    e.nombre,
    SUM(a.cantidad_atenciones) AS total_atenciones
FROM atenciones AS a
INNER JOIN establecimientos AS e
    ON e.id_establecimiento = a.id_establecimiento
WHERE a.anio = 2024
GROUP BY
    e.departamento,
    e.id_establecimiento,
    e.nombre
ORDER BY total_atenciones DESC;

SET STATISTICS XML OFF;
