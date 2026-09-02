# Generador de diapositivas — CKA Hands-On Training

Genera las presentaciones `CLASE-0N/01-CLASE-0N-CKA.pptx` a partir de contenido
estructurado, aplicando un sistema de diseño único y coherente para todas las
clases.

## Por qué

Los `.pptx` originales se construyeron shape a shape sin fuente reproducible y
con estilo mezclado (claro/oscuro, serif Cambria, acentos mostaza). Este
generador los reconstruye con:

- **Tema oscuro "Kubernetes blue"**: fondo `#0B1220`, acento primario
  `#326CE5`, y colores semánticos (`ok` verde, `warn` oro, `danger` rojo) para
  tips y laboratorios *challenge*.
- Tipografía **Segoe UI** (títulos *Light*, cuerpo regular) y **Consolas** para
  código.
- Componentes reutilizables: portada, divisor de sección, lista numerada /
  checklist, agenda, concepto + código, comparativa a 2–3 columnas, bloques de
  código, tabla, tarjetas, proceso, cadena/diagrama, ficha de laboratorio y
  cierre.

El **texto es el mismo** del deck original; solo cambia la presentación.

## Uso

```bash
cd generador-diapositivas
pip install python-pptx
python build.py            # todas las clases con contenido en contenido/
python build.py 1          # solo la Clase 1
python build.py 2 3        # varias
```

Cada ejecución **sobrescribe** `CLASE-0N/01-CLASE-0N-CKA.pptx`.
Los `.pptx` originales están guardados en `_originales/*.bak`.

## Estructura

| Archivo | Función |
|---|---|
| `design.py` | Paleta, tipografía, rejilla (EMU) y primitivas de dibujo. |
| `icons.py` | Capa de iconos: usa los PNG oficiales de Kubernetes (`assets/k8s/`) y, si no hay recurso equivalente, dibuja un glifo vectorial. |
| `builder.py` | Un renderizador por arquetipo + ensamblado del `.pptx`. |
| `contenido/claseNN.py` | Contenido de cada clase como lista de diapositivas (`DECK`). |
| `build.py` | Punto de entrada CLI. |
| `assets/k8s/` | Iconos oficiales de Kubernetes (Apache-2.0 / CC-BY-4.0). Ver `NOTICE.md`. |
| `_originales/` | Copia de seguridad de los `.pptx` previos. |

## Iconos

Los divisores de sección, las tarjetas y los diagramas usan los **iconos oficiales
de Kubernetes** (`kubernetes/community/icons`, PNG a color). Para conceptos que no
son un recurso de Kubernetes (agenda, tip, aviso, troubleshooting…) se dibuja un
icono vectorial. La atribución de la licencia está en `assets/k8s/NOTICE.md`.

Para actualizar o ampliar el juego de iconos:

```bash
BASE=https://raw.githubusercontent.com/kubernetes/community/main/icons/png
curl -sSL -o assets/k8s/<nombre>.png "$BASE/resources/unlabeled/<recurso>-256.png"
```

y añade la entrada correspondiente en `icons.py` (`_PNG` y `_KEYMAP`).

## Añadir o editar una clase

Edita `contenido/claseNN.py`. Cada diapositiva es un dict con clave `t`
(arquetipo) — ver `contenido/clase01.py` como referencia de todos los tipos y
sus campos.

## Vista previa a PNG (Windows, requiere PowerPoint)

```bash
powershell -ExecutionPolicy Bypass -File render_png.ps1 \
  -Pptx "..\CLASE-01\01-CLASE-01-CKA.pptx" -OutDir .\_preview
```
