# -*- coding: utf-8 -*-
"""
Genera las presentaciones .pptx de cada clase a partir del contenido en
`contenido/claseNN.py` y el sistema de diseño en `design.py` / `builder.py`.

Uso:
    python build.py            # genera todas las clases con contenido disponible
    python build.py 1          # genera solo la Clase 1
    python build.py 1 3 5      # genera las clases indicadas

Salida: CLASE-0N/01-CLASE-0N-CKA.pptx  (sobrescribe el archivo existente)
"""
import importlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
sys.path.insert(0, str(ROOT))

import builder  # noqa: E402


def build_clase(n: int) -> Path:
    mod = importlib.import_module(f"contenido.clase{n:02d}")
    deck = mod.DECK
    out_dir = REPO / f"CLASE-{n:02d}"
    out_dir.mkdir(exist_ok=True)
    out = out_dir / f"01-CLASE-{n:02d}-CKA.pptx"
    _, pages = builder.build(deck, str(out))
    print(f"  Clase {n}: {pages} diapositivas  ->  {out.relative_to(REPO)}")
    return out


def main(argv):
    if argv:
        clases = [int(a) for a in argv]
    else:
        clases = sorted(
            int(p.stem[-2:]) for p in (ROOT / "contenido").glob("clase*.py")
        )
    print("Generando presentaciones CKA")
    for n in clases:
        build_clase(n)
    print("Listo.")


if __name__ == "__main__":
    main(sys.argv[1:])
