# Gobernanza de Datos — KPIs del Dashboard
## Proyecto DataSalud Perú — DIRESA La Libertad

Este documento describe, para cada indicador presentado en el dashboard de Power BI conectado al cubo OLAP (`Cubo_Atenciones`), su fuente de datos, fórmula de cálculo, grano, responsable de actualización, frecuencia y criterios de calidad aplicados. Es la evidencia de gobernanza de datos requerida en la sección [1.6] del entregable.

---

## 1. Total de Atenciones por Provincia

| Campo | Detalle |
|---|---|
| **Página del dashboard** | Resumen Ejecutivo |
| **Pregunta de negocio que responde** | ¿Qué provincias de La Libertad concentran más atenciones, y por tanto necesitan más recursos? |
| **Fuente** | `fact_atenciones` (medida `Suma Atenciones`) + `dim_establecimiento` (atributo `Provincia`, dentro de `Jerarquia Establecimiento`) |
| **Fórmula de cálculo** | `SUM(cantidad_atenciones)` agrupado por `provincia` |
| **Grano** | Mensual (una fila del hecho por establecimiento × mes × servicio × sexo × grupo de edad × plan de seguro × nivel de atención) |
| **Responsable de actualización** | Equipo de datos DIRESA La Libertad |
| **Frecuencia de actualización** | Mensual, inmediatamente después de cada corrida exitosa del proceso ETL |
| **Criterio de calidad aplicado** | Las atenciones cuyo establecimiento no pudo resolverse durante el ETL (Surrogate Key = 0, "Desconocido") se incluyen en el total general pero quedan agrupadas bajo una categoría "Desconocido" separada de las provincias reales, evitando que se atribuyan incorrectamente a una provincia específica |

---

## 2. Promedio de Atenciones por Establecimiento

| Campo | Detalle |
|---|---|
| **Página del dashboard** | Resumen Ejecutivo |
| **Pregunta de negocio que responde** | ¿Qué tan cargado está, en promedio, cada centro de salud de la región? |
| **Fuente** | `fact_atenciones` (medidas `Suma Atenciones` y `Cantidad Establecimientos`) |
| **Fórmula de cálculo** | `SUM(cantidad_atenciones) / COUNT(DISTINCT establecimiento_SK)` — implementada como miembro calculado MDX `Promedio Atenciones por Establecimiento`, con manejo explícito de división por cero mediante `IIF` |
| **Grano** | Mensual |
| **Responsable de actualización** | Equipo de datos DIRESA La Libertad |
| **Frecuencia de actualización** | Mensual |
| **Criterio de calidad aplicado** | El conteo de establecimientos usa `DistinctCount`, por lo que un mismo establecimiento con múltiples filas de atención en el periodo no se cuenta más de una vez en el denominador |

---

## 3. Distribución de Atenciones por Grupo Etario

| Campo | Detalle |
|---|---|
| **Página del dashboard** | Perfil Demográfico |
| **Pregunta de negocio que responde** | ¿Qué grupo etario representa mayor carga de morbilidad, para orientar campañas de prevención? |
| **Fuente** | `fact_atenciones` (medida `Suma Atenciones`) + `dim_grupo_edad` (atributo `Rango Etario Amplio`, dentro de `Jerarquia Grupo Edad`) |
| **Fórmula de cálculo** | `SUM(cantidad_atenciones)` agrupado por `rango_etario_amplio` |
| **Grano** | Mensual |
| **Responsable de actualización** | Equipo de datos DIRESA La Libertad |
| **Frecuencia de actualización** | Mensual |
| **Criterio de calidad aplicado** | `rango_etario_amplio` es un atributo enriquecido durante el ETL: agrupa los 6 grupos etarios finos del dataset original del MINSA en 5 categorías alineadas a los programas de salud por edad (Primera infancia, Niñez, Adolescencia, Adulto, Adulto Mayor), reduciendo granularidad excesiva sin perder la posibilidad de drill-down al grupo etario fino cuando se requiere |

---

## 4. Tasa de Atenciones por Sexo

| Campo | Detalle |
|---|---|
| **Página del dashboard** | Perfil Demográfico |
| **Pregunta de negocio que responde** | ¿Existe una brecha relevante de atención entre hombres y mujeres que amerite una revisión de enfoque? |
| **Fuente** | `fact_atenciones` (atributo degenerado `sexo`, modelado en `Dim Sexo`) |
| **Fórmula de cálculo** | `SUM(cantidad_atenciones)` agrupado por `sexo`, expresado como porcentaje del total — miembros calculados MDX `Pct Atenciones Femenino` y `Pct Atenciones Masculino`, con manejo explícito de división por cero mediante `IIF` |
| **Grano** | Mensual |
| **Responsable de actualización** | Equipo de datos DIRESA La Libertad |
| **Frecuencia de actualización** | Mensual |
| **Criterio de calidad aplicado** | El campo `sexo` se normaliza desde el origen (acepta variantes como "MASCULINO"/"M") durante la migración staging → OLTP; valores no reconocidos se descartan y quedan registrados en `log_rechazos` con el motivo específico, por lo que el porcentaje reportado corresponde únicamente a registros con sexo válido y confirmado |

---

## 5. Evolución Mensual de Atenciones

| Campo | Detalle |
|---|---|
| **Página del dashboard** | Carga Operativa |
| **Pregunta de negocio que responde** | ¿La demanda de atenciones está creciendo, decreciendo o es estable mes a mes? |
| **Fuente** | `fact_atenciones` (medida `Suma Atenciones`) + `dim_tiempo` (atributo `Mes`, dentro de `Jerarquia Tiempo`) |
| **Fórmula de cálculo** | `SUM(cantidad_atenciones)` agrupado por `anio, mes` |
| **Grano** | Mensual (grano nativo de la dimensión tiempo del proyecto) |
| **Responsable de actualización** | Equipo de datos DIRESA La Libertad |
| **Frecuencia de actualización** | Mensual |
| **Criterio de calidad aplicado** | El orden cronológico del eje se garantiza mediante la propiedad `OrderBy = Key` configurada en el atributo `Mes` del cubo, de modo que la secuencia respeta el calendario real (Enero → Diciembre) independientemente del orden alfabético del texto mostrado |

---

## Indicador adicional de control de calidad (no es un KPI de negocio, es gobernanza interna)

### Porcentaje de Atenciones con Establecimiento No Resuelto

| Campo | Detalle |
|---|---|
| **Propósito** | Medir qué proporción de las atenciones cargadas no pudieron asociarse a un establecimiento real durante el proceso ETL, como señal de completitud del dato de origen |
| **Fuente** | `fact_atenciones` + `dim_establecimiento` (miembro "Desconocido", Surrogate Key = 0) |
| **Fórmula de cálculo** | Miembro calculado MDX `Pct Atenciones Establecimiento Desconocido`: `(Suma Atenciones del miembro Desconocido) / (Suma Atenciones total)` |
| **Responsable** | Equipo de datos DIRESA La Libertad |
| **Uso recomendado** | No se expone como visual central del dashboard; se consulta como indicador de salud del dato al revisar la calidad de una nueva carga ETL. Un valor elevado señalaría una degradación en la calidad del dataset de origen (por ejemplo, un aumento de códigos IPRESS sin coincidencia en el catálogo de establecimientos) |

---

## Principios de gobernanza aplicados de forma transversal

- **Trazabilidad del dato**: cada carga del ETL queda registrada en `log_ejecucion_etl`, con filas leídas, insertadas, actualizadas y su estado final — cualquier anomalía en un KPI puede rastrearse hasta la corrida específica que la originó.
- **Manejo explícito de datos faltantes**: siguiendo el patrón de Unknown Member de la metodología Kimball, ninguna atención se descarta por falta de un atributo secundario (plan de seguro, nivel de atención); se asocia a un miembro "Desconocido" en la dimensión correspondiente, preservando el hecho de negocio.
- **Fuente única de verdad**: todos los KPIs se calculan sobre el mismo modelo dimensional (`Cubo_Atenciones`), consultado en vivo desde Power BI mediante conexión directa (Live Connection) a Analysis Services — no existen copias desincronizadas de los datos entre el cubo y el dashboard.
- **Consistencia verificada**: el total general de `Suma Atenciones` se validó contra la suma equivalente en la capa OLTP (`SELECT SUM(cantidad_atenciones) FROM atenciones`), confirmando que el proceso ETL no pierde ni duplica información entre capas.
