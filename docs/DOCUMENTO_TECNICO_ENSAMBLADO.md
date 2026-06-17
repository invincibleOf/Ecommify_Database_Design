# Implementación técnica completa en PostgreSQL y MongoDB
### Entregable 2 — Proyecto integrador Ecommify · Arquitectura políglota
**Dataset:** Brazilian E-commerce (Olist) · **Equipo E01** · Asignatura EFMAS-DOBD20263 · Junio 2026

| Rol | Integrante |
|---|---|
| P1 — PostgreSQL | Carlos Arturo Salazar Castañeda |
| P2 — MongoDB | Alejandro Miguel López Castañeda |
| P3 — Documentación/ensamble | Carlos Alberto Zambrano Braydi |
| P4 — Video | Camilo José Mora Rodríguez |

> **Entorno:** PostgreSQL 17 sobre Supabase · MongoDB Atlas (M0) · Mediciones reales con
> `EXPLAIN (ANALYZE, BUFFERS)` y `.explain("executionStats")`.

> **🔧 MARCADORES PENDIENTES (datos de P1/P2 antes de entregar):**
> - `⟦P1⟧` capturas EXPLAIN de los índices avanzados híbridos (JSONB/GIN/pg_trgm).
> - `⟦P2⟧` capturas `.explain()` de MongoDB (las cifras ya están; faltan los screenshots).
> - `⟦a⟧` confirmar cifras finales del resumen ejecutivo tras ejecutar el script híbrido.

---

## a. Resumen ejecutivo

Ecommify implementa una **arquitectura políglota** que combina PostgreSQL (núcleo
transaccional) y MongoDB (módulo analítico y de catálogo), optimizada para consultas de
reportes de ventas, análisis de clientes y operación comercial sobre datos reales del
dataset Olist (100.000 órdenes).

**Principales optimizaciones aplicadas:**
- PostgreSQL: índices especializados (B-tree, parcial, BRIN, covering con INCLUDE),
  particionamiento declarativo por RANGE y reescritura de consultas críticas (CTEs).
- Enfoque **híbrido** de tipos avanzados: `JSONB` (specifications), arrays (`tags`) y
  `pg_trgm`/GIN sobre los datos reales (ver sección b).
- MongoDB: modelado con patrones de documento (Attribute/Embedding, Computed,
  Referenced), índices compuestos siguiendo la regla **ESR**, índice parcial e índice de
  texto, y un aggregation pipeline de 7 stages.

**Resultados cuantitativos destacados:**
- Índices en consultas filtradas: hasta **97,7 %** de mejora (Seq Scan → Index Scan).
- Particionamiento (partition pruning): **79,6 %** (15,07 → 3,07 ms).
- Reescritura de la query de ventas por categoría: **50,8 %** (15,68 → 7,72 ms).
- MongoDB, pipeline analítico optimizado: **84,9 %** (284 → 43 ms; docsExamined 1.000 → 198).

---

## b. Implementación PostgreSQL

### b.1 Scripts DDL ejecutados en Supabase

Esquema relacional con la estructura real de Olist (8 tablas: `geolocations`,
`categories`, `customers`, `sellers`, `products`, `orders`, `order_items`,
`order_payments`) con PK, FK y constraints. DDL completo en `postgresql/schema/`.

**Volumen real cargado:**

| Tabla | Registros | Tamaño |
|---|---:|---:|
| orders | 100.000 | 13 MB |
| order_items | 15.000 | 1.760 kB |
| order_payments | 5.000 | 528 kB |
| customers | 1.000 | 144 kB |
| products | 500 | 104 kB |
| categories / sellers / geolocations | 20 / 100 / 100 | — |

Estado de `order_status`: delivered 69.516 · shipped 29.424 · **processing 1.060 (1,06 %)**.

### b.2 Tipos nativos avanzados y extensiones (enfoque híbrido)

El dataset Olist tiene estructura plana (sin campos semiestructurados). Para cubrir el
criterio de *tipos avanzados y extensiones* sin inventar datos, se añadieron **sobre los
datos reales** (script `postgresql/schema/13_tipos_avanzados_hibrido.sql`):

| Elemento | Implementación | Justificación |
|---|---|---|
| `products.specifications` | `JSONB` (peso/dimensiones/fotos reales) | Atributos que varían por categoría; mismo criterio que el Attribute Pattern de Mongo |
| `products.tags` | `TEXT[]` | Etiquetado múltiple (categoría + atributos) |
| Extensión `pg_trgm` | Índice GIN sobre `categories.category_name` | Búsqueda difusa/`ILIKE` por nombre de categoría |

### b.3 Estrategia de indexación justificada

| Índice | Tipo | Tamaño | Patrón que optimiza |
|---|---|---:|---|
| `idx_orders_customer_id` | B-Tree | 704 kB | JOIN/filtro por customer_id |
| `idx_order_items_product_id` | B-Tree | 128 kB | JOIN/filtro por product_id |
| `idx_order_items_seller_id` | B-Tree | 120 kB | JOIN/filtro por seller_id |
| `idx_order_items_seller_incl_price` | B-Tree + INCLUDE (covering) | 480 kB | Agregación de price (Index Only Scan) |
| `idx_orders_processing` | **Parcial** | 40 kB | Pedidos 'processing' (1 % de la tabla) |
| `idx_orders_purchase_brin` | **BRIN** | 24 kB | Rangos de fecha (escalabilidad) |
| `idx_products_specifications_gin` | **GIN (JSONB)** | ⟦P1⟧ | Filtros dentro de specifications |
| `idx_products_tags_gin` | **GIN (array)** | ⟦P1⟧ | Pertenencia de etiquetas |
| `idx_categories_name_trgm` | **GIN + pg_trgm** | ⟦P1⟧ | Búsqueda difusa de texto |

**Decisión técnica:** el índice parcial es el mejor ratio (40 kB cubren el caso
operativo crítico sin indexar el 99 % restante). El BRIN ocupa 24 kB y se justifica como
decisión de escalabilidad. Los GIN cubren los tipos avanzados del enfoque híbrido.

### b.4 Particionamiento aplicado

- **Tabla:** `orders` (100.000 filas, >100k ✅) · **Columna:** `order_purchase_timestamp`
- **Tipo:** RANGE · **Granularidad:** mensual (14 particiones + DEFAULT) · índices locales
- **Mantenimiento:** retención 24 meses, archivado vía `DETACH PARTITION`, creación
  automática del mes siguiente con `pg_cron`.

### b.5 Queries críticas optimizadas

Tres técnicas, cada una justificada (código completo en el PDF de implementación y en
`postgresql/queries/`):
1. **Pre-agregación en CTE (Q1):** agregar `order_items` por producto antes de unir reduce
   las filas que entran al JOIN (15.000 → ~500).
2. **Corrección de fan-out con CTEs (Q5):** pre-agregar ítems y pagos por separado evita el
   producto cartesiano; mejora rendimiento **y** correctitud.
3. **Eliminación de JOIN redundante (Q3):** se quita el JOIN a `customers` porque
   `customer_id` ya está en `orders`.

> Evidencia visual: capturas `EXPLAIN (ANALYZE, BUFFERS)` en el documento PDF (Figuras 1–6).

---

## c. Implementación MongoDB

### c.1 Colecciones y esquemas de documentos

| Colección | Docs | Patrón | Decisión de modelado |
|---|---:|---|---|
| `products` | 1.000 | Attribute/Embedding + **Computed** | Especificaciones embebidas (varían por categoría); métricas precalculadas (`total_units_sold`, `average_rating`) para evitar aggregations en cada lectura |
| `order_reviews` | 500 | **Referenced** | Volumen de escritura alto e independiente del catálogo; embeber generaría documentos de crecimiento ilimitado |

> ⟦P2⟧ **Pendiente:** agregar JSON Schema de validación (≥2 colecciones) y, para más
> patrones, colección `orders` (Extended Reference) y/o `analytics_events` (Bucket).

### c.2 Índices implementados (regla ESR)

| Índice | Tipo | Colección | Optimiza |
|---|---|---|---|
| `idx_products_category_price_status` | Compuesto ESR `{category.name:1, price.amount:-1, status:1}` | products | Catálogo por categoría ordenado por precio |
| `idx_products_active` | Parcial (`status="ACTIVE"`) | products | Reduce el índice ~80 % (excluye inactivos) |
| `idx_products_text_name` | Text | products | Búsqueda full-text por nombre |
| `idx_reviews_product_score` | Compuesto `{product_id:1, review_score:-1}` | order_reviews | Reseñas de un producto por calificación |

**Validación con `.explain("executionStats")`:**

| Índice | docsExamined antes | docsExamined después | Tiempo antes | Tiempo después |
|---|---:|---:|---:|---:|
| `idx_products_category_price_status` | 1.000 | 198 | 18,4 ms | 1,8 ms |
| `idx_products_active` | 1.000 | 802 | 12,7 ms | 1,2 ms |
| `idx_reviews_product_score` | 500 | 43 | 8,9 ms | 0,7 ms |

La mayor mejora es el compuesto ESR: docsExamined 1.000 → 198 (**−80,2 %**).
> ⟦P2⟧ Adjuntar capturas de `.explain()` antes/después (las cifras ya están; faltan screenshots).

### c.3 Aggregation pipeline optimizado (7 stages)

Pipeline de análisis de rendimiento del catálogo: `$match` (índice parcial) → `$lookup`
(reviews) → `$unwind` → `$group` (métricas por categoría) → `$addFields` (etiqueta de
rendimiento) → `$sort` → `$project`, con `allowDiskUse: true`. Código en
`mongodb/schema/aggregation_pipelines.js`.

**Optimización medida:**

| Escenario | executionTimeMillis | docsExamined | Observación |
|---|---:|---:|---|
| Sin `$match` inicial ni índices | 284 ms | 1.000 | Recorre toda la colección antes del lookup |
| Con índice parcial pero `$match` al final | 187 ms | 1.000 | El índice existe pero no se aprovecha |
| Con `$match` al inicio e índices activos | 43 ms | 198 | **−84,9 %** |

### c.4 Diseño teórico de sharding y replica sets

**Sharding** (colección candidata: `analytics_events`/`orders`, la de mayor volumen y
crecimiento). Shard key recomendada: **`{ customer_id: 1, order_purchase_timestamp: 1 }`**
(range sobre clave compuesta).

- `customer_id` aporta alta cardinalidad y dispersa las escrituras (evita el *hot shard*
  de una clave temporal monotónica).
- `order_purchase_timestamp` conserva la localidad de rango → las analíticas por
  cliente+periodo son *targeted*, no *scatter-gather*.
- **Hashed vs range:** se descarta hashed porque convertiría todo reporte temporal en
  scatter-gather; el primer campo ya da distribución uniforme.

Distribución simulada (3 shards por rangos de `customer_id`): ~33 % / 33 % / 34 %.

**Replica sets:** topología **PSS (Primary + 2 Secondary) multi-AZ** por shard. 3 miembros
con datos garantizan quórum 2/3 para `w:majority` y tolerancia a la caída de 1 nodo
(se descarta Arbiter para no debilitar la durabilidad).

**Read/Write Concern diferenciados:**

| Operación | Write Concern | Read Concern | Read Preference |
|---|---|---|---|
| Transaccional (orden/pago/reseña) | `majority`, `j:true` | `majority` | `primary` |
| Lectura analítica (reportes) | — | `local` | `secondaryPreferred` |
| Baja criticidad (logs/telemetría) | `w:1` | `local` | `primaryPreferred` |
| Read-your-writes | `majority` | `majority` | `primary` / sesión causal |

> Diagrama: `Ejercicio3/Diagrama_ReplicaSet_3nodos_multiAZ.drawio`. Detalle ampliado en
> `docs/seccion_c_sharding_replica_sets.md`.

---

## d. Evidencias cuantitativas de mejoras de rendimiento

### d.1 PostgreSQL — tablas y gráficas

**Líneas base (antes de optimizar, solo índices de PK):**

| Consulta | Exec (ms) | Tablas con Seq Scan |
|---|---:|---|
| Q1 Ventas por categoría | 87,89 | order_items, products, categories |
| Q2 Vendedores por ingresos | 10,87 | order_items, sellers |
| Q3 Clientes mayores compras | 52,88 | orders, order_payments, customers |
| Q4 Ventas por estado | 62,64 | order_items, customers, geolocations, products, categories |
| Q5 Reporte de órdenes | 55,79 | order_items, orders, order_payments, customers |

**Impacto de índices (consultas filtradas)** — `evidencias/01_indices_consultas_filtradas.png`:

| Consulta | Antes | Después | Plan | Mejora |
|---|---:|---:|---|---:|
| F1 `customer_id` | 10,15 ms | 0,23 ms | Seq → Bitmap Heap Scan | **97,7 %** |
| F2 `seller_id` | 1,64 ms | 0,24 ms | Seq → Bitmap Heap Scan | **85,6 %** |
| F3 `status='processing'` | 9,91 ms | 0,28 ms | Seq → Index Only Scan | **97,1 %** |
| F4 rango 1 mes (BRIN) | 11,12 ms | 10,65 ms | Seq → Seq | 4,3 % |

**Optimización de queries críticas** — `evidencias/02_optimizacion_queries_criticas.png`:

| Técnica | Consulta | Antes | Después | Mejora |
|---|---|---:|---:|---:|
| Pre-agregación en CTE | Q1 | 15,68 ms | 7,72 ms | **50,8 %** |
| Corrección de fan-out con CTEs | Q5 | 60,69 ms | 48,48 ms | 20,1 % |
| Eliminación de JOIN redundante | Q3 | 29,97 ms | 28,25 ms | 5,7 % |

**Particionamiento** — `evidencias/03_particionamiento_pruning.png`:

| Escenario | Exec (ms) | Relaciones escaneadas |
|---|---:|---|
| Sin particionamiento | 15,07 | orders (tabla completa) |
| Con particionamiento | 3,07 | orders_part_202512 (1 partición) |

→ **79,6 %** por partition pruning (escanea 1 de 15 particiones).

### d.2 MongoDB — métricas de executionTimeMillis y efficiency ratios

- Índice compuesto ESR: docsExamined 1.000 → 198 (**efficiency ratio 5,05×**), 18,4 → 1,8 ms.
- Pipeline analítico: 284 → 43 ms (**−84,9 %**), docsExamined 1.000 → 198.
- Índice parcial: reduce el tamaño del índice ~80 % indexando solo productos activos.

> ⟦P2⟧ Pendiente: gráfica de `executionTimeMillis`/`docsExamined` (análoga a las de
> PostgreSQL) una vez se adjunten las capturas de `.explain()`.

### d.3 Interpretación y análisis de impacto

- Las mayores mejoras provienen de **decisiones de diseño** (índice parcial, pre-agregación,
  partition pruning, regla ESR), no de fuerza bruta.
- El BRIN mejora poco a 100k filas cacheadas pero se justifica por su costo ínfimo (24 kB)
  y su escalabilidad cuando el histórico crezca.
- En MongoDB, ubicar `$match` al inicio y dejar `$project` al final es lo que permite al
  planificador aprovechar el índice parcial desde el primer stage.

---

## e. Sincronización entre sistemas y estrategia de consistencia

**Reparto de responsabilidades:** PostgreSQL es la **fuente de verdad transaccional (CP)**;
MongoDB es un **read model analítico (AP)** derivado y enriquecido.

**Flujo de datos:** unidireccional para datos maestros. Un **job ETL programado** (base:
`Ejercicio3/carga_validacion_mongodb_etapa1.py`) lee de PostgreSQL las filas modificadas y
hace **upsert por `_id`** en MongoDB (idempotente). Las reseñas y eventos nacen en MongoDB.

**Consistencia eventual — doble ventana de inconsistencia:**

```
Lag percibido = Ventana 1 (latencia del job ETL: segundos–minutos)
              + Ventana 2 (replication lag del replica set: ~ms–2 s)
```

**Mitigación según criticidad:**

| Caso de uso | Estrategia |
|---|---|
| Operación crítica (ver último estado) | Leer de PostgreSQL o `readPreference:primary` + `readConcern:majority` |
| Read-your-writes | Sesión con **causal consistency** |
| Evitar leer datos que podrían perderse en rollback | `readConcern:majority` + `writeConcern:majority` |
| Lectura tolerante (catálogo, reportes) | `secondaryPreferred`/`nearest`, `readConcern:local` |

> Diagrama: `Ejercicio3/Diagrama_Consistencia_Eventual_ventana_lag.drawio`. Detalle en
> `docs/seccion_e_sincronizacion_consistencia.md`.

---

## f. Lecciones aprendidas

### Obstáculos y soluciones
1. **Datos reales sin atributos semiestructurados** → enfoque híbrido (JSONB/arrays/pg_trgm
   sobre datos reales, documentado).
2. **Cifras desactualizadas** (5.000 vs. 100.000 órdenes) → reejecución de mediciones y
   corrección; el particionamiento quedó justificado (>100k).
3. **Seq Scan óptimo en agregaciones de tabla completa** → se demostró el impacto de
   índices con consultas **filtradas** (85–98 %).
4. **Inconsistencia de datos entre tablas** (solo ~5.000 órdenes con pagos) → documentada y
   acotada en Q3/Q5.
5. **Datos derivados para MongoDB** (Olist no trae name/price/specifications) → derivación
   documentada para no presentar datos inventados como reales.

### Limitaciones del free tier y workarounds
| Limitación | Workaround |
|---|---|
| Atlas M0 sin sharding real | Sharding documentado de forma teórica (shard key, hashed vs range, simulación) |
| M0 sin control fino del replica set | Topología PSS multi-AZ como diseño objetivo |
| Supabase: DDL pesado / `pg_cron` limitado | Session Pooler (5432) para DDL; mantenimiento de particiones documentado |
| Pipelines que exceden memoria | `allowDiskUse: true` |

### Conclusiones
La arquitectura políglota demostró su valor: PostgreSQL para integridad transaccional y
MongoDB para analítica/catálogo flexible. Trabajar con datos reales obligó a decisiones
honestas de modelado, más valiosas que un esquema ideal con datos ficticios.

---

## 2. Repositorio GitHub

Estructura organizada (`postgresql/`, `mongodb/`, `notebooks/`, `docs/`, `evidencias/`),
README con instrucciones de setup para Supabase y MongoDB Atlas, scripts idempotentes y
reproducibles. Ver `README.md` en la raíz del repositorio.

## 3. Video de demostración (P4)
Guion sugerido (5–10 min): (a) conexión a Supabase y Atlas; (b) navegación por
tablas/colecciones; (c) ejecución de queries optimizadas mostrando mejoras; (d) explicación
de 2–3 decisiones técnicas clave: **índice parcial 'processing'**, **partition pruning** y
**regla ESR en MongoDB**.
