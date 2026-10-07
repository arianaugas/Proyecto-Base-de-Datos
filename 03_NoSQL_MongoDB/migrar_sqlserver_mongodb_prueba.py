# =====================================================
# PROYECTO: DataSalud Perú
# CURSO: Base de Datos Avanzadas y Big Data
#
# MIGRACIÓN: SQL SERVER -> MONGODB
#
# Fuente:
#   Base de datos: DataSalud_DIRESA
#   Servidor: localhost
#   Tabla principal: atenciones
#
# Destino:
#   MongoDB: DataSaludPeru
#   Colección: atenciones_salud
# =====================================================

import pyodbc
from pymongo import MongoClient


# =====================================================
# 1. CONFIGURACIÓN
# =====================================================

SERVIDOR_SQL = "localhost"
BASE_DATOS_SQL = "DataSalud_DIRESA"

MONGO_URI = "mongodb://localhost:27017/"
BASE_DATOS_MONGO = "DataSaludPeru"
COLECCION_MONGO = "atenciones_salud"

# PRIMERA PRUEBA:
# True  = solamente procesa 5 registros
# False = procesa los 256,448 registros
MODO_PRUEBA = True

TAMANO_LOTE = 1000


# =====================================================
# 2. CONSULTA SQL
# =====================================================

CONSULTA_SQL = """
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
"""


# =====================================================
# 3. CONEXIÓN A SQL SERVER
# =====================================================

def conectar_sql_server():

    drivers = pyodbc.drivers()

    driver = None

    for d in drivers:
        if "ODBC Driver 18 for SQL Server" in d:
            driver = d
            break
        elif "ODBC Driver 17 for SQL Server" in d:
            driver = d
            break

    if driver is None:
        raise Exception(
            "No se encontró ODBC Driver 17 o 18 para SQL Server."
        )

    print("Controlador SQL:", driver)

    conexion = pyodbc.connect(
        f"DRIVER={{{driver}}};"
        f"SERVER={SERVIDOR_SQL};"
        f"DATABASE={BASE_DATOS_SQL};"
        "Trusted_Connection=yes;"
        "TrustServerCertificate=yes;"
    )

    return conexion


# =====================================================
# 4. TRANSFORMAR FILA SQL A DOCUMENTO MONGODB
# =====================================================

def convertir_documento(row):

    documento = {
        "_id": int(row.id_atencion),

        "id_atencion": int(row.id_atencion),

        "periodo": {
            "anio": int(row.anio) if row.anio is not None else None,
            "mes": int(row.mes) if row.mes is not None else None
        },

        "establecimiento": {
            "codigo_ipress": str(row.codigo_ipress).strip()
            if row.codigo_ipress is not None else None,

            "nombre": str(row.nombre_establecimiento).strip()
            if row.nombre_establecimiento is not None else None,

            "categoria": str(row.categoria).strip()
            if row.categoria is not None else None,

            "departamento": str(row.departamento).strip()
            if row.departamento is not None else None,

            "provincia": str(row.provincia).strip()
            if row.provincia is not None else None,

            "distrito": str(row.distrito).strip()
            if row.distrito is not None else None,

            "ubigeo": str(row.ubigeo).strip()
            if row.ubigeo is not None else None
        },

        "nivel_eess": str(row.nivel_eess).strip()
        if row.nivel_eess is not None else None,

        "plan_seguro": str(row.plan_seguro).strip()
        if row.plan_seguro is not None else None,

        "servicio": {
            "codigo": str(row.cod_servicio).strip()
            if row.cod_servicio is not None else None,

            "descripcion": str(row.desc_servicio).strip()
            if row.desc_servicio is not None else None
        },

        "paciente": {
            "sexo": str(row.sexo).strip()
            if row.sexo is not None else None,

            "grupo_edad": str(row.grupo_edad).strip()
            if row.grupo_edad is not None else None
        },

        "cantidad_atenciones": int(row.cantidad_atenciones)
        if row.cantidad_atenciones is not None else None
    }

    return documento


# =====================================================
# 5. PROCESO PRINCIPAL
# =====================================================

def main():

    print("=" * 60)
    print("MIGRACIÓN SQL SERVER -> MONGODB")
    print("PROYECTO: DataSalud Perú")
    print("=" * 60)

    # -------------------------------------------------
    # Conectar a SQL Server
    # -------------------------------------------------

    conexion_sql = conectar_sql_server()

    cursor = conexion_sql.cursor()

    print("Conexión SQL Server: OK")

    # -------------------------------------------------
    # Conectar a MongoDB
    # -------------------------------------------------

    cliente_mongo = MongoClient(MONGO_URI)

    db = cliente_mongo[BASE_DATOS_MONGO]

    coleccion = db[COLECCION_MONGO]

    print("Conexión MongoDB: OK")
    print("Base:", BASE_DATOS_MONGO)
    print("Colección:", COLECCION_MONGO)

    # -------------------------------------------------
    # Ejecutar consulta
    # -------------------------------------------------

    print("\nEjecutando consulta SQL...")

    cursor.execute(CONSULTA_SQL)

    documentos = []

    contador = 0

    # -------------------------------------------------
    # Leer registros
    # -------------------------------------------------

    for row in cursor:

        documento = convertir_documento(row)

        documentos.append(documento)

        contador += 1

        # En modo prueba solo procesamos 5
        if MODO_PRUEBA and contador >= 5:
            break

        # Insertar por lotes
        if len(documentos) >= TAMANO_LOTE:

            coleccion.insert_many(
                documentos,
                ordered=False
            )

            print(
                f"Insertados: {contador:,} registros"
            )

            documentos = []

    # -------------------------------------------------
    # Insertar último lote
    # -------------------------------------------------

    if documentos:

        coleccion.insert_many(
            documentos,
            ordered=False
        )

    # -------------------------------------------------
    # Mostrar resultado
    # -------------------------------------------------

    print("\n" + "=" * 60)

    if MODO_PRUEBA:

        print("MODO PRUEBA ACTIVADO")

    else:

        print("MIGRACIÓN COMPLETA")

    print(f"Registros procesados: {contador:,}")

    total_mongo = coleccion.count_documents({})

    print(
        f"Documentos actualmente en MongoDB: "
        f"{total_mongo:,}"
    )

    print("=" * 60)

    # -------------------------------------------------
    # Cerrar conexiones
    # -------------------------------------------------

    cursor.close()
    conexion_sql.close()
    cliente_mongo.close()

    print("Proceso finalizado correctamente.")


# =====================================================
# 6. EJECUCIÓN
# =====================================================

if __name__ == "__main__":
    main()