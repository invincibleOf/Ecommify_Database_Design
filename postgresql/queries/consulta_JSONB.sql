-- NOTA: esta consulta referenciaba columnas (product_name, dimensions) que NO
-- existen en el esquema real cargado en Supabase. Se corrige para usar la columna
-- JSONB 'specifications' del enfoque híbrido (ver schema/13_tipos_avanzados_hibrido.sql).
-- Para las demostraciones con EXPLAIN ver: queries/consulta_jsonb_gin.sql

SELECT
    product_id,
    specifications ->> 'weight_kg' AS weight_kg
FROM products
WHERE specifications IS NOT NULL;
