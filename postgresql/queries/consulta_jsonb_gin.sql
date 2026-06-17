-- =============================================================================
-- consulta_jsonb_gin.sql
-- Demostraciones de los tipos avanzados del enfoque híbrido (script 13).
-- Ejecutar cada bloque con EXPLAIN (ANALYZE, BUFFERS) para evidenciar el uso
-- de los índices GIN (Bitmap Index Scan) frente al Seq Scan.
-- =============================================================================

-- Q-JSONB-1: productos cuyo peso supera 5 kg (filtro dentro del JSONB).
-- Sin índice -> Seq Scan + filtro; con idx_products_specifications_gin -> Bitmap.
EXPLAIN (ANALYZE, BUFFERS)
SELECT product_id, specifications ->> 'weight_kg' AS weight_kg
FROM products
WHERE (specifications ->> 'weight_kg')::numeric > 5;

-- Q-JSONB-2: contención de clave (¿tiene N fotos declaradas?). Aprovecha @> y GIN.
EXPLAIN (ANALYZE, BUFFERS)
SELECT product_id, specifications
FROM products
WHERE specifications @> '{"photos_qty": 1}';

-- Q-ARRAY-1: productos que contienen una etiqueta específica (GIN sobre tags).
EXPLAIN (ANALYZE, BUFFERS)
SELECT product_id, tags
FROM products
WHERE tags @> ARRAY['bed_bath_table'];   -- ajustar a una categoría real existente

-- Q-TRGM-1: búsqueda difusa por nombre de categoría (pg_trgm + GIN).
-- Tolera errores de tipeo / coincidencias parciales sin recorrer toda la tabla.
EXPLAIN (ANALYZE, BUFFERS)
SELECT category_id, category_name
FROM categories
WHERE category_name ILIKE '%hous%';

-- Plantilla para registrar resultados en la sección d del documento:
-- | Query        | Plan sin índice | Plan con índice    | Exec antes | Exec después | Mejora |
-- | Q-JSONB-1    | Seq Scan        | Bitmap Index Scan  |  __ ms     |  __ ms       |  __ %  |
-- | Q-ARRAY-1    | Seq Scan        | Bitmap Index Scan  |  __ ms     |  __ ms       |  __ %  |
-- | Q-TRGM-1     | Seq Scan        | Bitmap Index Scan  |  __ ms     |  __ ms       |  __ %  |
