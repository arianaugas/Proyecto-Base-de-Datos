# DataSalud Perú — DIRESA La Libertad

## Descripción
Proyecto integrador del curso: diseño e implementación de un
sistema de base de datos segura, automatizada e inteligente para la
gestión del ciclo de vida de los datos de salud de la DIRESA La Libertad.

## Problema
La DIRESA La Libertad no puede responder, con datos verificables, preguntas básicas de gestión —cuántas atenciones tuvo cada provincia, qué carga de morbilidad existe por grupo etario— porque sus datos llegan sin validación automática, sin control de acceso diferenciado, sin respaldo activo, y sin ningún modelo analítico que los consolide.

## Hipótesis
Si se automatiza la validación e ingesta de datos mediante procedimientos almacenados y triggers, se segrega el acceso por roles con auditoría activa conforme a la Ley N.° 29733, y se construye un modelo dimensional con procesos ETL confiables sobre el cual operan un cubo OLAP y un dashboard de indicadores, entonces la DIRESA La Libertad puede transformar reportes manuales propensos a error en decisiones de gestión de salud basadas en datos consistentes, trazables, auditables y analizables en tiempo real — con un modelo de arquitectura que, evaluado mediante Apache Spark, resulta además escalable frente al volumen creciente de datos del sector salud peruano.

## Estructura del repositorio
[Explicar brevemente cada carpeta, 1 línea por carpeta]

## Herramientas utilizadas
- SQL Server 2019+ (OLTP, DWH)
- SQL Server Integration Services (ETL)
- SQL Server Analysis Services - Multidimensional (cubo OLAP)
- Power BI Desktop (dashboard)
- Apache Spark / PySpark vía Google Colab (Big Data)
- [MongoDB u otro NoSQL que hayan usado]

## Instrucciones de revisión

El repositorio ya incluye las bases de datos restauradas (OLTP y DWH) listas
para inspección directa. Los scripts se dejan como evidencia del proceso de
construcción.

1. Descomprimir y restaurar la base OLTP con
   `01_Automatizacion/00_DATABASE_DataSalud_DIRESA.zip`.
2. Descomprimir y restaurar la base OLAP con
   `04_BI/02_DWH/DWH_DataSalud_DIRESA.zip`.
3. Revisar el proceso de staging y los scripts de migración en
   `01_Automatizacion/03_SPsMigracionStaginTablasFinales.sql` (procedimientos,
   validaciones y control transaccional ya aplicados sobre la base
   restaurada).
4. Revisar el modelo del Data Warehouse en `03_BI/DWH/DWH_DataSalud.sql`
   (tabla de hechos, dimensiones y relaciones ya reflejadas en la base
   restaurada).
5. Revisar el paquete ETL en `03_BI/01_ETL_SSIS/` (Control Flow, Data Flows
   por dimensión y carga del hecho).
6. Revisar el cubo OLAP en `03_BI/03_Cubo_SSAS/` (dimensiones, jerarquías y
   miembros calculados).
7. Abrir el dashboard `.pbix` y conectarlo al cubo para explorar los KPIs
   y las operaciones de drill-down / slice-dice.
8. Revisar el notebook de Spark en `04_BigData_Spark/Sparks_EF.ipynb`
   (ejecutable en Google Colab si se desea reproducir el benchmark).
