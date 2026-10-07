	/* 
	PROYECTO: DataSalud Perú - DIRESA La Libertad
	CAPA 1: STAGING
	propósito: recibir los datos crudos tal cual vienen del CSV, sin validar. 
	Todo como texto (NVARCHAR) para evitar que la carga falle por tipos de datos 
	inconsistentes. 
	nota: La validación real ocurrirá después, en procedimientos almacenados.
 */

CREATE DATABASE DataSalud_DIRESA;
USE DataSalud_DIRESA;

--Esquema donde se encontrarán las tablas de staging
CREATE SCHEMA staging;
GO

/****** Objeto: Table [staging].[staging_atenciones] Fecha de script: 19/09/2026 17:37:44 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [staging].[staging_atenciones](
	[AÑO] [nvarchar](50) NULL,
	[MES] [nvarchar](50) NULL,
	[REGION] [nvarchar](50) NULL,
	[PROVINCIA] [nvarchar](50) NULL,
	[UBIGEO_DISTRITO] [nvarchar](50) NULL,
	[DISTRITO] [nvarchar](50) NULL,
	[COD_UNIDAD_EJECUTORA] [nvarchar](50) NULL,
	[DESC_UNIDAD_EJECUTORA] [nvarchar](100) NULL,
	[COD_IPRESS] [nvarchar](50) NULL,
	[IPRESS] [nvarchar](100) NULL,
	[NIVEL_EESS] [nvarchar](50) NULL,
	[PLAN_SEGURO] [nvarchar](50) NULL,
	[COD_SERVICIO] [nvarchar](50) NULL,
	[DESC_SERVICIO] [nvarchar](100) NULL,
	[SEXO] [nvarchar](50) NULL,
	[GRUPO_EDAD] [nvarchar](50) NULL,
	[ATENCIONES] [nvarchar](50) NULL
) ON [PRIMARY]
GO



/****** Objeto: Table [staging].[staging_renipress] Fecha de script: 19/09/2026 17:38:38 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [staging].[staging_renipress](
	[INSTITUCION] [nvarchar](50) NULL,
	[COD_IPRESS] [nvarchar](50) NULL,
	[NOMBRE] [nvarchar](max) NULL,
	[CLASIFICACION] [nvarchar](max) NULL,
	[TIPO_ESTABLECIMIENTO] [nvarchar](100) NULL,
	[DEPARTAMENTO] [nvarchar](50) NULL,
	[PROVINCIA] [nvarchar](150) NULL,
	[DISTRITO] [nvarchar](150) NULL,
	[UBIGEO] [nvarchar](100) NULL,
	[DIRECCION] [nvarchar](150) NULL,
	[CO_DISA] [nvarchar](50) NULL,
	[COD_RED] [nvarchar](50) NULL,
	[COD_MICRORRED] [nvarchar](50) NULL,
	[DISA] [nvarchar](150) NULL,
	[RED] [nvarchar](150) NULL,
	[MICRORED] [nvarchar](150) NULL,
	[COD_UE] [nvarchar](150) NULL,
	[UNIDAD_EJECUTORA] [nvarchar](150) NULL,
	[CATEGORIA] [nvarchar](150) NULL,
	[TELEFONO] [nvarchar](150) NULL,
	[HORARIO] [nvarchar](150) NULL,
	[INICIO_ACTIVIDAD] [nvarchar](50) NULL,
	[ESTADO] [nvarchar](50) NULL,
	[NORTE] [nvarchar](50) NULL,
	[ESTE] [nvarchar](50) NULL,
	[IMAGEN_1] [nvarchar](150) NULL,
	[FE_ACT_IMAGEN_1] [nvarchar](50) NULL,
	[IMAGEN_2] [nvarchar](150) NULL,
	[FE_ACT_IMAGEN_2] [nvarchar](50) NULL,
	[IMAGEN_3] [nvarchar](150) NULL,
	[FE_ACT_IMAGEN_3] [nvarchar](50) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO




-- Nota: Después de haber creado el esquema de Staging con sus tablas se realizó la migración de los 
-- datos crudos del dataset hacia las tablas de staging (Ver la carpeta MigrarDatasetAStaging). 


/* 
	CAPA 2: TABLAS OPERACIONALES FINALES
	
	Para la creación de las tablas operaciones de la base de datos final
	se realizarón consultas sobre las tablas de staging con el propósito de 
	identificar las columnas con pocos valores distintos repetidos muchas veces, 
	esto para normalizar la base de datos sumado a eso, solo se tomaron en cuenta 
	las columnas que más nos interesan para la db final.

	propósito: datos limpios, tipados correctamente, con relaciones.
	Solo contienen las columnas que el proyecto realmente usará.
	
	Columnas tomadas en cuenta para las tablas finales:

	- Atenciones
	AÑO: Año de atención
	MES: Mes de atención
	NIVEL_EESS: Nivel de Establecimiento de Salud (I: Nivel II, II: Nivel II, III: Nivel III)
	PLAN_DE_SEGURO: Tipo de seguro SIS, asociado al listado de beneficios (prestaciones de salud) que brinda su cobertura financiera
	COD_SERVICIO: Código Prestacional
	DESC_SERVICIO: Descripción del Código Prestacional
	SEXO: (Masculino, Femenino)
	GRUPO_EDAD: Grupo edad de acuerdo a Normas MINSA Vigente 
	(00 - 04 Años, 05 - 11 Años, 12 - 17 Años, 18 - 29 Años, 30 - 59 Años, 60 - más Años)



	- Renipress (Establecimientos)
	INSTITUCION: Tipo de Institución a la que pertence la IPRESS
	CODIGO_IPRESS: Código Registro de la IPRESS (RENIPRESS)
	NOMBRE: Nombre de la IPRESS compuesto por 8 dígitos
	CATEGORIA: Categoría de la IPRESS
	CLASIFICACION: Clasificación de la IPRESS
	TIPO_ESTABLECIMIENTO: Tipo de Establecimiento de Salud
	DEPARTAMENTO: Nombre departamento donde se ubica la IPRESS
	PROVINCIA: Nombre provincia donde se ubica la IPRESS
	DISTRITO: Nombre distrito donde se ubica la IPRESS
	UBIGEO: Código de Ubigeo donde se ubica la IPRESS
	DIRECCION: Dirección de la IPRESS
	ESTADO: Estado de la IPRESS

	Columnas descartadas respecto a RENIPRESS original: DIRECCION, CODIGO_DISA/NOMBRE_DISA,
	CODIGO_RED/NOMBRE_RED, CODIGO_MICRORRED/NOMBRE_MICRORED, COD_UNIDAD_EJECUTORA/UNIDAD_EJECUTORA,
	TELEFONO_IPRESS, HORARIO_ATENCION, INICIO_ACTIVIDAD, LONGITUD_NORTE/ESTE, IMAGEN_*.
	Motivo: jerarquía administrativa interna, contacto y multimedia sin uso en los KPIs
	del proyecto (cobertura, atención promedio, morbilidad por grupo etario).
	
*/

-- Consultas realizadas sobre la tabla de staging

-- Cardinalidad de cada columna candidata a catálogo
select 'COD_SERVICIO' as columna, COUNT(distinct COD_SERVICIO) as valores_unicos, COUNT(*) as total_filas
from staging.staging_atenciones
union all
select 'GRUPO_EDAD', COUNT(distinct GRUPO_EDAD), COUNT(*)
from staging.staging_atenciones
union all
select 'PLAN_SEGURO', COUNT(distinct PLAN_SEGURO), COUNT(*)
from staging.staging_atenciones
union all
select 'SEXO', COUNT(distinct SEXO), COUNT(*)
from staging.staging_atenciones
union all
select 'NIVEL_EESS', COUNT(distinct NIVEL_EESS), COUNT(*)
from staging.staging_atenciones;

-- Valores realess de cada uno
select distinct COD_SERVICIO, DESC_SERVICIO from staging_atenciones order by COD_SERVICIO;
select distinct PLAN_SEGURO from staging_atenciones;
select distinct NIVEL_EESS from staging_atenciones;


-- Verificaciones de consistencia en las columnas de union de las tablas de staging
select * from staging.staging_atenciones sa
inner join staging.staging_renipress sr
on sa.COD_IPRESS=sr.COD_IPRESS;

select distinct COD_IPRESS from staging.staging_atenciones;

select distinct COD_IPRESS from staging.staging_renipress;

/*
nota: Se encontraron inconsistencias en los datos de las tablas de staging
	la columna de union de ambas tablas (COD_IPRESS) tenia distinto formato de padding,
	para resolver esto se decidió cambiar el formato de ese campo en el stored procedure
	que realiza la migración los datos hacia las tablas finales.
*/

--Primero visualizamos los datos con el cambio aplicado
select * from staging.staging_atenciones sa
inner join staging.staging_renipress sr
    on RIGHT('00000000' + LTRIM(RTRIM(sa.COD_IPRESS)), 8) = sr.COD_IPRESS;


-- Cantidad de codigos con match
SELECT COUNT(DISTINCT sa.COD_IPRESS) AS codigos_atenciones,
    COUNT(DISTINCT sr.COD_IPRESS) AS con_match
FROM staging.staging_atenciones sa
INNER JOIN staging.staging_renipress sr
    ON RIGHT('00000000' + LTRIM(RTRIM(sa.COD_IPRESS)), 8) = sr.COD_IPRESS;
-- todos con match



