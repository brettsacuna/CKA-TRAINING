# -*- coding: utf-8 -*-
"""
Genera la web estática de las SESIONES ESPECIALES (9-15) para GitHub Pages.

Salida: ./_site/  (lo publica el workflow .github/workflows/pages.yml con
actions/deploy-pages).

Incluye: índice del track, páginas de sesión, laboratorios (markdown
renderizado) y visor de recursos (YAML, scripts, charts de Helm, CI/CD).
NO incluye las carpetas SOLUCIONES/.

Uso:  python generar.py
"""
import html
import re
import shutil
from pathlib import Path

import markdown
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_lexer_for_filename, guess_lexer
from pygments import highlight as pyg_highlight

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(__file__).resolve().parent / "_site"
SITE = "CKA · Entrenamiento"
BASE_TAGLINE = "Kubernetes práctico para el examen CKA — CKA Training + CKA Extras"

# Dos grupos: (clave, etiqueta, sustantivo, subtítulo, [items]).
# Cada item: (slug, carpeta_origen, n, título, subtítulo, icono).
GRUPOS = [
    ("training", "CKA Training", "Sesión",
     "Siete sesiones sobre una arquitectura de microservicios real —el programa GRATITUD—: "
     "Services, Ingress y TLS, configuración y almacenamiento, observabilidad, seguridad, "
     "CI/CD y un proyecto integrador con evaluación.", [
        ("sesion-9", "CLASE-09", "9", "Networking en Kubernetes (Services)",
         "De una IP que desaparece a un nombre estable para todo el programa.", "graph"),
        ("sesion-10", "CLASE-10", "10", "Control de Tráfico Excluyente (Ingress)",
         "Una sola puerta que decide, por host y por path, quién entra y a dónde.", "cycle"),
        ("sesion-11", "CLASE-11", "11", "Configuración y Seguridad de Aplicaciones",
         "Sacar la configuración de la imagen y dar un disco que sobreviva al Pod.", "cylinder"),
        ("sesion-12", "CLASE-12", "12", "Salud de Aplicaciones y Observabilidad",
         "Sondas que deciden reinicio y tráfico, y las herramientas para ver qué pasa.", "magnifier"),
        ("sesion-13", "CLASE-13", "13", "Seguridad: RBAC, Red y Pods",
         "Quién puede hacer qué, quién puede hablar con quién y qué puede hacer un contenedor.", "cluster"),
        ("sesion-14", "CLASE-14", "14", "Entrega Continua: CI/CD, GitOps y Helm",
         "De un commit a un despliegue reproducible, sin tocar el cluster a mano.", "cycle"),
        ("sesion-15", "CLASE-15", "15", "Proyecto Integrador y Evaluación",
         "Desplegar GRATITUD entero, validar cada capa y demostrarlo en el examen.", "pod"),
     ]),
    ("extras", "CKA Extras", "Clase",
     "El curso base: seis clases de fundamentos y troubleshooting, con laboratorios de "
     "dificultad progresiva.", [
        ("clase-1", "CLASE-01", "1", "Pods, YAML, Services y Scheduling",
         "De ejecutar un comando a decidir dónde corre tu aplicación.", "pod"),
        ("clase-2", "CLASE-02", "2", "Administración del Cluster: Upgrade, ETCD y RBAC",
         "Mantener, recuperar y controlar el acceso al cluster.", "cluster"),
        ("clase-3", "CLASE-03", "3", "Workloads, Storage y StatefulSets",
         "Aplicaciones que no pueden permitirse perder sus datos.", "cylinder"),
        ("clase-4", "CLASE-04", "4", "Lifecycle, ConfigMaps, Secrets y Recursos",
         "Actualizar sin cortar, revertir sin drama, configurar desde fuera de la imagen.", "cycle"),
        ("clase-5", "CLASE-05", "5", "Services, Ingress, CoreDNS y NetworkPolicy",
         "Publicar aplicaciones y decidir quién puede hablar con quién.", "graph"),
        ("clase-6", "CLASE-06", "6", "Troubleshooting e Integración",
         "El 30 % del examen. Cinco laboratorios, incluido el integrador final.", "magnifier"),
     ]),
]

# Lista plana con el sustantivo y la clave de grupo de cada item.
ITEMS = [
    (slug, src, n, title, sub, icon, noun, gk)
    for gk, glabel, noun, gsub, items in GRUPOS
    for (slug, src, n, title, sub, icon) in items
]

LEVELS = {
    "BASICO": ("Básico", "ok"), "INTERMEDIO": ("Intermedio", "blue"),
    "AVANZADO": ("Avanzado", "warn"), "CHALLENGE": ("Challenge", "danger"),
    "INTEGRADOR": ("Integrador", "danger"),
}

ICONS = {
    "pod": '<rect x="4" y="6" width="16" height="12" rx="3"></rect><circle cx="9.5" cy="12" r="1.6"></circle><circle cx="14.5" cy="12" r="1.6"></circle>',
    "cluster": '<rect x="3" y="5" width="18" height="14" rx="2.5"></rect><rect x="6.5" y="9" width="3.4" height="6" rx="1"></rect><rect x="10.3" y="9" width="3.4" height="6" rx="1"></rect><rect x="14.1" y="9" width="3.4" height="6" rx="1"></rect>',
    "cylinder": '<ellipse cx="12" cy="6.5" rx="7" ry="2.8"></ellipse><path d="M5 6.5v11c0 1.55 3.13 2.8 7 2.8s7-1.25 7-2.8v-11"></path><path d="M5 12c0 1.55 3.13 2.8 7 2.8s7-1.25 7-2.8"></path>',
    "cycle": '<path d="M20 12a8 8 0 1 1-2.34-5.66"></path><polyline points="20 4 20 8 16 8"></polyline>',
    "graph": '<circle cx="6" cy="7" r="2.4"></circle><circle cx="18" cy="9" r="2.4"></circle><circle cx="12" cy="18" r="2.4"></circle><path d="M8 8l8 1M7.5 9.2 11 15.6M16.3 10.8 12.8 16"></path>',
    "magnifier": '<circle cx="10.5" cy="10.5" r="6"></circle><line x1="15" y1="15" x2="20" y2="20"></line>',
}
WHEEL = ('<polygon points="12,2 20,7 20,17 12,22 4,17 4,7"></polygon>'
         '<circle cx="12" cy="12" r="3"></circle>'
         '<path d="M12 2v3M20 7l-2.6 1.5M20 17l-2.6-1.5M12 22v-3M4 17l2.6-1.5M4 7l2.6 1.5"></path>')
IC_COPY = '<rect x="9" y="9" width="12" height="12" rx="2"></rect><path d="M5 15V5a2 2 0 0 1 2-2h10"></path>'
IC_DL = '<path d="M12 3v12M7 11l5 5 5-5M5 21h14"></path>'
IC_SLIDES = '<rect x="4" y="3" width="16" height="18" rx="2"></rect><path d="M8 8h8M8 12h8M8 16h5"></path>'

MD_EXT = ["fenced_code", "tables", "sane_lists", "attr_list", "toc",
          "codehilite"]
MD_CFG = {"codehilite": {"css_class": "hl", "guess_lang": False,
                         "pygments_style": "native"}}


def md(text):
    return markdown.markdown(text, extensions=MD_EXT, extension_configs=MD_CFG,
                             output_format="html5")


def preprocess(text):
    """Normaliza sangrías de listas anidadas de 1-3 espacios a 4 (Python-Markdown)."""
    out = []
    for line in text.split("\n"):
        m = re.match(r"^( {1,3})([*+-] |\d+\. )(.*)$", line)
        if m:
            out.append("    " + m.group(2) + m.group(3))
        else:
            out.append(line)
    return "\n".join(out)


def drop_h1(text):
    return re.sub(r"^#\s+.*\n(?:\n)?", "", text, count=1)


def _norm(s):
    return (s.lower().replace("á", "a").replace("é", "e").replace("í", "i")
            .replace("ó", "o").replace("ú", "u"))


def drop_sections(text, names):
    names = {_norm(n) for n in names}
    lines = text.split("\n")
    out, skip = [], False
    for line in lines:
        h = re.match(r"^##\s+(.+?)\s*$", line)
        if h:
            skip = _norm(h.group(1)) in names
        if not skip:
            out.append(line)
    return "\n".join(out)


def svg(paths, size=24, stroke="#74A6FF", sw="1.5"):
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" '
            f'stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" '
            f'stroke-linejoin="round">{paths}</svg>')


# --------------------------------------------------------------------------- #
def rewrite_links(body, *, in_class):
    """Reescribe enlaces del markdown original a rutas del sitio."""
    def sub_href(m):
        text, href = m.group(1), m.group(2)
        h = href.strip()
        low = h.lower()
        if "solucion" in low:                       # nunca enlazar soluciones
            return text
        m2 = re.match(r"(\d\d)-CLASE-\1-CKA\.pptx$", h)
        if re.match(r"\d\d-CLASE-\d\d-CKA\.pptx$", h):
            return f'<a href="../slides/{h}">{text}</a>'
        m3 = re.match(r"LABORATORIOS/LAB-(\d\d)-[A-ZÁÉÍÓÚ-]+\.md$", h)
        if m3:
            return f'<a href="lab-{int(m3.group(1))}/">{text}</a>'
        if low.startswith("recursos/") or re.match(r"RECURSOS/?$", h):
            return f'<a href="recursos.html">{text}</a>'
        if h == "02-CHECKLIST-CKA.md":
            return f'<a href="checklist.html">{text}</a>'
        if h == "03-CHEATSHEET-CKA.md":
            return f'<a href="cheatsheet.html">{text}</a>'
        return m.group(0)

    body = re.sub(r'<a href="([^"]+)">((?:(?!</a>).)*)</a>', sub_href, body)
    # quita enlaces vacíos a directorios que markdown dejó como <a href="RECURSOS/YAML/">
    return body


def tasklists(body):
    body = re.sub(r'<li>\s*\[ \]\s*', '<li class="task"><span class="box"></span>', body)
    body = re.sub(r'<li>\s*\[[xX]\]\s*',
                  '<li class="task done"><span class="box"></span>', body)
    if 'class="task"' in body or 'class="task done"' in body:
        body = body.replace('<ul>\n<li class="task"',
                            '<ul class="tasks">\n<li class="task"')
    return body


def process_md(text, *, in_class):
    return tasklists(rewrite_links(md(preprocess(text)), in_class=in_class))


# --------------------------------------------------------------------------- #
def shell(*, title, root, breadcrumb, content, nav_active="", head_extra="",
          body_class=""):
    fonts = ('<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
             '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?'
             'family=IBM+Plex+Sans:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500&display=swap">')

    def na(key, label, href):
        cls = ' class="on"' if nav_active == key else ""
        return f'<a{cls} href="{href}">{label}</a>'

    nav = (na("inicio", "Inicio", f"{root}index.html")
           + na("training", "CKA Training", f"{root}index.html#training")
           + na("extras", "CKA Extras", f"{root}index.html#extras"))
    crumbs = ""
    if breadcrumb:
        parts = []
        for i, (label, href) in enumerate(breadcrumb):
            last = i == len(breadcrumb) - 1
            if href and not last:
                parts.append(f'<a href="{href}">{label}</a>')
            else:
                parts.append(f'<span>{label}</span>')
        crumbs = ('<nav class="crumbs">'
                  + '<span class="sep">/</span>'.join(parts) + '</nav>')

    return f"""<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} · {SITE}</title>
<meta name="description" content="{html.escape(BASE_TAGLINE)}">
{fonts}
<link rel="stylesheet" href="{root}assets/styles.css">
{head_extra}
</head>
<body class="{body_class}">
<header class="topbar">
  <a class="brand" href="{root}index.html">
    {svg(WHEEL, 24, "#74A6FF", "1.6")}
    <span>CKA · ENTRENAMIENTO</span>
  </a>
  <nav class="mainnav">{nav}<span class="chip mono">v1.35</span></nav>
  <button class="burger" aria-label="Menú" onclick="document.body.classList.toggle('nav-open')">
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#BDC9DB" stroke-width="2"><path d="M4 7h16M4 12h16M4 17h16"></path></svg>
  </button>
</header>
<main>
{crumbs}
{content}
</main>
<footer>
  <span>{SITE}</span>
</footer>
<script src="{root}assets/app.js"></script>
</body>
</html>
"""


# --------------------------------------------------------------------------- #
def lab_meta(md_path):
    txt = md_path.read_text(encoding="utf-8")
    h1 = re.search(r"^#\s+(.+)$", txt, re.M)
    raw = h1.group(1).strip() if h1 else md_path.stem
    raw = re.sub(r"`", "", raw)
    title = re.sub(r"^LAB\s+[\d.]+\s*[—-]\s*", "", raw).strip()
    num = re.search(r"LAB-(\d\d)-", md_path.name)
    n = int(num.group(1)) if num else 0
    lvlkey = md_path.stem.split("-", 2)[-1].split("-")[0].upper()
    for k in LEVELS:
        if k in md_path.stem.upper():
            lvlkey = k
            break
    lvl_label, lvl_tone = LEVELS.get(lvlkey, ("Lab", "blue"))
    dur = re.search(r"##\s*Duraci[oó]n\s*\n+\s*([^\n.]+)", txt, re.I)
    duration = dur.group(1).strip().rstrip(".") if dur else ""
    return {"n": n, "title": title, "level": lvl_label, "tone": lvl_tone,
            "duration": duration, "text": txt}


def labs_of(src_dir):
    labs = []
    for p in sorted((src_dir / "LABORATORIOS").glob("LAB-*.md")):
        labs.append((p, lab_meta(p)))
    return labs


def _safe(name):
    return name.replace("/", "~")


def resources_of(src_dir):
    """Devuelve [(grupo, nombre_visible, Path), ...] de RECURSOS/, sin SOLUCIONES."""
    rd = src_dir / "RECURSOS"
    if not rd.is_dir():
        return []
    res = []
    # documentos sueltos en RECURSOS/*.md
    for p in sorted(rd.glob("*.md")):
        res.append(("DOC", p.name, p))
    # carpetas planas
    for sub in ("YAML", "SCRIPTS", "CICD"):
        d = rd / sub
        if d.is_dir():
            for p in sorted(d.iterdir()):
                if p.is_file():
                    res.append((sub, p.name, p))
    # charts de Helm (recursivo)
    for sub in ("CHART", "CHART-ROTO"):
        d = rd / sub
        if d.is_dir():
            for p in sorted(d.rglob("*")):
                if p.is_file() and "solucion" not in p.name.lower():
                    res.append((sub, str(p.relative_to(rd)).replace("\\", "/"), p))
    return res


# --------------------------------------------------------------------------- #
def build():
    if OUT.exists():                       # vacía el contenido sin borrar docs/
        for child in OUT.iterdir():
            if child.is_dir():
                shutil.rmtree(child, ignore_errors=True)
            else:
                try:
                    child.unlink()
                except OSError:
                    pass
    OUT.mkdir(exist_ok=True)
    (OUT / "assets").mkdir(parents=True, exist_ok=True)
    (OUT / "slides").mkdir(exist_ok=True)

    write_assets()

    # presentaciones (.pptx) para descarga
    for slug, src, n, title, sub, icon, noun, gk in ITEMS:
        pptx = ROOT / src / f"01-{src}-CKA.pptx"
        if pptx.exists():
            shutil.copy2(pptx, OUT / "slides" / pptx.name)

    build_index()

    for gk, glabel, noun, gsub, items in GRUPOS:
        for i, (slug, src, n, title, sub, icon) in enumerate(items):
            src_dir = ROOT / src
            cdir = OUT / slug
            cdir.mkdir(parents=True, exist_ok=True)
            labs = labs_of(src_dir)
            res = resources_of(src_dir)

            rdir = cdir / "recursos"
            rdir.mkdir(exist_ok=True)
            for _g, name, p in res:
                shutil.copy2(p, rdir / _safe(name))
            build_recursos(slug, src, n, title, res, noun)

            build_clase(slug, src, n, title, sub, icon, src_dir, labs, res, noun, gk,
                        prev_=items[i - 1] if i else None,
                        next_=items[i + 1] if i + 1 < len(items) else None)

            for j, (p, meta) in enumerate(labs):
                build_lab(slug, src, n, title, labs, j, meta, noun)

            # extras de la Clase 6: checklist y cheatsheet
            if slug == "clase-6":
                for fname, page, label in (
                        ("02-CHECKLIST-CKA.md", "checklist.html", "Checklist CKA"),
                        ("03-CHEATSHEET-CKA.md", "cheatsheet.html", "Cheat Sheet CKA")):
                    fp = src_dir / fname
                    if fp.exists():
                        bd = process_md(fp.read_text(encoding="utf-8"), in_class=True)
                        (cdir / page).write_text(shell(
                            title=f"{label} · Clase 6", root="../",
                            breadcrumb=[("Inicio", "../index.html"),
                                        ("Clase 6", "index.html"), (label, None)],
                            content=f'<article class="md wide">{bd}</article>'),
                            encoding="utf-8")

    (OUT / ".nojekyll").write_text("", encoding="utf-8")
    (OUT / "404.html").write_text(shell(
        title="No encontrado", root="",
        breadcrumb=[], nav_active="",
        content='<section class="hero"><h1>Página no encontrada</h1>'
                '<p><a href="./index.html">Volver al inicio →</a></p></section>'),
        encoding="utf-8")

    n_pages = len(list(OUT.rglob("*.html")))
    print(f"_site/ generado — {n_pages} páginas HTML")


# --------------------------------------------------------------------------- #
def build_index():
    def card(slug, src, n, title, sub, icon, noun):
        nlabs = len(list((ROOT / src / "LABORATORIOS").glob("LAB-*.md")))
        badge = f"S{int(n)}" if noun == "Sesión" else f"{int(n):02d}"
        return f"""
      <a class="ccard" href="{slug}/">
        <div class="ccard-top"><span class="mono num">{badge}</span>{svg(ICONS[icon], 26)}</div>
        <h3>{html.escape(title)}</h3>
        <p>{html.escape(sub)}</p>
        <div class="ccard-foot"><span class="mono">180 min · {nlabs} labs</span><span class="go">Ver {noun.lower()} →</span></div>
      </a>"""

    grupos_html = []
    n_total_labs = sum(len(list((ROOT / it[1] / "LABORATORIOS").glob("LAB-*.md"))) for it in ITEMS)
    for gk, glabel, noun, gsub, items in GRUPOS:
        cards = "".join(card(s, sr, n, t, sb, ic, noun) for (s, sr, n, t, sb, ic) in items)
        grupos_html.append(f"""
<section class="block" id="{gk}">
  <div class="group-head">
    <h2 class="section-title">{html.escape(glabel)}</h2>
    <span class="mono muted">{len(items)} {'sesiones' if noun == 'Sesión' else 'clases'}</span>
  </div>
  <p class="group-sub">{html.escape(gsub)}</p>
  <div class="cgrid">{cards}</div>
</section>""")

    content = f"""
<section class="hero">
  <div class="eyebrow">Kubernetes práctico · CKA</div>
  <h1>Entrenamiento · Kubernetes</h1>
  <p class="lead">Dos tracks sobre una misma base práctica: <strong>CKA Training</strong>,
  siete sesiones sobre la arquitectura GRATITUD (Services, Ingress, config, storage,
  observabilidad, seguridad, CI/CD e integrador), y <strong>CKA Extras</strong>, las seis
  clases de fundamentos y troubleshooting.</p>
  <div class="stats">
    <div class="stat"><b>13</b><span>Módulos</span></div>
    <div class="stat"><b>{n_total_labs}</b><span>Laboratorios</span></div>
    <div class="stat"><b>2</b><span>Tracks</span></div>
    <div class="stat"><b>GRATITUD</b><span>Caso guía</span></div>
  </div>
  <div class="chips" style="margin-top:24px">
    <a class="chip" href="#training">CKA Training →</a>
    <a class="chip" href="#extras">CKA Extras →</a>
  </div>
</section>
{''.join(grupos_html)}
"""
    (OUT / "index.html").write_text(shell(
        title="Inicio", root="", breadcrumb=[], nav_active="inicio",
        content=content, body_class="home"), encoding="utf-8")


def rail_labs(labs, current=None, rel=""):
    rows = []
    for p, m in labs:
        on = ' class="on"' if current == m["n"] else ""
        chip = f'<span class="lvl {m["tone"]} mono">{m["level"][:8]}</span>'
        rows.append(f'<a{on} href="{rel}lab-{m["n"]}/"><span>LAB {"?" if not m["n"] else ""}'
                    f'{m["title"]}</span>{chip}</a>')
    return "".join(rows)


def build_clase(slug, src, n, title, sub, icon, src_dir, labs, res, noun, gk, prev_, next_):
    readme = (src_dir / "00-README.md").read_text(encoding="utf-8")
    readme = drop_sections(drop_h1(readme),
                           ["Duración", "Duracion", "Presentación", "Presentacion",
                            "Laboratorios", "Recursos", "Material adicional"])
    body = process_md(readme, in_class=True)
    pptx_name = f"01-{src}-CKA.pptx"

    lab_rows = "".join(
        f'<a href="lab-{m["n"]}/"><span>LAB {n}.{m["n"]} — {html.escape(m["title"])}</span>'
        f'<span class="lvl {m["tone"]} mono">{m["level"]}</span></a>'
        for _, m in labs)

    groups = []
    for g, name, p in res:
        if g not in groups:
            groups.append(g)

    def res_rows(group):
        return "".join(
            f'<div class="rrow mono"><span>{html.escape(name)}</span>'
            f'<span class="acts"><a href="recursos.html#{_safe(name)}" title="Ver">{svg(IC_COPY,14,"currentColor","2")}</a>'
            f'<a href="recursos/{_safe(name)}" download title="Descargar">{svg(IC_DL,14,"currentColor","2")}</a></span></div>'
            for g, name, p in res if g == group)

    res_blocks = "".join(
        f'<div class="railcard-h"{" style=\"margin-top:16px\"" if i else ""}>{g}</div>'
        f'<div class="rlist">{res_rows(g)}</div>'
        for i, g in enumerate(groups))

    prevlink = f'<a href="../{prev_[0]}/">← {noun} {prev_[2]}</a>' if prev_ else '<span></span>'
    nextlink = f'<a href="../{next_[0]}/">{noun} {next_[2]} →</a>' if next_ else '<span></span>'

    content = f"""
<section class="clase-head">
  <div class="eyebrow">{noun} {n}</div>
  <h1>{html.escape(title)}</h1>
  <p class="lead">{html.escape(sub)}</p>
  <div class="chips">
    <span class="chip mono">180 min</span>
    <span class="chip mono">{len(labs)} laboratorios</span>
    <span class="chip mono">Kubernetes v1.35</span>
  </div>
</section>

<div class="two-col">
  <article class="md">{body}</article>
  <aside class="rail">
    <div class="railcard">
      <div class="railcard-h">Presentación</div>
      <div class="slide-row">{svg(IC_SLIDES,22)}<div><div class="mono fn">{pptx_name}</div></div></div>
      <a class="btn primary" href="../slides/{pptx_name}" download>Descargar .pptx</a>
    </div>
    <div class="railcard">
      <div class="railcard-h">Laboratorios</div>
      <div class="lab-list">{lab_rows}</div>
    </div>
    {'<div class="railcard">' + res_blocks + '<a class="btn" href="recursos.html">Abrir visor de recursos</a></div>' if res else ''}
  </aside>
</div>

<nav class="pager">{prevlink}{nextlink}</nav>
"""
    (OUT / slug / "index.html").write_text(shell(
        title=f"{noun} {n} — {title}", root="../", nav_active=gk,
        breadcrumb=[("Inicio", "../index.html"), (f"{noun} {n}", None)],
        content=content), encoding="utf-8")


def build_lab(slug, src, n, ctitle, labs, idx, meta, noun="Sesión"):
    p, m = labs[idx]
    labtext = drop_sections(drop_h1(m["text"]), ["Nivel", "Duración", "Duracion"])
    body = process_md(labtext, in_class=True)
    ldir = OUT / slug / f"lab-{m['n']}"
    ldir.mkdir(parents=True, exist_ok=True)

    sidelabs = "".join(
        f'<a class="{"on" if k == idx else ""}" href="../lab-{mm["n"]}/">'
        f'LAB {n}.{mm["n"]} — {html.escape(mm["title"])}</a>'
        for k, (_, mm) in enumerate(labs))

    prev_ = f'<a href="../lab-{labs[idx-1][1]["n"]}/">← LAB {n}.{labs[idx-1][1]["n"]}</a>' if idx else '<span></span>'
    nxt = f'<a href="../lab-{labs[idx+1][1]["n"]}/">LAB {n}.{labs[idx+1][1]["n"]} →</a>' if idx + 1 < len(labs) else '<span></span>'

    content = f"""
<div class="lab-layout">
  <aside class="lab-side">
    <details class="lab-nav" open>
      <summary>{noun} {n} · Laboratorios</summary>
      <div class="railcard-h">{noun} {n} · Laboratorios</div>
      <div class="side-labs">{sidelabs}</div>
      <div class="railcard-h" style="margin-top:22px">Recursos</div>
      <a class="rlink" href="../recursos.html">Visor de recursos</a>
      <a class="rlink" href="../../slides/01-{src}-CKA.pptx" download>Presentación (.pptx)</a>
    </details>
  </aside>
  <script>if(matchMedia('(max-width:900px)').matches){{var _ln=document.currentScript.previousElementSibling.querySelector('.lab-nav');if(_ln)_ln.removeAttribute('open');}}</script>
  <article class="md lab-body">
    <div class="eyebrow">LAB {n}.{m['n']}</div>
    <h1>{html.escape(m['title'])}</h1>
    <div class="chips">
      <span class="lvl {m['tone']} mono">Nivel · {m['level']}</span>
      {'<span class="chip mono">' + html.escape(m['duration']) + '</span>' if m['duration'] else ''}
    </div>
    {body}
    <div class="lab-note">
      {svg('<circle cx="12" cy="12" r="9"></circle><path d="M12 8v5M12 16h.01"></path>', 15, "#8493AD", "2")}
      La solución de este laboratorio es material del instructor y no se incluye en el sitio del alumno.
    </div>
    <nav class="pager">{prev_}{nxt}</nav>
  </article>
</div>
"""
    (ldir / "index.html").write_text(shell(
        title=f"LAB {n}.{m['n']} — {m['title']}", root="../../", nav_active="inicio",
        breadcrumb=[("Inicio", "../../index.html"),
                    (f"{noun} {n}", "../index.html"),
                    (f"LAB {n}.{m['n']}", None)],
        content=content, body_class="labpage"), encoding="utf-8")


def build_recursos(slug, src, n, title, res, noun="Sesión"):
    listing = []
    panels = []
    last_kind = None
    for kind, name, p in res:
        if kind != last_kind:
            listing.append(f'<div class="rl-group mono">{kind}</div>')
            last_kind = kind
        listing.append(
            f'<a class="rl-item mono" href="#{_safe(name)}" data-file="{_safe(name)}">{html.escape(name)}</a>')
    for kind, name, p in res:
        raw = p.read_text(encoding="utf-8", errors="replace")
        try:
            lexer = get_lexer_for_filename(p.name, raw)
        except Exception:
            try:
                lexer = guess_lexer(raw)
            except Exception:
                lexer = get_lexer_for_filename("x.txt")
        hl = pyg_highlight(raw, lexer, HtmlFormatter(style="native", cssclass="hl", nowrap=False))
        nlines = raw.count("\n") + 1
        anchor = _safe(name)
        panels.append(f"""
    <div class="viewer" data-file="{anchor}" hidden>
      <div class="viewer-h">
        <div class="vh-l"><span class="mono fn">{html.escape(name)}</span>
          <span class="badge mono">{p.suffix.lstrip('.').upper() or 'TXT'}</span>
          <span class="muted">{nlines} líneas · {p.stat().st_size} B</span></div>
        <div class="vh-r">
          <button class="btn sm copybtn" data-target="{anchor}">{svg(IC_COPY,14,"currentColor","2")} Copiar</button>
          <a class="btn sm primary" href="recursos/{anchor}" download>{svg(IC_DL,14,"currentColor","2")} Descargar</a>
        </div>
      </div>
      <div class="viewer-code">{hl}</div>
    </div>""")

    content = f"""
<section class="clase-head compact">
  <div class="eyebrow">{noun} {n} · Recursos</div>
  <h1>Manifiestos, scripts y charts</h1>
  <p class="lead">Archivos de referencia de los laboratorios. Cópialos o descárgalos.</p>
</section>
<div class="viewer-layout">
  <nav class="rl">{''.join(listing)}</nav>
  <div class="viewer-stack">{''.join(panels)}</div>
</div>
"""
    (OUT / slug / "recursos.html").write_text(shell(
        title=f"Recursos · {noun} {n}", root="../", nav_active="inicio",
        breadcrumb=[("Inicio", "../index.html"), (f"{noun} {n}", "index.html"),
                    ("Recursos", None)],
        content=content, body_class="viewerpage"), encoding="utf-8")


# --------------------------------------------------------------------------- #
def write_assets():
    pyg = HtmlFormatter(style="native").get_style_defs(".hl")
    (OUT / "assets" / "styles.css").write_text(STYLES + "\n\n/* pygments */\n"
                                              + pyg + PYG_FIX, encoding="utf-8")
    (OUT / "assets" / "app.js").write_text(APPJS, encoding="utf-8")


# --------------------------------------------------------------------------- #
STYLES = r"""
:root{
  --bg:#0B1220; --panel:#131C2E; --soft:#0F1729; --line:#26354E;
  --ink:#F3F6FC; --body:#BDC9DB; --muted:#8493AD; --faint:#4C5B75;
  --blue:#326CE5; --blue2:#74A6FF; --ok:#3FB950; --warn:#E3B341; --danger:#F85149;
  --code:#0A1120; --codet:#E6EDF3; --maxw:1120px;
}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--body);
  font-family:"IBM Plex Sans","Segoe UI",system-ui,sans-serif;font-size:15px;line-height:1.62;
  -webkit-font-smoothing:antialiased}
h1,h2,h3,h4{color:var(--ink);font-weight:600;line-height:1.25;margin:0}
a{color:var(--blue2);text-decoration:none}
a:hover{color:#a7c6ff}
.mono{font-family:"IBM Plex Mono",ui-monospace,Consolas,monospace}
.muted{color:var(--muted)}
img{max-width:100%}

/* topbar */
.topbar{position:sticky;top:0;z-index:20;display:flex;align-items:center;justify-content:space-between;
  height:60px;padding:0 clamp(16px,4vw,48px);border-bottom:1px solid var(--line);
  background:rgba(11,18,32,.86);backdrop-filter:blur(8px)}
.brand{display:flex;align-items:center;gap:11px;color:var(--ink);font-weight:600;
  letter-spacing:.13em;font-size:12.5px}
.mainnav{display:flex;align-items:center;gap:26px;font-size:14px}
.mainnav a{color:var(--muted)} .mainnav a.on{color:var(--ink)}
.chip{border:1px solid var(--line);border-radius:999px;padding:4px 12px;color:var(--blue2);
  font-size:12px;font-weight:600}
.burger{display:none;background:none;border:0;padding:6px;cursor:pointer}

main{max-width:var(--maxw);margin:0 auto;padding:0 clamp(16px,4vw,48px) 72px}
footer{max-width:var(--maxw);margin:0 auto;padding:26px clamp(16px,4vw,48px) 40px;
  border-top:1px solid var(--line);display:flex;flex-direction:column;gap:6px;font-size:12.5px;color:var(--muted)}

.crumbs{display:flex;gap:8px;align-items:center;font-size:13px;color:var(--muted);padding:26px 0 0}
.crumbs a{color:var(--muted)} .crumbs span:last-child{color:var(--body)} .crumbs .sep{color:var(--faint)}

.eyebrow{color:var(--blue2);font-weight:600;font-size:12px;letter-spacing:.18em;text-transform:uppercase}
.lead{max-width:660px;font-size:16.5px;color:var(--body)}
.section-title{font-size:15px;color:var(--muted);letter-spacing:.15em;text-transform:uppercase;font-weight:600;margin:0}
.group-head{display:flex;align-items:baseline;gap:14px;border-top:1px solid var(--line);padding-top:22px}
.group-sub{max-width:640px;font-size:14px;color:var(--muted);margin:8px 0 22px}
.chips,.chip-row{display:flex;gap:10px;flex-wrap:wrap;margin-top:18px}
a.chip:hover{border-color:var(--blue2);color:#a7c6ff}
.block{margin-top:44px;scroll-margin-top:80px}

/* home */
.hero{padding:60px 0 8px}
.hero h1{font-size:clamp(32px,5vw,46px);margin:14px 0 0;letter-spacing:-.01em}
.stats{display:flex;gap:14px;margin-top:30px;flex-wrap:wrap}
.stat{border:1px solid var(--line);border-radius:12px;padding:14px 20px;background:var(--panel);min-width:128px}
.stat b{display:block;font-size:22px;color:var(--ink);font-weight:600}
.stat span{font-size:11px;color:var(--muted);letter-spacing:.12em;text-transform:uppercase}

.cgrid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:20px}
.ccard{border:1px solid var(--line);border-radius:16px;background:var(--panel);padding:22px;
  display:flex;flex-direction:column;gap:12px;color:var(--body)}
.ccard:hover{border-color:#3a5488;background:#16223a}
.ccard-top{display:flex;align-items:center;justify-content:space-between}
.ccard .num{font-size:13px;color:var(--faint)}
.ccard h3{font-size:18px}
.ccard p{font-size:13px;color:var(--muted);margin:0;flex-grow:1}
.ccard-foot{display:flex;align-items:center;justify-content:space-between;border-top:1px solid var(--line);
  padding-top:12px;font-size:12px}
.ccard-foot .mono{color:var(--muted)} .ccard-foot .go{color:var(--blue2);font-weight:600}

.method{border:1px solid var(--line);border-radius:14px;background:var(--soft);padding:18px 22px;
  display:flex;align-items:center;gap:16px;flex-wrap:wrap}
.method-k{color:var(--blue2);font-size:11px;font-weight:700;letter-spacing:.14em;text-transform:uppercase}
.method-flow{font-size:12.5px;color:var(--body)}
.notice{display:flex;align-items:center;gap:9px;font-size:12.5px;color:var(--muted);margin-top:16px;flex-wrap:wrap}

/* clase head */
.clase-head{padding:26px 0 0}
.clase-head.compact{padding:10px 0 0}
.clase-head h1{font-size:clamp(26px,4vw,36px);margin:12px 0 0;letter-spacing:-.01em}

/* two column */
.two-col{display:grid;grid-template-columns:minmax(0,1fr) 340px;gap:40px;align-items:start;margin-top:34px}
.rail{display:flex;flex-direction:column;gap:20px;position:sticky;top:80px}
.railcard{border:1px solid var(--line);border-radius:14px;background:var(--panel);padding:18px}
.railcard-h{font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:var(--muted);font-weight:600;margin-bottom:12px}
.slide-row{display:flex;align-items:center;gap:12px} .slide-row .fn{font-size:12.5px;color:var(--ink)}
.btn{display:block;text-align:center;border:1px solid var(--line);color:var(--body);border-radius:8px;
  padding:8px 12px;font-size:12.5px;margin-top:12px}
.btn.primary{background:var(--blue);border-color:var(--blue);color:#fff;font-weight:600}
.btn.sm{display:inline-flex;align-items:center;gap:6px;margin:0;padding:6px 11px}
.lab-list,.rlist,.lab-side .side-labs{display:flex;flex-direction:column;gap:3px}
.lab-list a{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:9px 10px;
  border-radius:8px;font-size:13px;color:var(--body)}
.lab-list a:first-child{background:var(--soft)} .lab-list a:hover{background:var(--soft);color:var(--ink)}
.lvl{font-size:10.5px;border-radius:999px;padding:2px 8px;white-space:nowrap}
.lvl.ok{color:#63D178;border:1px solid rgba(63,185,80,.4)}
.lvl.blue{color:var(--blue2);border:1px solid rgba(116,166,255,.4)}
.lvl.warn{color:var(--warn);border:1px solid rgba(227,179,65,.4)}
.lvl.danger{color:#FF7B72;border:1px solid rgba(248,81,73,.4)}
.rrow{display:flex;align-items:center;justify-content:space-between;gap:10px;font-size:12px;padding:6px 0;color:var(--body)}
.rrow>span:first-child{overflow-wrap:anywhere;min-width:0}
.rrow .acts{display:flex;gap:10px;color:var(--faint);flex-shrink:0}
.rrow .acts a:hover{color:var(--blue2)}
.rlink{display:block;font-size:12.5px;color:var(--body);padding:6px 0}

.pager{display:flex;justify-content:space-between;margin-top:40px;padding-top:20px;border-top:1px solid var(--line);font-size:13.5px}

/* lab layout */
.lab-layout{display:grid;grid-template-columns:262px minmax(0,1fr);gap:44px;align-items:start;margin-top:20px}
.lab-side{position:sticky;top:80px;display:flex;flex-direction:column}
.lab-nav>summary{display:none}
.lab-side .side-labs a{padding:9px 12px;border-radius:8px;font-size:13px;color:var(--body);border-left:2px solid transparent}
.lab-side .side-labs a.on{background:rgba(50,108,229,.14);color:var(--ink);font-weight:500;border-left-color:var(--blue)}
.lab-side .side-labs a:hover{color:var(--ink)}
.lab-body{max-width:820px}
.lab-note,.md .lab-note{margin-top:32px;border:1px solid var(--line);border-radius:10px;background:var(--soft);
  padding:14px 18px;font-size:12.5px;color:var(--muted);display:flex;align-items:center;gap:10px}

/* markdown */
.md{color:var(--body)}
.md.wide{max-width:820px}
.md h1{font-size:32px;margin:6px 0 0;letter-spacing:-.01em}
.md h2{font-size:20px;margin:34px 0 12px;padding-top:6px}
.md h3{font-size:16px;margin:24px 0 8px;color:var(--ink)}
.md p{margin:0 0 14px}
.md ul,.md ol{margin:0 0 16px;padding-left:22px}
.md li{margin:6px 0}
.md li::marker{color:var(--blue2)}
.md a{border-bottom:1px solid rgba(116,166,255,.3)}
.md strong{color:var(--ink)}
.md hr{border:0;border-top:1px solid var(--line);margin:28px 0}
.md blockquote{margin:16px 0;padding:2px 16px;border-left:3px solid var(--blue);color:var(--muted)}
.md code{font-family:"IBM Plex Mono",ui-monospace,Consolas,monospace;font-size:.9em;
  background:rgba(50,108,229,.14);color:#cfe0ff;border-radius:4px;padding:1px 6px}
.md pre{background:var(--code);border:1px solid var(--line);border-radius:12px;padding:16px 18px;
  overflow-x:auto;margin:0 0 18px;position:relative}
.md pre code{background:none;color:var(--codet);padding:0;font-size:12.8px;line-height:1.75}
.md .hl,.md .codehilite{background:var(--code);border:1px solid var(--line);border-radius:12px;
  overflow-x:auto;margin:0 0 18px;position:relative}
.md .hl pre,.md .codehilite pre{background:none;border:0;border-radius:0;margin:0;padding:16px 18px}
.md table{border-collapse:collapse;width:100%;margin:0 0 20px;font-size:13.5px;
  border:1px solid var(--line);border-radius:10px;overflow:hidden}
.md thead{background:var(--soft)}
.md th{text-align:left;padding:10px 14px;font-size:11px;letter-spacing:.1em;text-transform:uppercase;
  color:var(--muted);font-weight:600}
.md td{padding:10px 14px;border-top:1px solid var(--line)}
.md tbody tr:nth-child(even){background:rgba(255,255,255,.015)}
.md .tasks,.md ul.tasks{list-style:none;padding-left:0}
.md li.task{display:flex;gap:10px;align-items:flex-start;margin:8px 0}
.md li.task .box{width:16px;height:16px;border:1.5px solid var(--faint);border-radius:4px;flex-shrink:0;margin-top:3px}
.md li.task.done .box{background:var(--blue);border-color:var(--blue)}
.copybtn-float{position:absolute;top:8px;right:8px;background:var(--soft);border:1px solid var(--line);
  color:var(--muted);border-radius:7px;padding:5px 9px;font-size:11px;cursor:pointer;display:flex;gap:5px;align-items:center}
.copybtn-float:hover{color:var(--blue2)}

/* recursos viewer */
.viewer-layout{display:grid;grid-template-columns:250px minmax(0,1fr);gap:32px;align-items:start;margin-top:24px}
.rl{border:1px solid var(--line);border-radius:12px;background:var(--panel);overflow:hidden;padding:8px 0}
.rl-group{font-size:11px;color:var(--faint);padding:10px 16px 6px}
.rl-item{display:block;padding:7px 16px 7px 26px;font-size:12.5px;color:var(--body)}
.rl-item.on{background:rgba(50,108,229,.14);color:var(--ink);border-left:2px solid var(--blue)}
.rl-item:hover{color:var(--ink)}
.viewer{border:1px solid var(--line);border-radius:12px;overflow:hidden;background:var(--code)}
.viewer-h{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:11px 16px;
  border-bottom:1px solid var(--line);background:var(--soft);flex-wrap:wrap}
.vh-l{display:flex;align-items:center;gap:10px;font-size:12.5px}
.vh-l .fn{color:var(--ink)} .vh-l .muted{font-size:11.5px}
.badge{font-size:10.5px;color:var(--blue2);border:1px solid rgba(116,166,255,.35);border-radius:5px;padding:1px 7px}
.vh-r{display:flex;gap:8px}
.viewer-code{overflow-x:auto}
.viewer-code pre{margin:0;padding:16px 18px;font-size:12.8px;line-height:1.8;background:none;border:0}

/* mobile */
@media (max-width:900px){
  .mainnav{display:none}
  .burger{display:block}
  body.nav-open .mainnav{display:flex;position:absolute;top:60px;left:0;right:0;flex-direction:column;
    gap:0;background:var(--panel);border-bottom:1px solid var(--line);padding:8px 24px 16px}
  body.nav-open .mainnav a{padding:12px 0}
  .cgrid{grid-template-columns:1fr}
  .two-col,.lab-layout,.viewer-layout{grid-template-columns:1fr}
  .rail,.lab-side{position:static}
  .lab-side{margin-bottom:6px}
  .lab-nav>summary{display:flex;align-items:center;justify-content:space-between;
    list-style:none;cursor:pointer;background:var(--panel);border:1px solid var(--line);
    border-radius:10px;padding:11px 14px;font-size:13px;color:var(--body)}
  .lab-nav>summary::-webkit-details-marker{display:none}
  .lab-nav>summary::after{content:"▸";color:var(--muted)}
  .lab-nav[open]>summary::after{content:"▾"}
  .lab-nav>summary+.railcard-h{display:none}
  .lab-nav[open]{border:1px solid var(--line);border-top:0;border-radius:0 0 10px 10px;padding:4px 12px 12px}
  .stats{gap:10px}.stat{min-width:calc(50% - 5px)}
}
"""

PYG_FIX = r"""
.hl{background:#0A1120!important}
.hl pre{background:#0A1120!important}
.hl .c,.hl .c1,.hl .cm,.hl .cp,.hl .cs{font-style:italic}
"""

APPJS = r"""
(function(){
  "use strict";
  // copy buttons for markdown code blocks
  document.querySelectorAll('.md pre, .md .hl, .md .codehilite').forEach(function(pre){
    if(pre.querySelector('.copybtn-float')) return;
    var b=document.createElement('button');
    b.className='copybtn-float';
    b.type='button';
    b.innerHTML='<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="12" height="12" rx="2"></rect><path d="M5 15V5a2 2 0 0 1 2-2h10"></path></svg> Copiar';
    b.addEventListener('click',function(){
      var code=pre.querySelector('code')||pre.querySelector('pre')||pre;
      navigator.clipboard.writeText(code.innerText.replace(/\n$/,'')).then(function(){
        b.textContent='Copiado'; setTimeout(function(){b.innerHTML='<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="12" height="12" rx="2"></rect><path d="M5 15V5a2 2 0 0 1 2-2h10"></path></svg> Copiar';},1400);
      });
    });
    pre.appendChild(b);
  });

  // resource viewer
  var stack=document.querySelector('.viewer-stack');
  if(stack){
    var items=[].slice.call(document.querySelectorAll('.rl-item'));
    var viewers=[].slice.call(document.querySelectorAll('.viewer'));
    function show(name){
      viewers.forEach(function(v){ v.hidden = v.dataset.file!==name; });
      items.forEach(function(a){ a.classList.toggle('on', a.dataset.file===name); });
    }
    items.forEach(function(a){
      a.addEventListener('click',function(e){ e.preventDefault();
        history.replaceState(null,'','#'+a.dataset.file); show(a.dataset.file); });
    });
    var initial=(location.hash||'').replace('#','');
    if(!initial || !viewers.some(function(v){return v.dataset.file===initial;}))
      initial = items[0] && items[0].dataset.file;
    if(initial) show(initial);

    document.querySelectorAll('.copybtn').forEach(function(btn){
      btn.addEventListener('click',function(){
        var v=document.querySelector('.viewer[data-file="'+btn.dataset.target+'"] .viewer-code');
        if(!v) return;
        navigator.clipboard.writeText(v.innerText.replace(/\n$/,'')).then(function(){
          var t=btn.innerHTML; btn.textContent='Copiado';
          setTimeout(function(){btn.innerHTML=t;},1400);
        });
      });
    });
  }
})();
"""

if __name__ == "__main__":
    build()
