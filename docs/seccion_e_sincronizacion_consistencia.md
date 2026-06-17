# Sección e — Sincronización entre sistemas y estrategia de consistencia

> Arquitectura políglota Ecommify: PostgreSQL (Supabase) + MongoDB (Atlas).
> Diagrama de soporte: `Ejercicio3/Diagrama_Consistencia_Eventual_ventana_lag.drawio`.

## 1. Reparto de responsabilidades (por qué dos motores)

Ecommify usa cada motor para lo que mejor hace (arquitectura políglota):

| Sistema | Rol | Datos que gobierna |
|---|---|---|
| **PostgreSQL (CP)** | Fuente única de verdad **transaccional** | `orders`, `order_items`, `order_payments`, `customers`, `products`, `sellers`, `geolocations` |
| **MongoDB (AP)** | Módulo **analítico** y de catálogo enriquecido | `products` (con métricas precalculadas), `order_reviews`, eventos analíticos |

PostgreSQL prioriza consistencia e integridad referencial (transacciones de compra y
pago). MongoDB prioriza disponibilidad y rendimiento de lectura para el catálogo y la
analítica, asumiendo **consistencia eventual**.

## 2. Flujo de datos PostgreSQL → MongoDB

El flujo es **unidireccional** para los datos maestros: PostgreSQL es el origen y
MongoDB un *read model* derivado y enriquecido.

```
  PostgreSQL (verdad)                 Job de sincronización                MongoDB (read model)
 ┌──────────────────┐   lee filas con   ┌──────────────────┐   upsert por _id  ┌──────────────────┐
 │ orders, products │──updated_at >  ───►│ ETL programado    │──(idempotente)──►│ products,         │
 │ payments...      │   last_run        │ (pandas + pymongo)│                   │ analytics_events  │
 └──────────────────┘                   └──────────────────┘                   └──────────────────┘
                                                                                       │
                                          MongoDB también recibe escrituras PROPIAS ────┘
                                          (reviews, eventos de navegación)
```

- **Mecanismo:** job programado (el cargador `Ejercicio3/carga_validacion_mongodb_etapa1.py`
  es la base) que lee de PostgreSQL las filas modificadas (`updated_at`/`order_purchase_timestamp`
  posteriores a la última corrida) y hace **upsert por `_id`** en MongoDB.
- **Idempotencia:** al ser upsert por clave natural, reejecutar el job no duplica ni
  corrompe documentos → tolerante a reintentos.
- **Enriquecimiento:** durante el ETL se precalculan métricas (Computed Pattern:
  `total_units_sold`, `average_rating`) para evitar aggregations costosas en lectura.
- **Escrituras nativas de Mongo:** las reseñas y eventos analíticos nacen en MongoDB
  (no provienen de PostgreSQL), por lo que ahí Mongo **sí** es la fuente de verdad.

## 3. Estrategia de consistencia: doble ventana de inconsistencia

El cliente puede leer un dato obsoleto durante una ventana que es la **suma de dos
desfases**:

```
Lag percibido = (Ventana 1: latencia del job ETL Postgres→Mongo)
              + (Ventana 2: replication lag del replica set de Mongo)
```

| Ventana | Origen | Magnitud típica |
|---|---|---|
| **Ventana 1** | Periodicidad del job de sincronización (upsert) | segundos a minutos |
| **Ventana 2** | Replicación oplog asíncrona Primary→Secondary | ~ms a 2 s |

### Estrategias de mitigación (según criticidad de la lectura)

| Caso de uso | Estrategia | Efecto |
|---|---|---|
| Operación crítica que requiere ver el último estado (ej. confirmar pago) | Leer de PostgreSQL directamente, o `readPreference: primary` + `readConcern: "majority"` en Mongo | Elimina ambas ventanas para ese caso |
| Read-your-writes (usuario consulta lo que acaba de escribir en Mongo) | Sesión con **causal consistency** | Garantiza leer la propia escritura aunque toque un secondary |
| Evitar leer datos que podrían perderse en rollback | `readConcern: "majority"` + `writeConcern: "majority"` | Solo lee datos confirmados por la mayoría |
| Lectura tolerante (catálogo, geolocation, reportes) | `readPreference: secondaryPreferred` / `nearest`, `readConcern: "local"` | Acepta el desfase a cambio de escalar lecturas |

**Resumen de la decisión arquitectónica:** se acepta **consistencia eventual** para el
catálogo y la analítica (donde el desfase de segundos no afecta al negocio) y se reserva
**consistencia fuerte** (lecturas desde PostgreSQL o `majority` en Mongo) para las
operaciones transaccionales. Esto materializa el principio de la arquitectura políglota:
consistencia donde importa, disponibilidad y velocidad donde se puede.
