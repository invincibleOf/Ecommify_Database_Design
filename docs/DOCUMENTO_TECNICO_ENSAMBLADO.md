# Documento técnico ensamblado — Entregable 2 (Ecommify · E01)

> **El documento entregable es `Documento_Tecnico_Ecommify_E01.docx`** (en esta misma
> carpeta). Este archivo es solo un índice; el `.docx` es la fuente de verdad y se
> regenera de forma reproducible con `docs/gen_docx.py`.

## Contenido del documento (secciones a–f + repositorio + video)

| Sección | Contenido | Insumos en el repo |
|---|---|---|
| a | Resumen ejecutivo | — |
| b | Implementación PostgreSQL (DDL, indexación, particionamiento, queries críticas) | `postgresql/`, `evidencias/explain_postgresql/`, `Tarea4/scripts/RESULTADOS_Parte2.md` |
| c | Implementación MongoDB (colecciones + JSON Schema, índices ESR, pipeline) y **sharding/replica sets teórico** | `mongodb/schema/`, `docs/seccion_c_sharding_replica_sets.md` |
| d | Evidencias cuantitativas (gráficas + capturas EXPLAIN/.explain) | `evidencias/` |
| e | Sincronización y consistencia eventual | `docs/seccion_e_sincronizacion_consistencia.md` |
| f | Lecciones aprendidas | `docs/seccion_f_lecciones_aprendidas.md` |
| 2 | Repositorio GitHub | este repo |
| 3 | Video de demostración | enlace incluido en el `.docx` |

## Regenerar el `.docx`

```bash
python -m venv .venv
./.venv/bin/pip install python-docx
./.venv/bin/python docs/gen_docx.py     # genera docs/Documento_Tecnico_Ecommify_E01.docx
```

> Las gráficas (`evidencias/*.png`) se regeneran con `evidencias/gen_charts.py`
> (requiere `matplotlib`). Las capturas EXPLAIN reales están en
> `evidencias/explain_postgresql/`.

## Nota de alineación

El documento refleja la **última versión** de la implementación del equipo
(*Implementación técnica completa en PostgreSQL y MongoDB V2*): esquema relacional
real de Olist **sin JSONB** en PostgreSQL (justificado técnicamente) y flexibilidad
documental concentrada en MongoDB.
