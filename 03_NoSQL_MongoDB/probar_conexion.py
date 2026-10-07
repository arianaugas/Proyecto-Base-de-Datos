# =====================================================
# PROYECTO: DataSalud Perú
# PRUEBA DE CONEXIÓN SQL SERVER
# =====================================================

import pyodbc

SERVIDOR = "localhost"
BASE_DATOS = "DataSalud_DIRESA"

# Buscar un controlador ODBC disponible
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
    print("ERROR: No se encontró ODBC Driver 17 o 18 para SQL Server.")
    print("Controladores disponibles:")
    for d in drivers:
        print("-", d)
    raise SystemExit

print("Controlador encontrado:", driver)

conexion = pyodbc.connect(
    f"DRIVER={{{driver}}};"
    f"SERVER={SERVIDOR};"
    f"DATABASE={BASE_DATOS};"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"
)

print("CONEXIÓN EXITOSA")
print("Servidor:", SERVIDOR)
print("Base de datos:", BASE_DATOS)

conexion.close()

print("Conexión cerrada correctamente.")