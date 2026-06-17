-- =============================================================================
-- 13_tipos_avanzados_hibrido.sql
-- -----------------------------------------------------------------------------
-- ESTADO: PROPUESTA DE EVOLUCIÓN FUTURA — NO ejecutada en el Entregable 2.
-- En esta entrega el esquema PostgreSQL se mantiene relacional puro (sin JSONB);
-- la flexibilidad documental se resuelve en MongoDB (Attribute/Embedding). Este
-- script se conserva como camino de evolución si más adelante se decide llevar
-- atributos semiestructurados también a PostgreSQL.
-- -----------------------------------------------------------------------------
-- Enfoque HÍBRIDO: añade tipos nativos avanzados y extensiones SOBRE el esquema
-- real ya cargado en Supabase (estructura Olist), sin rehacer la implementación
-- ni las evidencias EXPLAIN existentes (ver Tarea4/scripts/RESULTADOS_Parte2.md).
--
-- Objetivo: cubrir el criterio de rúbrica "tipos avanzados (JSON/JSONB, arrays)
-- y extensiones (pg_trgm)" partiendo de datos REALES, documentando cada derivación.
--
-- Ejecutar en Supabase con el Session Pooler (puerto 5432) por ser DDL.
-- =============================================================================

-- 1) EXTENSIONES -------------------------------------------------------------
-- pg_trgm habilita índices GIN para búsqueda difusa / por similitud de texto.
CREATE EXTENSION IF NOT EXISTS pg_trgm;


-- 2) JSONB: atributos variables por categoría --------------------------------
-- Decisión de diseño: el dataset Olist trae las dimensiones físicas como columnas
-- numéricas planas. Se consolidan en una columna JSONB 'specifications' porque son
-- atributos que varían por tipo de producto y siempre se consultan junto al producto
-- (mismo criterio de "Embedding/Attribute Pattern" usado en MongoDB).
ALTER TABLE products
    ADD COLUMN IF NOT EXISTS specifications JSONB;

-- Backfill desde las columnas reales (no se inventan datos: se reorganizan).
UPDATE products
SET specifications = jsonb_strip_nulls(
    jsonb_build_object(
        'weight_kg',   ROUND(product_weight_g / 1000.0, 3),
        'length_cm',   product_length_cm,
        'height_cm',   product_height_cm,
        'width_cm',    product_width_cm,
        'photos_qty',  product_photos_qty
    )
)
WHERE specifications IS NULL;


-- 3) ARRAYS: etiquetas/categorización múltiple -------------------------------
-- 'tags' permite asociar varias etiquetas a un producto (categoría + atributos).
-- Se inicializa con el nombre de categoría real; el negocio puede enriquecerlo luego.
ALTER TABLE products
    ADD COLUMN IF NOT EXISTS tags TEXT[];

UPDATE products p
SET tags = ARRAY[c.category_name]
FROM categories c
WHERE p.category_id = c.category_id
  AND p.tags IS NULL;


-- 4) ÍNDICES ESPECIALIZADOS --------------------------------------------------

-- 4.1 GIN sobre JSONB: permite consultar/filtrar por claves dentro de specifications.
--     Operador jsonb_path_ops = índice más compacto, optimizado para contención (@>).
CREATE INDEX IF NOT EXISTS idx_products_specifications_gin
    ON products USING GIN (specifications jsonb_path_ops);

-- 4.2 GIN sobre array de tags: filtrado por pertenencia (tags @> ARRAY['...']).
CREATE INDEX IF NOT EXISTS idx_products_tags_gin
    ON products USING GIN (tags);

-- 4.3 GIN + pg_trgm sobre texto real (nombre de categoría): búsqueda difusa/ILIKE.
CREATE INDEX IF NOT EXISTS idx_categories_name_trgm
    ON categories USING GIN (category_name gin_trgm_ops);


-- 5) VERIFICACIÓN ------------------------------------------------------------
-- Tipos y tamaños de los nuevos índices:
--   SELECT indexname, pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
--   FROM pg_indexes
--   WHERE indexname IN ('idx_products_specifications_gin',
--                       'idx_products_tags_gin','idx_categories_name_trgm');

-- =============================================================================
-- NOTA PARA P1 / EQUIPO: tras ejecutar este script, correr las queries de
-- demostración en postgresql/queries/consulta_jsonb_gin.sql con
-- EXPLAIN (ANALYZE, BUFFERS) y pegar los planes en la sección d del documento.
-- =============================================================================
