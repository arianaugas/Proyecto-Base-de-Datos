/*
Se implementaron 3 stored procedures con control transaccional (BEGIN TRANSACTION / COMMIT / ROLLBACK dentro de bloques TRY/CATCH):
*/

-- Procedimiento almacenado que migra los datos crudos de las tablas de staging a tablas normalizadas
-- con validacion por tipos de datos, seleccion de campos, eliminacion de duplicados y valores nulos.
CREATE OR ALTER PROCEDURE sp_migrar_catalogos
AS
BEGIN
    BEGIN TRY
        -- Creamos una transaccion para revertir cambios si ocurre un error
        BEGIN TRANSACTION;

        --Migra las edades por grupos en su tabla correspondiente
        INSERT INTO grupos_edad (grupo_edad)
        SELECT DISTINCT LTRIM(RTRIM(GRUPO_EDAD))
        FROM staging.staging_atenciones 
        WHERE GRUPO_EDAD IS NOT NULL -- no aceptamos datos nulos
            -- Validacion que rechaza filas duplicadas
            AND NOT EXISTS (
                SELECT 1 FROM grupos_edad ge 
                    WHERE ge.grupo_edad = LTRIM(RTRIM(staging.staging_atenciones.GRUPO_EDAD))
                );
        --Migra los tipos de planes seguros
        INSERT INTO planes_seguro(plan_seguro)
        SELECT DISTINCT LTRIM(RTRIM(PLAN_SEGURO))
        FROM staging.staging_atenciones
        WHERE PLAN_SEGURO IS NOT NULL -- no aceptamos datos nulos
            -- Validacion que rechaza filas duplicadas
            AND NOT EXISTS (
                    SELECT 1 FROM planes_seguro ps 
                        WHERE ps.plan_seguro = LTRIM(RTRIM(staging.staging_atenciones.PLAN_SEGURO))
                );
        
        --Migramos los niveles de atencion
        INSERT INTO niveles_eess (nivel_eess)
        SELECT DISTINCT LTRIM(RTRIM(NIVEL_EESS))
        FROM staging.staging_atenciones
        WHERE NIVEL_EESS IS NOT NULL -- no aceptamos datos nulos
            -- Validacion que rechaza filas duplicadas
            AND NOT EXISTS (
                SELECT 1 FROM niveles_eess ne 
                    WHERE ne.nivel_eess = LTRIM(RTRIM(staging.staging_atenciones.NIVEL_EESS))
            );

        --Migramos los tipos de servicios
        INSERT INTO servicios (cod_servicio, desc_servicio)
        SELECT DISTINCT LTRIM(RTRIM(COD_SERVICIO)), LTRIM(RTRIM(DESC_SERVICIO))
        FROM staging.staging_atenciones
        WHERE COD_SERVICIO IS NOT NULL -- no aceptamos datos nulos
            -- Validacion que rechaza filas duplicadas
            AND NOT EXISTS (
                SELECT 1 FROM servicios sv 
                    WHERE sv.cod_servicio = LTRIM(RTRIM(staging.staging_atenciones.COD_SERVICIO))
            );

        COMMIT TRANSACTION; -- confirmamos la transaccion
        PRINT 'Se migraron los datos exitosamente';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION; -- desacemos los cambios si hubo algún error
        THROW;
    END CATCH
END;
go


-- Migra staging.staging_renipress a establecimientos, registrando en log_rechazos las filas sin COD_IPRESS válido.
CREATE OR ALTER PROCEDURE sp_migrar_establecimientos
AS
BEGIN
    BEGIN TRY
        -- Creamos una transaccion para revertir cambios si ocurre un error
        BEGIN TRANSACTION;

        INSERT INTO establecimientos (
            institucion, codigo_ipress, nombre, categoria, clasificacion,
            tipo_establecimiento, departamento, provincia, distrito,
            ubigeo, direccion, estado
        )
        SELECT
            LTRIM(RTRIM(INSTITUCION)),
            LTRIM(RTRIM(COD_IPRESS)),
            LTRIM(RTRIM(NOMBRE)),
            LTRIM(RTRIM(CATEGORIA)),
            LTRIM(RTRIM(CLASIFICACION)),
            LTRIM(RTRIM(TIPO_ESTABLECIMIENTO)),
            LTRIM(RTRIM(DEPARTAMENTO)),
            LTRIM(RTRIM(PROVINCIA)),
            LTRIM(RTRIM(DISTRITO)),
            LTRIM(RTRIM(UBIGEO)),
            LTRIM(RTRIM(DIRECCION)),
            LTRIM(RTRIM(ESTADO))
        FROM staging.staging_renipress s
        WHERE COD_IPRESS IS NOT NULL -- no aceptamos que el codigo sea nulo
            -- Validacion que rechaza filas duplicadas
            AND NOT EXISTS (
                SELECT 1 FROM establecimientos e
                WHERE e.codigo_ipress = LTRIM(RTRIM(s.COD_IPRESS))
            );
        
        /*
        Validación de duplicados: 
        se definió que la clave de unicidad de una fila de atenciones es la combinación completa 
        (establecimiento, año, mes, servicio, sexo, grupo_edad, plan_seguro), no solo algunos campos, 
        porque el dataset origen trae múltiples filas legítimas por cada combinación demográfica distinta.
        */

        -- Registramos las filas sin código IPRESS (no se puede identificar el establecimiento)
        INSERT INTO log_rechazos (tabla_destino, motivo_rechazo, fila_original)
        SELECT
            'establecimientos',
            'COD_IPRESS nulo o vacío',
            CONCAT('NOMBRE = ', NOMBRE, ' | UBIGEO = ', UBIGEO, ' | DEPARTAMENTO = ', DEPARTAMENTO, ' | PROVINCIA = ', PROVINCIA)
        FROM staging.staging_renipress
        WHERE COD_IPRESS IS NULL OR LTRIM(RTRIM(COD_IPRESS)) = '';
        
        COMMIT TRANSACTION;
        PRINT 'Se migraron los datos exitosamente';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION; -- desacemos los cambios si ocurrió algun error
        THROW;
    END CATCH
END;
go



-- Procedimiento almacenado que migra staging.staging_atenciones a atenciones, resolviendo 
-- las llaves foráneas contra los catálogos ya migrados, normalizando el campo SEXO (acepta 
-- variantes como "MASCULINO"/"M"), y validando que AÑO, MES y ATENCIONES sean numéricos y 
-- coherentes. Las filas que no cumplen se registran en log_rechazos con el motivo específico.
CREATE OR ALTER PROCEDURE sp_migrar_atenciones
AS
BEGIN
    BEGIN TRY
        -- Creamos una transaccion para revertir cambios si ocurre un error
        BEGIN TRANSACTION;

        INSERT INTO atenciones (
            anio, mes, id_establecimiento,
            id_nivel, id_plan, id_servicio, sexo, id_grupo_edad, cantidad_atenciones
        )
        SELECT
            TRY_CAST(s.AÑO AS INT),
            TRY_CAST(s.MES AS INT),
            e.id_establecimiento,
            n.id_nivel,
            p.id_plan,
            sv.id_servicio,
            CASE
                -- Estandarización del género
                WHEN UPPER(LTRIM(RTRIM(s.SEXO))) IN ('M', 'MASCULINO') THEN 'M'
                WHEN UPPER(LTRIM(RTRIM(s.SEXO))) IN ('F', 'FEMENINO') THEN 'F'
                ELSE NULL
            END,
            g.id_grupo_edad,
            TRY_CAST(s.ATENCIONES AS INT)
        FROM staging.staging_atenciones s
        -- Condicion de union entre Establecimientos y Atenciones (codigo_ipress)
        INNER JOIN establecimientos e 
            -- estandarización de formato en codigo_ipress con el fin de poder realizar la union
            ON e.codigo_ipress = RIGHT('00000000' + LTRIM(RTRIM(s.COD_IPRESS)), 8)
        -- Uniones hacia sus catalogos
        LEFT JOIN niveles_eess n ON n.nivel_eess = LTRIM(RTRIM(s.NIVEL_EESS))
        LEFT JOIN planes_seguro p ON p.plan_seguro = LTRIM(RTRIM(s.PLAN_SEGURO))
        LEFT JOIN servicios sv ON sv.cod_servicio = LTRIM(RTRIM(s.COD_SERVICIO))
        LEFT JOIN grupos_edad g ON g.grupo_edad = LTRIM(RTRIM(s.GRUPO_EDAD))
        -- Validaciones, sin aceptar valores nulo o datos inconsistentes
        WHERE TRY_CAST(s.AÑO AS INT) IS NOT NULL
            AND TRY_CAST(s.MES AS INT) IS NOT NULL
            AND TRY_CAST(s.ATENCIONES AS INT) IS NOT NULL
            AND TRY_CAST(s.ATENCIONES AS INT) >= 0
            AND sv.id_servicio IS NOT NULL
            AND g.id_grupo_edad IS NOT NULL
            AND UPPER(LTRIM(RTRIM(s.SEXO))) IN ('M','MASCULINO','F','FEMENINO')
            -- Validacion que rechaza filas duplicadas
            AND NOT EXISTS (
                SELECT 1 FROM atenciones a
                WHERE a.id_establecimiento = e.id_establecimiento
                    AND a.anio = TRY_CAST(s.AÑO AS INT)
                    AND a.mes = TRY_CAST(s.MES AS INT)
                    AND a.id_servicio = sv.id_servicio
                    AND a.id_grupo_edad = g.id_grupo_edad
                    AND a.sexo = CASE WHEN UPPER(LTRIM(RTRIM(s.SEXO))) IN ('M','MASCULINO') THEN 'M' ELSE 'F' END
                    AND ISNULL(a.id_plan,-1) = ISNULL(p.id_plan,-1)
            ); 

        -- Insertamos las filas rechazadas en la tabla de log_rechazos
        INSERT INTO log_rechazos(tabla_destino, motivo_rechazo, fila_original)
        SELECT
            'atenciones',
            CASE
                WHEN e.id_establecimiento IS NULL THEN 'COD_IPRESS sin match en establecimientos'
                WHEN TRY_CAST(s.AÑO AS INT) IS NULL THEN 'AÑO inválido'
                WHEN TRY_CAST(s.MES AS INT) IS NULL THEN 'MES inválido'
                WHEN TRY_CAST(s.ATENCIONES AS INT) IS NULL THEN 'ATENCIONES no numérico'
                WHEN TRY_CAST(s.ATENCIONES AS INT) < 0 THEN 'ATENCIONES negativo'
                WHEN sv.id_servicio IS NULL THEN 'COD_SERVICIO sin match en catálogo servicios'
                WHEN g.id_grupo_edad IS NULL THEN 'GRUPO_EDAD sin match en catálogo grupos_edad'
                WHEN UPPER(LTRIM(RTRIM(s.SEXO))) NOT IN ('M','MASCULINO','F','FEMENINO') THEN 'SEXO inválido o vacío'
                ELSE 'Otro motivo no clasificado'
            END,
            CONCAT('COD_IPRESS = ', s.COD_IPRESS, ' | AÑO = ', s.AÑO, ' | MES = ', s.MES, ' | ATENCIONES = ', s.ATENCIONES,
                ' | SERVICIO = ', s.COD_SERVICIO, ' | GRUPO_EDAD = ', s.GRUPO_EDAD, ' | SEXO = ', s.SEXO)
        FROM staging.staging_atenciones s
        LEFT JOIN establecimientos e 
            ON e.codigo_ipress = RIGHT('00000000' + LTRIM(RTRIM(s.COD_IPRESS)), 8)
        LEFT JOIN servicios sv ON sv.cod_servicio = LTRIM(RTRIM(s.COD_SERVICIO))
        LEFT JOIN grupos_edad g ON g.grupo_edad = LTRIM(RTRIM(s.GRUPO_EDAD))
        WHERE e.id_establecimiento IS NULL
            OR TRY_CAST(s.AÑO AS INT) IS NULL
            OR TRY_CAST(s.MES AS INT) IS NULL
            OR TRY_CAST(s.ATENCIONES AS INT) IS NULL
            OR TRY_CAST(s.ATENCIONES AS INT) < 0
            OR sv.id_servicio IS NULL
            OR g.id_grupo_edad IS NULL
            OR UPPER(LTRIM(RTRIM(s.SEXO))) NOT IN ('M','MASCULINO','F','FEMENINO');

        COMMIT TRANSACTION; -- confirmamos
        PRINT 'Datos migrados correctamente.';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;



--Ejecutamos los sp
EXEC sp_migrar_catalogos;

EXEC sp_migrar_establecimientos;

EXEC sp_migrar_atenciones;

-- Verificamos si tenemos filas rechazadas 
select * from log_rechazos;

-- Cantidad de filas totales
select 'Atenciones',count(*) as Filas from atenciones
union all
select 'Establecimientos',count(*) from establecimientos;














