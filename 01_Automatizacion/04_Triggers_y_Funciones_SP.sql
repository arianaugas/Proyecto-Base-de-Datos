
-- TRIGGER: Integridad, no permitir atenciones sobre un
-- establecimiento que no está ACTIVO.
CREATE OR ALTER TRIGGER trg_integridad_establecimiento_activo
ON atenciones
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN establecimientos e ON e.id_establecimiento = i.id_establecimiento
        WHERE UPPER(ISNULL(e.estado, '')) NOT IN ('ACTIVO', 'ACTIVA')
    )
        THROW 50001, 'No se pueden registrar atenciones para un establecimiento que no está activo.', 1;

END
GO


-- TRIGGER: auditoría sobre atenciones
CREATE OR ALTER TRIGGER trg_auditoria_atenciones
ON atenciones
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @operacion VARCHAR(10);

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @operacion = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @operacion = 'INSERT';
    ELSE
        SET @operacion = 'DELETE';

    -- INSERT y DELETE: se registra siempre, sin condición
    IF @operacion IN ('INSERT', 'DELETE')
    BEGIN
        INSERT INTO log_auditoria
            (tabla_afectada, operacion, usuario_bd, host_origen, aplicacion_origen,
            valores_anteriores, valores_nuevos)
        SELECT
            'atenciones',
            @operacion,
            SUSER_SNAME(),
            HOST_NAME(),
            APP_NAME(),
            (SELECT * FROM deleted FOR JSON AUTO),
            (SELECT * FROM inserted FOR JSON AUTO);
    END

    -- UPDATE: solo se registra si algo relevante realmente cambió
    IF @operacion = 'UPDATE'
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM inserted i
            INNER JOIN deleted d ON i.id_atencion = d.id_atencion
            WHERE i.cantidad_atenciones <> d.cantidad_atenciones
                OR i.id_establecimiento <> d.id_establecimiento
        )
        BEGIN
            INSERT INTO log_auditoria
                (tabla_afectada, operacion, usuario_bd, host_origen, aplicacion_origen,
                valores_anteriores, valores_nuevos)
            SELECT
                'atenciones',
                @operacion,
                SUSER_SNAME(),
                HOST_NAME(),
                APP_NAME(),
                (SELECT * FROM deleted FOR JSON AUTO),
                (SELECT * FROM inserted FOR JSON AUTO);
        END
    END
END;
GO

-- TRIGGER: auditoría sobre establecimientos
CREATE OR ALTER TRIGGER trg_auditoria_establecimientos
ON establecimientos
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @operacion VARCHAR(10);

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @operacion = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @operacion = 'INSERT';
    ELSE
        SET @operacion = 'DELETE';

    IF @operacion IN ('INSERT', 'DELETE')
    BEGIN
        INSERT INTO log_auditoria
            (tabla_afectada, operacion, usuario_bd, host_origen, aplicacion_origen,
            valores_anteriores, valores_nuevos)
        SELECT
            'establecimientos',
            @operacion,
            SUSER_SNAME(),
            HOST_NAME(),
            APP_NAME(),
            (SELECT * FROM deleted FOR JSON AUTO),
            (SELECT * FROM inserted FOR JSON AUTO);
    END

    IF @operacion = 'UPDATE'
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM inserted i
            INNER JOIN deleted d ON i.id_establecimiento = d.id_establecimiento
            WHERE ISNULL(i.estado,'') <> ISNULL(d.estado,'')
                OR ISNULL(i.categoria,'') <> ISNULL(d.categoria,'')
        )
        BEGIN
            INSERT INTO log_auditoria
                (tabla_afectada, operacion, usuario_bd, host_origen, aplicacion_origen,
                valores_anteriores, valores_nuevos)
            SELECT
                'establecimientos',
                @operacion,
                SUSER_SNAME(),
                HOST_NAME(),
                APP_NAME(),
                (SELECT * FROM deleted FOR JSON AUTO),
                (SELECT * FROM inserted FOR JSON AUTO);
        END
    END
END;
GO

/*
    Se optó por implementar la auditoría y validación de integridad como triggers en base de datos, 
    en vez de en la capa de aplicación, porque garantiza que, ninguna modificación a los datos
    sin importar desde qué cliente o proceso se origine, escape del registro de auditoría.
    La alternativa descartada (validar en la capa de aplicación) se rechazó porque no protege contra 
    modificaciones directas a la base de datos (por ejemplo, desde SSMS o un script ad-hoc), 
    que sí quedan cubiertas por el trigger.
*/





CREATE OR ALTER FUNCTION fn_total_atenciones_establecimiento (
    @codigo_ipress VARCHAR(10),
    @anio INT
)
RETURNS INT
AS
BEGIN
    DECLARE @total INT;

    SELECT @total = SUM(a.cantidad_atenciones)
    FROM atenciones a
    INNER JOIN establecimientos e ON e.id_establecimiento = a.id_establecimiento
    WHERE e.codigo_ipress = @codigo_ipress
        AND a.anio = @anio;

    RETURN ISNULL(@total, 0);
END;
go



CREATE OR ALTER FUNCTION fn_atenciones_por_provincia (@anio INT)
RETURNS TABLE
AS
RETURN (
    SELECT
        e.provincia,
        COUNT(DISTINCT e.id_establecimiento) AS establecimientos_activos,
        SUM(a.cantidad_atenciones) AS total_atenciones,
        AVG(CAST(a.cantidad_atenciones AS FLOAT)) AS promedio_atenciones_por_registro
    FROM atenciones a
    INNER JOIN establecimientos e ON e.id_establecimiento = a.id_establecimiento
    WHERE a.anio = @anio
    GROUP BY e.provincia
);
go


CREATE OR ALTER PROCEDURE sp_actualizar_cantidad_atencion
    @id_atencion INT,
    @nueva_cantidad INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @cantidad_actual INT;

        SELECT @cantidad_actual = cantidad_atenciones 
        FROM atenciones 
        WHERE id_atencion = @id_atencion;

        IF @cantidad_actual IS NULL
            THROW 50007, 'El id_atencion especificado no existe.', 1;

        IF @nueva_cantidad < 0
            THROW 50008, 'La cantidad de atenciones no puede ser negativa.', 1;

        IF @cantidad_actual = @nueva_cantidad
        BEGIN
            COMMIT TRANSACTION;
            PRINT 'No se realizó ningún cambio: la cantidad ya tenía ese valor.';
            RETURN;
        END

        UPDATE atenciones
        SET cantidad_atenciones = @nueva_cantidad
        WHERE id_atencion = @id_atencion;

        COMMIT TRANSACTION;
        PRINT 'Cantidad actualizada correctamente.';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- Probamos los triggers

-- Prueba trigger de auditoría (debe generar 1 fila en log_auditoria)
UPDATE atenciones SET cantidad_atenciones = cantidad_atenciones + 1 WHERE id_atencion = 1;
-- no genera ninguna fila
UPDATE atenciones SET cantidad_atenciones = cantidad_atenciones + 0 WHERE id_atencion = 1;

SELECT * FROM log_auditoria ORDER BY id_log DESC;

-- Prueba trigger de integridad (debe fallar si el establecimiento no está activo)
-- escojemos el id de un establecimiento q no esta activo
SELECT TOP 1 id_establecimiento FROM establecimientos WHERE UPPER(estado) NOT IN ('ACTIVO','ACTIVA');

-- Prueba funciones
SELECT * FROM dbo.fn_atenciones_por_provincia(2024);

--Obtenemos el codigo ipress
SELECT TOP 1 codigo_ipress from establecimientos;
SELECT dbo.fn_total_atenciones_establecimiento('00000001', 2024) AS TotalAtenciones;
