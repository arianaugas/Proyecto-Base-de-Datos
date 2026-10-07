import csv
from pymongo import MongoClient, ASCENDING


# ============================================================
# CONFIGURACIÓN
# ============================================================

ARCHIVO_CSV = r"C:\DataSaludPeru\RENIPRESS_31-08-2026.csv"

MONGO_URI = "mongodb://localhost:27017/"
BASE_DATOS = "DataSaludPeru"
COLECCION = "renipress"

TAMANO_LOTE = 1000


# ============================================================
# CONEXIÓN A MONGODB
# ============================================================

print("Conectando a MongoDB...")

cliente = MongoClient(MONGO_URI)

db = cliente[BASE_DATOS]
coleccion = db[COLECCION]

# Verificar conexión
cliente.admin.command("ping")

print("Conexión a MongoDB correcta.")
print(f"Base de datos: {BASE_DATOS}")
print(f"Colección: {COLECCION}")


# ============================================================
# LIMPIAR COLECCIÓN SI YA EXISTE
# ============================================================

print("\nPreparando colección...")

coleccion.delete_many({})

print("Colección preparada.")


# ============================================================
# LECTURA DEL CSV
# ============================================================

print("\nLeyendo archivo CSV...")

lote = []

registros_leidos = 0
registros_insertados = 0


with open(
    ARCHIVO_CSV,
    mode="r",
    encoding="utf-8-sig",
    newline=""
) as archivo:

    lector = csv.DictReader(
        archivo,
        delimiter=";"
    )

    for fila in lector:

        registros_leidos += 1

        # ----------------------------------------------------
        # COD_IPRESS
        # ----------------------------------------------------

        codigo_ipress = fila["COD_IPRESS"].strip()

        # ----------------------------------------------------
        # DOCUMENTO MONGODB
        # ----------------------------------------------------

        documento = {
            "_id": codigo_ipress,

            "codigo_ipress": codigo_ipress,

            "nombre": fila["NOMBRE"].strip(),

            "institucion": fila["INSTITUCION"].strip(),

            "clasificacion": fila["CLASIFICACION"].strip(),

            "tipo_establecimiento": fila["TIPO_ESTABLECIMIENTO"].strip(),

            "ubicacion": {
                "departamento": fila["DEPARTAMENTO"].strip(),
                "provincia": fila["PROVINCIA"].strip(),
                "distrito": fila["DISTRITO"].strip(),
                "ubigeo": fila["UBIGEO"].strip(),
                "direccion": fila["DIRECCION"].strip()
            },

            "categoria": fila["CATEGORIA"].strip(),

            "estado": fila["ESTADO"].strip(),

            "red": {
                "disa": fila["DISA"].strip(),
                "red": fila["RED"].strip(),
                "microred": fila["MICRORED"].strip()
            },

            "geolocalizacion": {
                "norte": fila["NORTE"].strip(),
                "este": fila["ESTE"].strip()
            }
        }

        lote.append(documento)

        # ----------------------------------------------------
        # INSERTAR POR LOTES
        # ----------------------------------------------------

        if len(lote) >= TAMANO_LOTE:

            resultado = coleccion.insert_many(
                lote,
                ordered=False
            )

            registros_insertados += len(resultado.inserted_ids)

            print(
                f"Insertados: {registros_insertados:,}"
            )

            lote = []


# ============================================================
# INSERTAR ÚLTIMO LOTE
# ============================================================

if lote:

    resultado = coleccion.insert_many(
        lote,
        ordered=False
    )

    registros_insertados += len(resultado.inserted_ids)


# ============================================================
# CREAR ÍNDICES
# ============================================================

print("\nCreando índices...")

coleccion.create_index(
    [("codigo_ipress", ASCENDING)],
    unique=True,
    name="idx_codigo_ipress"
)

coleccion.create_index(
    [("ubicacion.departamento", ASCENDING)],
    name="idx_departamento"
)

coleccion.create_index(
    [("ubicacion.provincia", ASCENDING)],
    name="idx_provincia"
)

coleccion.create_index(
    [("ubicacion.distrito", ASCENDING)],
    name="idx_distrito"
)


# ============================================================
# RESULTADOS
# ============================================================

total_mongodb = coleccion.count_documents({})

print("\n========================================")
print("PROCESO FINALIZADO")
print("========================================")

print(f"Registros leídos del CSV: {registros_leidos:,}")
print(f"Registros insertados:     {registros_insertados:,}")
print(f"Documentos en MongoDB:    {total_mongodb:,}")

print("\nÍndices creados:")
for indice in coleccion.list_indexes():
    print(f" - {indice['name']}")

print("\nColección creada correctamente:")
print(f"{BASE_DATOS}.{COLECCION}")


# ============================================================
# CERRAR CONEXIÓN
# ============================================================

cliente.close()