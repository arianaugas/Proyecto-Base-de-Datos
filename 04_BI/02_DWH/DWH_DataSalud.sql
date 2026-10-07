
/*
    Se siguió la metodología de Ralph Kimball para el diseño del Data Warehouse.
    Grano de la tabla de hechos: una fila por cada combinación única de 
    establecimiento × mes × servicio × sexo × grupo de edad × plan de seguro × nivel de atención. 

    TABLA DE HECHOS: fact_atenciones
    fact_atencion_SK: Clave subrogada propia del hecho
    tiempo_SK: Referencia a dim_tiempo
    establecimiento_SK: Referencia a dim_establecimiento
    servicio_SK: Referencia a dim_servicio
    grupo_edad_SK: Referencia a dim_grupo_edad
    plan_seguro_SK:	Referencia a dim_plan_seguro
    nivel_eess_SK: Referencia a dim_nivel_eess
    sexo: Atributo degenerado (M/F)
    cantidad_atenciones: Métrica aditiva


    DIMENSIONES (6 en total):
    dim_tiempo (año, mes, nombre_mes, trimestre): Generada desde combinaciones únicas de año-mes en atenciones
    dim_establecimiento	(código IPRESS, nombre, ubicación geográfica, categoría, tipo, estado): Catálogo establecimientos
    dim_servicio (código, descripción) Catálogo servicios
    dim_grupo_edad (grupo de edad, rango etario amplio) Catálogo grupos_edad
    dim_plan_seguro (plan de seguro): Catálogo planes_seguro
    dim_nivel_eess (nivel de atención)	Catálogo niveles_eess


    DECISIONES DEL DISEÑO DIMENSIONAL
    sexo como atributo degenerado, sin dimensión propia: 
        por ser un atributo binario sin jerarquía ni atributos adicionales, 
        se dejó directamente en la tabla de hechos en vez de crear una dim_sexo de solo 2 filas.
    
    plan_seguro_SK y nivel_eess_SK como llaves nullable en el hecho: 
        se mantuvieron nullable porque en el OLTP origen (atenciones.id_plan, atenciones.id_nivel) 
        también lo son, no todo registro trae ese dato garantizado. Se resolvió mediante el 
        patrón de Unknown Member en vez de forzar NOT NULL y perder filas válidas.

    dim_tiempo generada solo con las combinaciones existentes, no un calendario completo: 
        se generó dim_tiempo únicamente con las combinaciones año-mes que existen en atenciones. 
        Esto se justifica porque el grano de análisis del proyecto es mensual, no diario.
    
    Enriquecimiento en dim_grupo_edad — rango_etario_amplio: 
        se agregó una columna derivada que agrupa los 6 grupos etarios 
        finos del dataset original en 5 categorías más amplias,
    
        00 - 04 AÑOS: Primera infancia
        05 - 11 AÑOS: Niñez
        12 - 17 AÑOS: Adolescencia
        18 - 29 AÑOS, 30 - 59 AÑOS: Adulto
        60 - MAS AÑOS: Adulto Mayor
*/




-- BASE DE DATOS: Data Warehouse
CREATE DATABASE DWH_DataSalud_DIRESA;
GO

USE DWH_DataSalud_DIRESA;
GO
-- DIMENSIÓN: Tiempo 
CREATE TABLE dim_tiempo (
    tiempo_SK INT IDENTITY(1,1) CONSTRAINT PK_dim_tiempo PRIMARY KEY,
    anio INT NOT NULL,
    mes INT NOT NULL,
    nombre_mes VARCHAR(30) NOT NULL,
    trimestre INT NOT NULL,
    CONSTRAINT UQ_dim_tiempo_anio_mes UNIQUE (anio, mes)
);

-- DIMENSIÓN: Establecimiento
CREATE TABLE dim_establecimiento (
    establecimiento_SK INT IDENTITY(1,1) CONSTRAINT PK_dim_establecimiento PRIMARY KEY,
    codigo_ipress VARCHAR(10) NOT NULL,
    nombre VARCHAR(200),
    departamento VARCHAR(200),
    provincia VARCHAR(200),
    distrito VARCHAR(200),
    categoria VARCHAR(50),
    tipo_establecimiento VARCHAR(200),
    estado VARCHAR(50),
    CONSTRAINT UQ_dim_establecimiento_codigo UNIQUE (codigo_ipress)
);

-- DIMENSIÓN: Servicio 
CREATE TABLE dim_servicio (
    servicio_SK INT IDENTITY(1,1) CONSTRAINT PK_dim_servicio PRIMARY KEY,
    cod_servicio NVARCHAR(5) NOT NULL,
    desc_servicio NVARCHAR(100),
    CONSTRAINT UQ_dim_servicio_cod UNIQUE (cod_servicio)
);

-- DIMENSIÓN: Grupo Edad
CREATE TABLE dim_grupo_edad (
    grupo_edad_SK INT IDENTITY(1,1) CONSTRAINT PK_dim_grupo_edad PRIMARY KEY,
    grupo_edad NVARCHAR(20) NOT NULL,
    rango_etario_amplio NVARCHAR(30) NOT NULL, 
    CONSTRAINT UQ_dim_grupo_edad_valor UNIQUE (grupo_edad)
);

-- DIMENSIÓN: Plan de Seguro
CREATE TABLE dim_plan_seguro (
    plan_seguro_SK INT IDENTITY(1,1) CONSTRAINT PK_dim_plan_seguro PRIMARY KEY,
    plan_seguro NVARCHAR(50) NOT NULL,
    CONSTRAINT UQ_dim_plan_seguro_valor UNIQUE (plan_seguro)
);

-- DIMENSIÓN: Nivel EESS
CREATE TABLE dim_nivel_eess (
    nivel_eess_SK INT IDENTITY(1,1) CONSTRAINT PK_dim_nivel_eess PRIMARY KEY,
    nivel_eess NVARCHAR(5) NOT NULL,
    CONSTRAINT UQ_dim_nivel_eess_valor UNIQUE (nivel_eess)
);

-- TABLA DE HECHOS: Atenciones
CREATE TABLE fact_atenciones (
    fact_atencion_SK INT IDENTITY(1,1) CONSTRAINT PK_fact_atenciones PRIMARY KEY,

    tiempo_SK INT NOT NULL
        CONSTRAINT FK_fact_tiempo REFERENCES dim_tiempo(tiempo_SK),
    establecimiento_SK INT NOT NULL
        CONSTRAINT FK_fact_establecimiento REFERENCES dim_establecimiento(establecimiento_SK),
    servicio_SK INT NOT NULL
        CONSTRAINT FK_fact_servicio REFERENCES dim_servicio(servicio_SK),
    grupo_edad_SK INT NOT NULL
        CONSTRAINT FK_fact_grupo_edad REFERENCES dim_grupo_edad(grupo_edad_SK),
    plan_seguro_SK INT NULL
        CONSTRAINT FK_fact_plan_seguro REFERENCES dim_plan_seguro(plan_seguro_SK),
    nivel_eess_SK INT NULL
        CONSTRAINT FK_fact_nivel_eess REFERENCES dim_nivel_eess(nivel_eess_SK),

    sexo CHAR(1)
        CONSTRAINT CK_fact_atenciones_sexo CHECK (sexo IN ('M','F')),

    cantidad_atenciones INT NOT NULL
        CONSTRAINT CK_fact_atenciones_cantidad CHECK (cantidad_atenciones >= 0)
);



-- TABLA DE CONTROL ETL
CREATE TABLE etl_control (
    proceso VARCHAR(50) NOT NULL CONSTRAINT PK_etl_control PRIMARY KEY,
    ultima_fecha_carga DATETIME NOT NULL
        CONSTRAINT DF_etl_control_fecha DEFAULT '1900-01-01',
    fecha_ultima_ejecucion DATETIME NULL,
    estado BIT NOT NULL CONSTRAINT DF_etl_control_estado DEFAULT 0, -- 0=en proceso/fallido, 1=exitoso
    filas_procesadas INT NULL,
    mensaje NVARCHAR(300) NULL
);
GO

-- LOG DETALLADO POR ETAPA (para auditar cada Data Flow Task)
CREATE TABLE log_ejecucion_etl (
    id_log INT IDENTITY(1,1) CONSTRAINT PK_log_ejecucion_etl PRIMARY KEY,
    proceso VARCHAR(50) NOT NULL,
    etapa VARCHAR(100) NOT NULL, --'dim_servicio', 'dim_establecimiento', 'fact_atenciones', etc
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NULL,
    filas_leidas INT NULL,
    filas_insertadas INT NULL,
    filas_actualizadas INT NULL,
    filas_rechazadas INT NULL,
    estado VARCHAR(20) NOT NULL
        CONSTRAINT CK_log_ejecucion_estado CHECK (estado IN ('INICIADO','EXITOSO','FALLIDO')),
    mensaje_error NVARCHAR(MAX) NULL
);
GO

-- (Unknown Member) en cada dimensión para evitar FKs huérfanas en el hecho
SET IDENTITY_INSERT dim_tiempo ON;
INSERT INTO dim_tiempo (tiempo_SK, anio, mes, nombre_mes, trimestre)
VALUES (0, 1900, 0, 'Desconocido', 0);
SET IDENTITY_INSERT dim_tiempo OFF;
GO

SET IDENTITY_INSERT dim_establecimiento ON;
INSERT INTO dim_establecimiento (establecimiento_SK, codigo_ipress, nombre, departamento, provincia, distrito, categoria, tipo_establecimiento, estado)
VALUES (0, 'DESCONOCID', 'Desconocido', 'Desconocido', 'Desconocido', 'Desconocido', 'Desconocido', 'Desconocido', 'Desconocido');
SET IDENTITY_INSERT dim_establecimiento OFF;
GO


SET IDENTITY_INSERT dim_servicio ON;
INSERT INTO dim_servicio (servicio_SK, cod_servicio, desc_servicio)
VALUES (0, 'DESC', 'Desconocido');
SET IDENTITY_INSERT dim_servicio OFF;
GO

SET IDENTITY_INSERT dim_grupo_edad ON;
INSERT INTO dim_grupo_edad (grupo_edad_SK, grupo_edad, rango_etario_amplio)
VALUES (0, 'Desconocido', 'Desconocido');
SET IDENTITY_INSERT dim_grupo_edad OFF;
GO

SET IDENTITY_INSERT dim_plan_seguro ON;
INSERT INTO dim_plan_seguro (plan_seguro_SK, plan_seguro)
VALUES (0, 'Desconocido');
SET IDENTITY_INSERT dim_plan_seguro OFF;
GO

SET IDENTITY_INSERT dim_nivel_eess ON;
INSERT INTO dim_nivel_eess (nivel_eess_SK, nivel_eess)
VALUES (0, 'Desco');
SET IDENTITY_INSERT dim_nivel_eess OFF;
GO

-- Registrar el proceso en la tabla de control (una vez, la primera vez)
INSERT INTO etl_control (proceso, ultima_fecha_carga, estado, mensaje)
VALUES ('ETL_DataSalud_LaLibertad', '1900-01-01', 0, 'Sin cargas aún');
GO



---------------------------------------------------------------------------------------------
USE DWH_DataSalud_DIRESA;
GO

-- Marca el inicio de una ejecución del ETL completo
CREATE OR ALTER PROCEDURE sp_etl_inicio
    @proceso VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM etl_control WHERE proceso = @proceso)
    BEGIN
        INSERT INTO etl_control (proceso, ultima_fecha_carga, fecha_ultima_ejecucion, estado, mensaje)
        VALUES (@proceso, '1900-01-01', GETDATE(), 0, 'Proceso iniciado (nuevo)');
    END
    ELSE
    BEGIN
        UPDATE etl_control
        SET estado = 0,
            fecha_ultima_ejecucion = GETDATE(),
            mensaje = 'Proceso iniciado'
        WHERE proceso = @proceso;
    END
END;
GO

-- Marca el fin exitoso del ETL completo
CREATE OR ALTER PROCEDURE sp_etl_fin_ok
    @proceso VARCHAR(50),
    @filas_procesadas INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE etl_control
    SET estado = 1,
        ultima_fecha_carga = GETDATE(),
        fecha_ultima_ejecucion = GETDATE(),
        filas_procesadas = @filas_procesadas,
        mensaje = 'Proceso finalizado correctamente'
    WHERE proceso = @proceso;
END;
GO

-- Marca el fin fallido del ETL completo
CREATE OR ALTER PROCEDURE sp_etl_fin_error
    @proceso VARCHAR(50),
    @mensaje NVARCHAR(300)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE etl_control
    SET estado = 0,
        fecha_ultima_ejecucion = GETDATE(),
        mensaje = @mensaje
    WHERE proceso = @proceso;
END;
GO

-- Log detallado por etapa (uno para iniciar, uno para cerrar)
CREATE OR ALTER PROCEDURE sp_log_etapa_inicio
    @proceso VARCHAR(50),
    @etapa VARCHAR(100),
    @id_log INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO log_ejecucion_etl (proceso, etapa, fecha_inicio, estado)
    VALUES (@proceso, @etapa, GETDATE(), 'INICIADO');

    SET @id_log = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE sp_log_etapa_fin
    @id_log INT,
    @filas_leidas INT = NULL,
    @filas_insertadas INT = NULL,
    @filas_actualizadas INT = NULL,
    @filas_rechazadas INT = NULL,
    @estado VARCHAR(20), -- 'EXITOSO' o 'FALLIDO'
    @mensaje_error NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE log_ejecucion_etl
    SET fecha_fin = GETDATE(),
        filas_leidas = @filas_leidas,
        filas_insertadas = @filas_insertadas,
        filas_actualizadas = @filas_actualizadas,
        filas_rechazadas = @filas_rechazadas,
        estado = @estado,
        mensaje_error = @mensaje_error
    WHERE id_log = @id_log;
END;
GO

