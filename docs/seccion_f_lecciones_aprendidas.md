# Sección f — Lecciones aprendidas

## 1. Obstáculos encontrados y soluciones aplicadas

| # | Obstáculo | Solución aplicada |
|---|---|---|
| 1 | **Datos reales sin atributos semiestructurados.** El dataset Olist trae una estructura plana (longitudes y dimensiones numéricas), sin campos JSON ni tags, lo que dificultaba demostrar tipos avanzados de PostgreSQL exigidos por la rúbrica. | Enfoque **híbrido**: se conservó el esquema real cargado en Supabase y se añadieron `specifications JSONB` (a partir de las dimensiones reales), `tags TEXT[]` (derivados de categoría) y `pg_trgm` sobre nombres de categoría, documentando cada derivación. Ver `postgresql/schema/13_tipos_avanzados_hibrido.sql`. |
| 2 | **Cifras desactualizadas en el documento de la Etapa 1.** Se reportaban ~5.000 órdenes de una muestra antigua; la base real tiene **100.000**. | Se reejecutaron las mediciones EXPLAIN contra la base real (`Tarea4/scripts/RESULTADOS_Parte2.md`) y se corrigieron las cifras. El particionamiento quedó así **justificado** (>100k filas). |
| 3 | **El Seq Scan era óptimo en agregaciones de tabla completa**, lo que hacía que los índices no mostraran mejora en las queries de reporte. | Se demostró el impacto de los índices con **consultas filtradas** (Seq Scan → Index/Bitmap Scan), que es donde aplica el cambio que pide la rúbrica (mejoras del 85–98 %). |
| 4 | **Inconsistencia de datos entre tablas.** Solo ~5.000 órdenes tienen pagos y ~15.000 ítems, frente a 100.000 órdenes. | Se documentó la limitación y se acotaron las queries Q3/Q5 al subconjunto con datos, dejando constancia para no malinterpretar los resultados. |
| 5 | **Datos derivados para MongoDB.** Olist no trae `name`, `price` ni `specifications` de producto. | Se derivaron de forma **documentada** (precio = promedio en `order_items`, rating = promedio de reviews vía join) y se declararon como decisión de diseño, evitando presentar datos inventados como reales. |
| 6 | **Dos esquemas divergentes** (diseño lógico de la U2 con tipos avanzados vs. implementación real Olist). | Se reconcilió con el enfoque híbrido y se documentó el porqué de la divergencia, alineando repo y evidencias. |

## 2. Limitaciones del free tier y workarounds

| Limitación | Plataforma | Workaround aplicado |
|---|---|---|
| **Sin sharding real** (clusters M0 no soportan sharded clusters) | MongoDB Atlas M0 | Sharding documentado de forma **teórica**: shard key justificada, comparación hashed vs. range y simulación de distribución (sección c). |
| **Replica set no configurable manualmente** (M0 ya es un RS gestionado de 3 nodos, sin control fino) | MongoDB Atlas M0 | Topología PSS multi-AZ documentada como diseño objetivo; se aprovecha que M0 ya provee 3 nodos para validar `readPreference`/`writeConcern`. |
| **`pg_cron` y extensiones limitadas / DDL pesado** | Supabase free | El mantenimiento de particiones (`pg_cron`, `DETACH PARTITION`) se documentó como estrategia; para DDL pesado se usó el **Session Pooler (5432)** en vez del Transaction Pooler (6543). |
| **Límites de almacenamiento y conexiones** | Ambas | Conjunto de datos acotado (products ~1.000, reviews ~500 en Mongo; 100k orders en PG) suficiente para evidenciar las optimizaciones sin agotar el tier. |
| **`allowDiskUse` necesario** en pipelines que exceden 100 MB de memoria | MongoDB Atlas | Se activó `allowDiskUse: true` en el aggregation pipeline analítico. |

## 3. Conclusiones clave

- La **arquitectura políglota** demostró su valor: PostgreSQL para integridad
  transaccional (índices especializados + particionamiento) y MongoDB para analítica y
  catálogo flexible (patrones de documento + aggregation pipeline).
- Las mayores mejoras de rendimiento provinieron de **decisiones de diseño**, no de
  fuerza bruta: pre-agregación en CTEs, índices parciales/covering, partition pruning
  y la regla ESR en MongoDB.
- Trabajar con **datos reales** (Olist) obliga a decisiones honestas de modelado y
  documentación, más valiosas que un esquema ideal con datos ficticios.
