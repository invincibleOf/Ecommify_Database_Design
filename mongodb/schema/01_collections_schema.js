// ============================================================================
// Ecommify · Módulo analítico en MongoDB Atlas
// 01_collections_schema.js — Creación de colecciones con validación JSON Schema
// ----------------------------------------------------------------------------
// Dos colecciones reflejan cómo la aplicación consulta los datos:
//   - products       (1.000 docs): Attribute/Embedding + Computed Pattern
//   - order_reviews  (500 docs)  : Referenced Pattern
// Ejecutar en mongosh contra la base del módulo analítico:
//   use ecommify_catalog
// ============================================================================

// --------------------------------------------------------------------------
// Colección: products
// Decisión de modelado: las "specifications" se embeben porque varían por
// categoría y siempre se consultan junto al producto (Attribute/Embedding).
// Se aplica el Computed Pattern guardando métricas precalculadas
// (total_units_sold, average_rating) para evitar aggregations costosas en
// cada lectura del catálogo.
// --------------------------------------------------------------------------
db.createCollection("products", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "name", "category", "price", "status"],
      properties: {
        _id:  { bsonType: "string", description: "Identificador del producto (PROD-XXXX)" },
        name: { bsonType: "string" },
        category: {
          bsonType: "object",
          required: ["id", "name"],
          properties: {
            id:   { bsonType: "int" },
            name: { bsonType: "string" }
          }
        },
        price: {
          bsonType: "object",
          required: ["amount", "currency"],
          properties: {
            amount:   { bsonType: ["double", "decimal", "int"], minimum: 0 },
            currency: { bsonType: "string", maxLength: 3 }
          }
        },
        seller_id: { bsonType: "string" },
        status: { enum: ["ACTIVE", "INACTIVE"] },
        // Attribute Pattern: claves variables por categoría
        specifications: { bsonType: "object" },
        // Computed Pattern: métricas precalculadas
        computed_metrics: {
          bsonType: "object",
          properties: {
            total_units_sold: { bsonType: "int", minimum: 0 },
            average_rating:   { bsonType: ["double", "int"], minimum: 0, maximum: 5 },
            total_reviews:    { bsonType: "int", minimum: 0 },
            last_updated:     { bsonType: "string" }
          }
        },
        created_at: { bsonType: "string" },
        updated_at: { bsonType: "string" }
      }
    }
  },
  validationLevel: "moderate",
  validationAction: "error"
});

// --------------------------------------------------------------------------
// Colección: order_reviews
// Decisión de modelado: las reseñas se mantienen separadas (Referenced)
// porque su volumen de escritura es alto e independiente del producto.
// Embeberlas dentro de cada producto generaría documentos de crecimiento
// ilimitado que degradarían la lectura del catálogo.
// --------------------------------------------------------------------------
db.createCollection("order_reviews", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "product_id", "review_score"],
      properties: {
        _id:         { bsonType: "string", description: "Identificador de la reseña (REV-XXXX)" },
        product_id:  { bsonType: "string", description: "Referencia a products._id" },
        order_id:    { bsonType: "string" },
        customer_id: { bsonType: "string" },
        review_score: { bsonType: "int", minimum: 1, maximum: 5 },
        review_comment_title:   { bsonType: "string" },
        review_comment_message: { bsonType: "string" },
        review_creation_date:   { bsonType: "string" },
        review_answer_timestamp:{ bsonType: "string" }
      }
    }
  },
  validationLevel: "moderate",
  validationAction: "error"
});

// --------------------------------------------------------------------------
// Documentos de ejemplo (estructura real cargada)
// --------------------------------------------------------------------------
// products:
// {
//   "_id": "PROD-0001",
//   "name": "Producto Computers 1",
//   "category": { "id": 1, "name": "Computers" },
//   "price": { "amount": 1245.50, "currency": "USD" },
//   "seller_id": "SELL-023",
//   "status": "ACTIVE",
//   "specifications": { "processor": "Intel i5", "ram": "16GB", "storage": "512GB SSD" },
//   "computed_metrics": {
//     "total_units_sold": 312, "average_rating": 4.3,
//     "total_reviews": 87, "last_updated": "2026-06-01T00:00:00Z"
//   },
//   "created_at": "2026-01-15T10:00:00Z",
//   "updated_at": "2026-06-01T00:00:00Z"
// }
//
// order_reviews:
// {
//   "_id": "REV-0001",
//   "product_id": "PROD-0234",
//   "order_id": "ORD-45678",
//   "customer_id": "CUST-12345",
//   "review_score": 5,
//   "review_comment_title": "Excelente produto",
//   "review_comment_message": "Produto chegou antes do prazo.",
//   "review_creation_date": "2026-03-10T08:00:00Z",
//   "review_answer_timestamp": "2026-03-10T09:30:00Z"
// }
