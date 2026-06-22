# Ecommify — Diseño y optimización de base de datos políglota

Proyecto integrador de la plataforma e-commerce **Ecommify** sobre el dataset
**Brazilian E-commerce (Olist)**. Implementa una **arquitectura políglota** que combina
PostgreSQL (datos transaccionales) y MongoDB (módulo analítico y catálogo), con énfasis
en **optimización de rendimiento**: indexación especializada, particionamiento,
modelado de documentos, aggregation pipelines y diseño teórico de sharding/replica sets.

> Asignatura: EFMAS-DOBD20263 · Unidad 5 — Optimización de rendimiento · Equipo E01

---
## PResetnacion y sustentecion de arquitectura

https://drive.google.com/file/d/12NT4Gd8R7VCd7zA6xToBPnjOJtscFWGv/view?usp=sharing

## Arquitectura

<img width="1692" height="929" alt="image" src="https://github.com/user-attachments/assets/9a55ac74-5415-4ed9-b205-197b50191600" />



```
                 ┌─────────────────────────┐        Job ETL (upsert idempotente)
                 │   PostgreSQL (Supabase)  │  ───────────────────────────────────►  ┌────────────────────────┐
                 │   FUENTE DE VERDAD (CP)  │   datos maestros + métricas             │   MongoDB (Atlas)       │
                 │   orders, order_items,   │                                          │   MÓDULO ANALÍTICO (AP)│
                 │   payments, customers,   │  ◄── (no hay flujo de regreso de datos   │   products, reviews,    │
                 │   products, sellers      │       maestros; Mongo deriva/enriquece)  │   eventos analíticos    │
                 └─────────────────────────┘                                          └────────────────────────┘
```

- **PostgreSQL** prioriza integridad transaccional (compras, pagos).
- **MongoDB** prioriza disponibilidad y rendimiento de lectura analítica (consistencia eventual).
- Detalle de flujos y consistencia: [`docs/seccion_e_sincronizacion_consistencia.md`](docs/seccion_e_sincronizacion_consistencia.md).

---

## Estructura del repositorio

```
Ecommify_Database_Design/
├── postgresql/
│   ├── schema/            # DDL: tablas, tipos, índices, constraints, tipos avanzados (híbrido)
│   ├── seed_data/         # Datos de carga
│   └── queries/           # Consultas críticas y demostraciones de índices
├── mongodb/
│   └── schema/            # Colecciones, validadores JSON Schema, índices, pipelines
├── notebooks/             # Colab de EDA y carga documentados
├── docs/                  # Documento técnico (secciones), diseño teórico, presentación
└── README.md
```

---

## Requisitos previos

- **PostgreSQL 17** vía cuenta en [Supabase](https://supabase.com) (free tier).
- **MongoDB Atlas** cluster M0 (free tier).
- **Python 3.11+** con: `pip install pymongo pandas dnspython psycopg2-binary`
- Dataset Olist (CSV) — se descarga con `brazilian-ecommerce/download.py` (requiere `kaggle.json`).

---

## Setup PostgreSQL (Supabase)

1. Crear el proyecto en Supabase y obtener la cadena de conexión.
   - Para **DDL pesado** usar el **Session Pooler** (puerto `5432`).
   - Para queries normales sirve el **Transaction Pooler** (puerto `6543`).
2. Ejecutar los scripts de esquema **en orden** (desde el editor SQL de Supabase o con `psql`):

   ```bash
   export DSN="postgresql://USER:PASS@HOST:5432/postgres"
   for f in postgresql/schema/0*.sql postgresql/schema/1*.sql; do psql "$DSN" -f "$f"; done
   ```

   Orden: `01_extensions` → `02_types` → `03..10` (tablas) → `11_indexes` →
   `12_constraints`. El script `13_tipos_avanzados_hibrido.sql` es **opcional**
   (ver nota de diseño más abajo).
3. Cargar datos de prueba:

   ```bash
   for f in postgresql/seed_data/*.sql; do psql "$DSN" -f "$f"; done
   ```
4. (Opcional) Reproducir las optimizaciones y mediciones de la Unidad 4:
   `Tarea4/scripts/01_indices.sql`, `Tarea4/scripts/02_particionamiento.sql`
   (resultados en `Tarea4/scripts/RESULTADOS_Parte2.md`).

> **Nota de diseño:** la entrega usa el esquema relacional real de Olist sin campos
> `JSONB`; la flexibilidad documental se concentra en MongoDB (patrón Attribute/Embedding).
> El script `13_tipos_avanzados_hibrido.sql` (JSONB, arrays, `pg_trgm`/GIN sobre los datos
> reales) queda como **propuesta de evolución futura**, no ejecutada en este entregable.

---

## Setup MongoDB (Atlas)

1. Crear un cluster M0 y un usuario de base de datos; copiar el connection string.
2. Cargar el catálogo y reseñas con el script de carga (deriva métricas con Computed Pattern):

   ```bash
   export MONGODB_URI="mongodb+srv://USER:PASS@cluster0.xxxxx.mongodb.net/?retryWrites=true&w=majority"
   export OLIST_CSV_DIR="../brazilian-ecommerce"
   python Ejercicio3/carga_validacion_mongodb_etapa1.py
   ```
3. Aplicar validadores JSON Schema, índices y pipelines desde `mongodb/schema/`
   (ver scripts en esa carpeta).

---

## Reproducibilidad

- Todos los scripts SQL son **idempotentes** donde aplica (`IF NOT EXISTS`).
- La carga de MongoDB hace **upsert por `_id`**: reejecutar no duplica datos.
- Las evidencias de rendimiento (EXPLAIN / `.explain()`) están en `docs/` y en
  `Tarea4/scripts/RESULTADOS_Parte2.md`.

---

## Documento técnico (secciones)

| Sección | Archivo |
|---|---|
| **Documento ensamblado (a–f) + repo + video** | `docs/Documento_Tecnico_Ecommify_E01.docx` (generado por `docs/gen_docx.py`) |
| b. Implementación PostgreSQL | `Tarea4/scripts/RESULTADOS_Parte2.md` + `postgresql/` |
| c. Implementación MongoDB + **sharding/replica sets** | `docs/seccion_c_sharding_replica_sets.md` + `mongodb/schema/` |
| e. Sincronización y consistencia | `docs/seccion_e_sincronizacion_consistencia.md` |
| f. Lecciones aprendidas | `docs/seccion_f_lecciones_aprendidas.md` |
| Evidencias (gráficas + capturas EXPLAIN) | `evidencias/` |

---

## Equipo E01

| Integrante | Código |
|---|---|
| Camilo José Mora Rodríguez | 0000394950 |
| Carlos Alberto Zambrano Braydi | 0000395349 |
| Alejandro Miguel López Castañeda | 0000385228 |
| Carlos Arturo Salazar Castañeda | 0000393238 |
