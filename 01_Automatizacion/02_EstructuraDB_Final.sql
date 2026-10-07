
/*
Esta base sigue un diseño en tercera forma normal (3NF), con:
    Catálogos normalizados de baja cardinalidad: 
        grupos_edad, planes_seguro, niveles_eess, servicios. 
        Cada uno separa valores que se repiten muchas veces (ej. "SIS", "I-1") para evitar 
        redundancia de texto y permitir actualización centralizada.
    
    establecimientos: 
        entidad con los atributos descriptivos de cada IPRESS (institución, ubicación geográfica, categoría, estado).
    
    atenciones: 
        tabla central que registra la cantidad de atenciones por combinación de establecimiento, periodo (año/mes), 
        servicio, sexo, grupo de edad, plan de seguro y nivel de atención
        todas como llaves foráneas a los catálogos correspondientes.
    
    log_auditoria y log_rechazos: 
        tablas de soporte para trazabilidad de cambios y control de calidad de la migración.
*/

-- Tabla normalizada a partir de un análisis con consultas sobre las tablas de staging
CREATE TABLE grupos_edad (
    id_grupo_edad INT IDENTITY(1,1) CONSTRAINT PK_grupos_edad PRIMARY KEY,
    grupo_edad NVARCHAR(20) NOT NULL CONSTRAINT UQ_grupos_edad_valor UNIQUE
);

-- Tabla normalizada a partir de un análisis con consultas sobre las tablas de staging

CREATE TABLE planes_seguro (
    id_plan INT IDENTITY(1,1) CONSTRAINT PK_planes_seguro PRIMARY KEY,
    plan_seguro NVARCHAR(50) NOT NULL CONSTRAINT UQ_planes_seguro_valor UNIQUE
);

-- Tabla normalizada a partir de un análisis con consultas sobre las tablas de staging
-- contiene el nivel de....
CREATE TABLE niveles_eess (
    id_nivel INT IDENTITY(1,1) CONSTRAINT PK_niveles_eess PRIMARY KEY,
    nivel_eess NVARCHAR(5) NOT NULL CONSTRAINT UQ_niveles_eess_valor UNIQUE
);

-- Tabla normalizada a partir de un análisis con consultas sobre las tablas de staging
-- contiene codigo de servicio y descripción
CREATE TABLE servicios (
    id_servicio INT IDENTITY(1,1) CONSTRAINT PK_servicios PRIMARY KEY,
    cod_servicio NVARCHAR(5) NOT NULL CONSTRAINT UQ_servicios_cod UNIQUE,
    desc_servicio NVARCHAR(100)
);

-- TABLA: establecimientos, contiene los datos primordiales de los establecimientos del dataset
CREATE TABLE establecimientos (
    id_establecimiento INT IDENTITY(1,1) CONSTRAINT PK_establecimientos PRIMARY KEY,
    institucion VARCHAR(200),
    codigo_ipress VARCHAR(10) NOT NULL CONSTRAINT UQ_establecimientos_codigo_ipress UNIQUE,
    nombre VARCHAR(200),
    categoria VARCHAR(50),
    clasificacion VARCHAR(500),
    tipo_establecimiento VARCHAR(200),
    departamento VARCHAR(200),
    provincia VARCHAR(200),
    distrito VARCHAR(200),
    ubigeo VARCHAR(10),
    direccion VARCHAR(300),
    estado VARCHAR(50),
    fecha_carga DATETIME CONSTRAINT DF_establecimientos_fecha_carga DEFAULT GETDATE()
);

-- TABLA: atenciones, contiene claves foreaneas hacia las tablas donde se encuentran sus datos
CREATE TABLE atenciones (
    id_atencion INT IDENTITY(1,1) CONSTRAINT PK_atenciones PRIMARY KEY,
    anio INT NOT NULL CONSTRAINT CK_atenciones_anio_valido
    CHECK (anio >= 2020 AND anio <= YEAR(GETDATE())),
    mes INT NOT NULL CONSTRAINT CK_atenciones_mes_valido CHECK (mes BETWEEN 1 AND 12),
    id_establecimiento INT NOT NULL
        CONSTRAINT FK_atenciones_establecimiento REFERENCES establecimientos(id_establecimiento),
    id_nivel INT
        CONSTRAINT FK_atenciones_nivel REFERENCES niveles_eess(id_nivel),
    id_plan INT
        CONSTRAINT FK_atenciones_plan REFERENCES planes_seguro(id_plan),
    id_servicio INT
        CONSTRAINT FK_atenciones_servicio REFERENCES servicios(id_servicio),
    sexo CHAR(1) CONSTRAINT CK_atenciones_sexo CHECK (sexo IN ('M','F')),
    id_grupo_edad INT
        CONSTRAINT FK_atenciones_grupo_edad REFERENCES grupos_edad(id_grupo_edad),
    cantidad_atenciones INT NOT NULL
        CONSTRAINT CK_atenciones_cantidad_positiva CHECK (cantidad_atenciones >= 0),
    fecha_carga DATETIME CONSTRAINT DF_atenciones_fecha_carga DEFAULT GETDATE()
);


-- LOGS

-- Tabla de log que registra la el nombre de la tabla que fue afectada, la operación (evento), 
--el usuario responsable, la fecha y los valores antiguos y nuevos después del cambio.
-- psdt: Si la operación fue de 'INSERT' el campo valor_anterior queda en 'null'
-- y si la operación fue 'DELETE' el campo valor_nuevo queda en 'null'
CREATE TABLE log_auditoria (
    id_auditoria BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_log_auditoria PRIMARY KEY,
    tabla_afectada NVARCHAR(128) NOT NULL,
    operacion VARCHAR(10) NOT NULL
        CONSTRAINT CK_log_auditoria_operacion CHECK (operacion IN ('INSERT','UPDATE','DELETE')),
    usuario_bd NVARCHAR(128) NOT NULL CONSTRAINT DF_log_auditoria_usuario DEFAULT SUSER_SNAME(),
    host_origen NVARCHAR(128) NULL,
    aplicacion_origen NVARCHAR(128) NULL,
    fecha_hora DATETIME2(0) NOT NULL CONSTRAINT DF_log_auditoria_fecha DEFAULT SYSDATETIME(),
    valores_anteriores NVARCHAR(MAX) NULL,
    valores_nuevos NVARCHAR(MAX) NULL
);
GO

-- Tabla que registra todas las filas que fueron rechazadas durante la migracion 
-- de los datos crudos de las tablas de staging a las tablas finales
CREATE TABLE log_rechazos (
    id_rechazo INT IDENTITY(1,1) CONSTRAINT PK_log_rechazados PRIMARY KEY,
    tabla_destino VARCHAR(100),
    motivo_rechazo VARCHAR(300),
    fila_original NVARCHAR(MAX),
    fecha_rechazo DATETIME CONSTRAINT DF_log_rechazados_fecha DEFAULT GETDATE()
);



