import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

OUT = os.path.dirname(os.path.abspath(__file__))
AZUL, ROJO, VERDE = "#1f366a", "#9d0b0e", "#2e8b57"

def barras_antes_despues(nombre, etiquetas, antes, despues, titulo, subt):
    x = np.arange(len(etiquetas)); w = 0.38
    fig, ax = plt.subplots(figsize=(9, 5))
    b1 = ax.bar(x - w/2, antes, w, label="Antes (ms)", color=ROJO)
    b2 = ax.bar(x + w/2, despues, w, label="Después (ms)", color=AZUL)
    ax.set_ylabel("Tiempo de ejecución (ms)")
    ax.set_title(titulo, fontweight="bold")
    ax.set_xticks(x); ax.set_xticklabels(etiquetas, fontsize=9)
    ax.set_ylim(0, max(max(antes),max(despues))*1.22)
    ax.legend(loc="center left")
    for b in list(b1)+list(b2):
        h=b.get_height()
        ax.annotate(f"{h:.2f}", (b.get_x()+b.get_width()/2, h),
                    textcoords="offset points", xytext=(0,3), ha="center", fontsize=8)
    # % mejora encima de cada par
    for i,(a,d) in enumerate(zip(antes,despues)):
        mej = (a-d)/a*100 if a else 0
        ax.annotate(f"-{mej:.1f}%", (x[i], max(a,d)),
                    textcoords="offset points", xytext=(0,16), ha="center",
                    fontsize=9, fontweight="bold", color=VERDE)
    fig.text(0.5, 0.01, subt, ha="center", fontsize=8, style="italic", color="#555")
    fig.tight_layout(rect=[0,0.03,1,1])
    fig.savefig(f"{OUT}/{nombre}.png", dpi=150)
    plt.close(fig)
    print("OK", nombre)

# 1) Índices especializados (consultas filtradas) — RESULTADOS_Parte2.md sec.2
barras_antes_despues(
    "01_indices_consultas_filtradas",
    ["F1 customer_id\n(B-tree)", "F2 seller_id\n(B-tree)",
     "F3 status='processing'\n(parcial)", "F4 rango mes\n(BRIN)"],
    [10.15, 1.64, 9.91, 11.12],
    [0.23, 0.24, 0.28, 10.65],
    "PostgreSQL — Impacto de índices especializados (consultas filtradas)",
    "Fuente: Tarea4/RESULTADOS_Parte2.md · Seq Scan → Index/Bitmap Scan · base real (orders=100.000)")

# 2) Técnicas de optimización de queries críticas — PDF sec.1.4
barras_antes_despues(
    "02_optimizacion_queries_criticas",
    ["Q1 Ventas/categoría\n(pre-agreg. CTE)", "Q5 Reporte órdenes\n(fan-out CTEs)",
     "Q3 Clientes top\n(quitar JOIN)"],
    [15.68, 60.69, 29.97],
    [7.72, 48.48, 28.25],
    "PostgreSQL — Optimización de queries críticas (reescritura SQL)",
    "Fuente: PDF Implementación técnica, sección 1.4 · EXPLAIN (ANALYZE, BUFFERS)")

# 3) Particionamiento (partition pruning) — RESULTADOS_Parte2.md sec.3
barras_antes_despues(
    "03_particionamiento_pruning",
    ["Consulta por rango de 1 mes"],
    [15.07], [3.07],
    "PostgreSQL — Particionamiento por RANGE (partition pruning)",
    "Sin particionar: escanea tabla completa · Con particionar: 1 de 15 particiones · Fuente: RESULTADOS_Parte2.md")
