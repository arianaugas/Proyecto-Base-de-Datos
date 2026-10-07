-- Verificamos la cantidad de registros existentes en la tabla
-- final de atenciones.
SELECT COUNT(*) AS total_registros
FROM atenciones;
-- Verificamos la cantidad de registros cargados inicialmente
-- en la tabla de staging antes del proceso de transformación.
SELECT COUNT(*) AS total_staging
FROM staging.staging_atenciones;

-- Utilizamos esta consulta para obtener los registros de atenciones
-- junto con la información descriptiva de establecimientos,
-- servicios, planes de seguro, niveles de EESS y grupos de edad.
--
-- Se utilizaron INNER JOIN para establecer la relación obligatoria
-- con establecimientos y LEFT JOIN para recuperar información
-- complementaria cuando exista correspondencia.
SELECT
    a.id_atencion,
    a.anio,
    a.mes,
    a.sexo,
    a.cantidad_atenciones,

    g.grupo_edad,

    p.plan_seguro,

    n.nivel_eess,

    s.cod_servicio,
    s.desc_servicio,

    e.codigo_ipress,
    e.nombre AS nombre_establecimiento,
    e.categoria,
    e.departamento,
    e.provincia,
    e.distrito,
    e.ubigeo

FROM atenciones a

INNER JOIN establecimientos e
    ON e.id_establecimiento = a.id_establecimiento

LEFT JOIN grupos_edad g
    ON g.id_grupo_edad = a.id_grupo_edad

LEFT JOIN planes_seguro p
    ON p.id_plan = a.id_plan

LEFT JOIN niveles_eess n
    ON n.id_nivel = a.id_nivel

LEFT JOIN servicios s
    ON s.id_servicio = a.id_servicio

ORDER BY a.id_atencion;