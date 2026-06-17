# Evidencias de mejoras de rendimiento

Carpeta de evidencias cuantitativas (sección d del documento técnico). Las **capturas
de `EXPLAIN (ANALYZE, BUFFERS)`** están embebidas en el documento técnico (PDF); aquí
se consolidan las **gráficas comparativas** generadas a partir de esas mediciones reales.

> Todos los datos provienen de ejecuciones reales contra la base en Supabase
> (PostgreSQL 17, `orders` = 100.000 filas). No hay cifras inventadas.

## Gráficas PostgreSQL

| Figura | Archivo | Qué muestra | Fuente de datos |
|---|---|---|---|
| 1 | `01_indices_consultas_filtradas.png` | Impacto de 4 tipos de índice (B-tree, parcial, BRIN) en consultas filtradas. Mejoras de 85–98% por el cambio Seq Scan → Index/Bitmap Scan. | `Tarea4/scripts/RESULTADOS_Parte2.md`, sección 2 |
| 2 | `02_optimizacion_queries_criticas.png` | Reescritura SQL de 3 queries críticas (pre-agregación en CTE, corrección de fan-out, eliminación de JOIN redundante). | PDF *Implementación técnica*, sección 1.4 |
| 3 | `03_particionamiento_pruning.png` | Particionamiento RANGE con partition pruning: 15,07 → 3,07 ms (79,6%) al leer 1 de 15 particiones. | `RESULTADOS_Parte2.md`, sección 3 |

### Lectura de resultados (interpretación)
- Los índices **B-tree y parcial** dan las mayores mejoras (97,7% en `customer_id`,
  97,1% en el índice parcial de `processing`) porque convierten un Seq Scan completo en
  un acceso directo por índice.
- El índice **BRIN** mejora poco a 100k filas cacheadas (4,2%): se justifica como
  decisión de **escalabilidad futura**, no de impacto inmediato (ocupa solo 24 kB).
- La **pre-agregación en CTE** (Q1) reduce a la mitad el tiempo al disminuir las filas
  que entran al JOIN; la **corrección de fan-out** (Q5) además corrige un doble conteo
  (mejora de correctitud, no solo de velocidad).
- El **particionamiento** es la técnica de mayor impacto estructural (79,6%) y la que
  mejor escala con el crecimiento del histórico de órdenes.

## Gráficas MongoDB

| Figura | Archivo | Qué muestra | Fuente de datos |
|---|---|---|---|
| 4 | `04_mongodb_indices.png` | Impacto de 3 índices (compuesto ESR, parcial, reseñas) en `executionTimeMillis`. | PDF V2, sección 2.2 (`.explain("executionStats")`) |
| 5 | `05_mongodb_pipeline.png` | Aggregation pipeline (7 stages): 284 → 187 → 43 ms (−84,9 %) según ubicación del `$match`. | PDF V2, sección 2.3 |

## Capturas EXPLAIN reales (PostgreSQL)
La subcarpeta `explain_postgresql/` contiene las capturas de `EXPLAIN (ANALYZE, BUFFERS)`
extraídas del documento técnico: partition pruning y las queries Q1/Q5/Q3 antes y después
de optimizar. Están embebidas en `docs/Documento_Tecnico_Ecommify_E01.docx`.

## Cómo regenerar las gráficas
```bash
python -m venv .venv && ./.venv/bin/pip install matplotlib
./.venv/bin/python evidencias/gen_charts.py   # script en esta carpeta
```
