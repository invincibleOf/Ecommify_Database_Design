// ============================================================================
// Ecommify · Módulo analítico en MongoDB Atlas
// 03_aggregation_pipelines.js — Pipeline de análisis de rendimiento del catálogo
// ----------------------------------------------------------------------------
// Determina qué categorías tienen mejor relación entre calificación promedio y
// volumen de ventas, cruzando con las reseñas reales (order_reviews).
//
// Decisiones de optimización:
//   - $match en Stage 1: aprovecha el índice parcial idx_products_active desde
//     el primer paso, reduciendo de 1.000 a 802 documentos antes del $lookup.
//   - $project al final: no bloquea el uso de índices en stages anteriores.
//   - allowDiskUse: true: permite pipelines que excedan la memoria del free tier.
// ============================================================================

db.products.aggregate([

  // Stage 1: $match — filtra productos activos aprovechando el índice parcial
  { $match: { "status": "ACTIVE" } },

  // Stage 2: $lookup — join con la colección order_reviews
  {
    $lookup: {
      from: "order_reviews",
      localField: "_id",
      foreignField: "product_id",
      as: "real_reviews"
    }
  },

  // Stage 3: $unwind — descompone el array de reseñas para agregar
  {
    $unwind: {
      path: "$real_reviews",
      preserveNullAndEmptyArrays: true
    }
  },

  // Stage 4: $group — agrupa por categoría con métricas de negocio
  {
    $group: {
      _id: "$category.name",
      total_products:      { $sum: 1 },
      avg_computed_rating: { $avg: "$computed_metrics.average_rating" },
      total_units_sold:    { $sum: "$computed_metrics.total_units_sold" },
      avg_real_score:      { $avg: "$real_reviews.review_score" }
    }
  },

  // Stage 5: $addFields — etiqueta de rendimiento por categoría
  {
    $addFields: {
      performance_label: {
        $cond: {
          if:   { $gte: ["$avg_computed_rating", 4.0] },
          then: "Alto rendimiento",
          else: {
            $cond: {
              if:   { $gte: ["$avg_computed_rating", 3.0] },
              then: "Rendimiento medio",
              else: "Bajo rendimiento"
            }
          }
        }
      }
    }
  },

  // Stage 6: $sort — ordena por volumen de ventas descendente
  { $sort: { "total_units_sold": -1 } },

  // Stage 7: $project — proyección final con solo los campos necesarios
  {
    $project: {
      _id: 0,
      categoria:           "$_id",
      total_products:      1,
      avg_computed_rating: { $round: ["$avg_computed_rating", 2] },
      avg_real_score:      { $round: ["$avg_real_score", 2] },
      total_units_sold:    1,
      performance_label:   1
    }
  }

], { allowDiskUse: true });

// ----------------------------------------------------------------------------
// Evidencia de optimización (PDF V2, sección 2.3)
// ----------------------------------------------------------------------------
//  Escenario                                  | executionTimeMillis | docsExamined
//  Sin $match inicial ni índices              |        284 ms       |    1.000
//  Con índice parcial pero $match al final    |        187 ms       |    1.000
//  Con $match al inicio e índices activos     |         43 ms       |      198
//
//  Mejora total: -84,9 % respecto al escenario sin optimizar.
// ----------------------------------------------------------------------------
