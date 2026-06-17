# Sección c (parte teórica) — Diseño de sharding y replica sets

> Módulo analítico de Ecommify · MongoDB Atlas · Diseño teórico (free tier M0 no
> permite sharding real; se documenta la configuración objetivo para producción).

Esta sección complementa la implementación de colecciones, índices y aggregation
pipeline ya entregada. Aquí se justifica **cómo escalaría horizontalmente** el módulo
analítico mediante *sharding* y **cómo se garantiza disponibilidad y durabilidad**
mediante *replica sets*.

---

## 1. Diseño de sharding

### 1.1 Colección candidata a particionar

Se elige la colección más crítica por **volumen y tasa de crecimiento**: la colección
de eventos analíticos / órdenes del módulo (`analytics_events` / `orders`), no el
catálogo `products` (que es pequeño y de lectura intensiva, mejor servido por réplicas).

| Colección | Volumen esperado | Crecimiento | ¿Shard? |
|---|---|---|---|
| `products` | ~1.000 docs | Bajo | No — replicar, no shardear |
| `order_reviews` | ~500–decenas de miles | Medio | Opcional |
| `analytics_events` / `orders` | Millones (histórico de compras Olist: ~100k órdenes y creciendo) | Alto y continuo | **Sí — candidata principal** |

### 1.2 Análisis de la shard key

Una buena shard key debe cumplir tres propiedades: **alta cardinalidad**, **baja
frecuencia** (que ningún valor concentre demasiados documentos) y **monotonía
controlada** (evitar que todas las escrituras nuevas caigan en el mismo chunk).

Candidatas evaluadas:

| Shard key candidata | Cardinalidad | Riesgo | Veredicto |
|---|---|---|---|
| `{ order_purchase_timestamp: 1 }` (range puro) | Alta | **Monotónica** → todas las inserciones nuevas van al último chunk (*hot shard*) y genera *jumbo chunks* | ❌ Anti-patrón |
| `{ customer_id: "hashed" }` | Alta | Distribuye uniforme, pero **rompe las queries por rango de fecha** (scatter-gather en todos los shards) | ⚠️ Parcial |
| `{ customer_id: 1, order_purchase_timestamp: 1 }` (compuesta) | Alta | Equilibra distribución (por cliente) y permite *targeting* de las analíticas por cliente+fecha | ✅ **Recomendada** |

**Decisión final:** shard key compuesta **`{ customer_id: 1, order_purchase_timestamp: 1 }`**.

**Justificación técnica:**
- `customer_id` aporta **alta cardinalidad** (1.000+ clientes reales, decenas de miles
  en producción) y reparte la carga de escritura entre muchos valores → evita el
  *hot shard* que provocaría una clave puramente temporal.
- `order_purchase_timestamp` como segundo campo conserva la **localidad de rango**
  dentro de cada cliente, de modo que las consultas analíticas frecuentes
  ("compras de un cliente en un periodo") son operaciones **targeted** (golpean
  solo el/los shard(s) relevantes) en lugar de *scatter-gather*.
- No es monotónica a nivel global porque el primer campo dispersa las inserciones.

### 1.3 Hashed vs. Range sharding

| Criterio | Range sharding | Hashed sharding |
|---|---|---|
| Distribución de escritura | Desigual si la clave es monotónica | Uniforme garantizada |
| Queries por rango | Eficientes (targeted) | Ineficientes (scatter-gather) |
| Caso Ecommify analítico | Reportes por periodo/cliente lo requieren | Perdería el targeting por fecha |

**Conclusión:** se usa **range sharding sobre la clave compuesta**. El primer campo
(`customer_id`) ya logra una distribución suficientemente uniforme sin sacrificar las
consultas por rango de fecha, que son el patrón analítico dominante de Ecommify.
Hashed se descartó porque convertiría todo reporte temporal en scatter-gather.

### 1.4 Simulación de distribución across shards

Cluster objetivo: **3 shards** (cada uno un replica set). Con la clave
`{ customer_id: 1, order_purchase_timestamp: 1 }` el balanceador reparte los chunks
por rangos de `customer_id`:

| Shard | Rango de chunk (customer_id) | Chunks estimados | % datos aprox. |
|---|---|---|---|
| shard01 | `[CUST-00000 … CUST-03333)` | ~33 | ~33 % |
| shard02 | `[CUST-03333 … CUST-06666)` | ~33 | ~33 % |
| shard03 | `[CUST-06666 … CUST-99999]` | ~34 | ~34 % |

Con *zone sharding* opcional se podrían fijar zonas geográficas (ej. clientes de una
región a un shard cercano) para reducir latencia, aprovechando que Olist incluye
`state`/`zip_code_prefix`.

---

## 2. Diseño de replica sets

Topología objetivo por shard: **Replica Set de 3 miembros (PSS)** distribuidos en
zonas de disponibilidad distintas (multi-AZ). Diagrama de soporte:
`Ejercicio3/Diagrama_ReplicaSet_3nodos_multiAZ.drawio`.

```
            ┌──────────── AZ-a ────────────┐
            │  PRIMARY  (mongod)            │  ← acepta TODAS las escrituras
            │  w:majority, j:true           │
            └───────────────┬───────────────┘
        replicación oplog   │   (asíncrona, lag ~ms a 2s)
        ┌───────────────────┴───────────────────┐
┌─────── AZ-b ───────┐                  ┌─────── AZ-c ───────┐
│ SECONDARY 1        │   heartbeat /    │ SECONDARY 2        │
│ atiende lecturas   │◄── elección ────►│ atiende lecturas   │
└────────────────────┘   (votos)        └────────────────────┘
```

**Por qué PSS (Primary + 2 Secondary) y no PSA (con Arbiter):**
3 miembros **con datos** garantizan quórum 2/3 para `w:majority` y mantienen la
durabilidad aunque caiga 1 nodo. Un Arbiter votaría pero no guardaría datos, lo que
debilita `w:majority` ante una caída. En el free tier M0 esta topología es teórica
(simula 3 nodos), pero es la configuración correcta para producción.

**Consideraciones de latencia:** los Secondary en AZ distintas dan tolerancia a fallos
de zona a costa de mayor *replication lag*. Para lecturas sensibles a latencia se usa
`readPreference: nearest`; para lecturas que toleran desfase, `secondaryPreferred`.

### 2.1 Estrategias de Read/Write Concern diferenciadas

| Tipo de operación | Write Concern | Read Concern | Read Preference | Razón |
|---|---|---|---|---|
| Transaccional (escritura crítica: orden, pago, reseña) | `w: "majority", j: true` | `"majority"` | `primary` | Durabilidad garantizada; evita leer datos que podrían perderse en un rollback |
| Lectura analítica (reportes, dashboards) | — | `"local"` | `secondaryPreferred` | Escala las lecturas masivas en los secondaries; tolera un pequeño desfase |
| Baja criticidad (logs, eventos de telemetría) | `w: 1` | `"local"` | `primaryPreferred` | Máximo throughput de escritura; la pérdida ocasional es aceptable |
| Read-your-writes (usuario ve su propio cambio) | `w: "majority"` | `"majority"` | `primary` o sesión con *causal consistency* | Garantiza leer la propia escritura aunque se use un secondary |

Esta diferenciación permite **pagar el costo de consistencia fuerte solo donde el
negocio lo exige** (pagos/órdenes) y maximizar rendimiento donde no (analítica/logs).
