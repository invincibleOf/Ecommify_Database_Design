// ============================================================================
// Ecommify · Módulo analítico en MongoDB Atlas
// 02_indexes.js — Índices siguiendo la regla ESR (Equality, Sort, Range)
// ----------------------------------------------------------------------------
// Validación medida con .explain("executionStats") — ver tabla de resultados
// al final de este archivo.
// ============================================================================

// Índice 1 — Compuesto ESR para catálogo
// Equality: category.name · Sort: price.amount · (status como filtro adicional)
db.products.createIndex(
  { "category.name": 1, "price.amount": -1, "status": 1 },
  { name: "idx_products_category_price_status" }
);

// Índice 2 — Parcial, solo productos activos (reduce el índice ~80 %)
db.products.createIndex(
  { "status": 1 },
  {
    partialFilterExpression: { "status": "ACTIVE" },
    name: "idx_products_active"
  }
);

// Índice 3 — Text para búsqueda full-text por nombre
db.products.createIndex(
  { "name": "text" },
  { name: "idx_products_text_name" }
);

// Índice 4 — Compuesto para reseñas de un producto ordenadas por calificación
db.order_reviews.createIndex(
  { "product_id": 1, "review_score": -1 },
  { name: "idx_reviews_product_score" }
);

// ----------------------------------------------------------------------------
// Validación con .explain("executionStats")  (PDF V2, sección 2.2)
// ----------------------------------------------------------------------------
//  Índice                               | docsExam. antes | después | t antes | t después
//  idx_products_category_price_status   |      1.000      |   198   | 18,4 ms |  1,8 ms
//  idx_products_active                  |      1.000      |   802   | 12,7 ms |  1,2 ms
//  idx_reviews_product_score            |        500      |    43   |  8,9 ms |  0,7 ms
//
// El compuesto ESR logra la mayor mejora: docsExamined 1.000 -> 198 (-80,2 %),
// porque el planificador usa categoría + precio para localizar exactamente el
// subconjunto relevante sin recorrer la colección completa.
// ----------------------------------------------------------------------------

// Ejemplo de medición:
// db.products.find({ "category.name": "Computers" })
//            .sort({ "price.amount": -1 })
//            .explain("executionStats");
