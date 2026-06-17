# Ecommify — Diseño y optimización de base de datos políglota

Proyecto integrador de la plataforma e-commerce **Ecommify** sobre el dataset
**Brazilian E-commerce (Olist)**. Implementa una **arquitectura políglota** que combina
PostgreSQL (datos transaccionales) y MongoDB (módulo analítico y catálogo), con énfasis
en **optimización de rendimiento**: indexación especializada, particionamiento,
modelado de documentos, aggregation pipelines y diseño teórico de sharding/replica sets.

> Asignatura: EFMAS-DOBD20263 · Unidad 5 — Optimización de rendimiento · Equipo E01

---

## Arquitectura

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
   `12_constraints` → `13_tipos_avanzados_hibrido`.
3. Cargar datos de prueba:

   ```bash
   for f in postgresql/seed_data/*.sql; do psql "$DSN" -f "$f"; done
   ```
4. (Opcional) Reproducir las optimizaciones y mediciones de la Unidad 4:
   `Tarea4/scripts/01_indices.sql`, `Tarea4/scripts/02_particionamiento.sql`
   (resultados en `Tarea4/scripts/RESULTADOS_Parte2.md`).

> **Nota de diseño (enfoque híbrido):** el esquema base refleja la estructura real de
> Olist; el script `13_tipos_avanzados_hibrido.sql` añade `JSONB`, arrays y `pg_trgm`
> sobre esos datos reales. Ver justificación en `docs/seccion_f_lecciones_aprendidas.md`.

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
| b. Implementación PostgreSQL | `Tarea4/scripts/RESULTADOS_Parte2.md` + `postgresql/` |
| c. Implementación MongoDB + **sharding/replica sets** | `docs/seccion_c_sharding_replica_sets.md` |
| e. Sincronización y consistencia | `docs/seccion_e_sincronizacion_consistencia.md` |
| f. Lecciones aprendidas | `docs/seccion_f_lecciones_aprendidas.md` |

---

## Equipo E01

| Rol | Integrante | Responsabilidad |
|---|---|---|
| P1 | Carlos Arturo Salazar Castañeda | PostgreSQL: esquema, índices, particionamiento, EXPLAIN |
| P2 | Alejandro Miguel López Castañeda | MongoDB: colecciones, índices, aggregation pipeline |
| P3 | Carlos Alberto Zambrano Braydi | Documentación, repositorio, sharding teórico, ensamble |
| P4 | Camilo José Mora Rodríguez | Video de demostración |
