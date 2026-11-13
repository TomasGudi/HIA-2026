"""Genera el informe consolidado (HTML + PDF) a partir de docs/informe/*.md.

Uso:
    python scripts/informe.py            # HTML + PDF
    python scripts/informe.py --solo-html

El PDF se imprime con Edge en modo headless (no requiere pandoc ni LaTeX).
Los bloques ```mermaid se renderizan con mermaid.js desde CDN al imprimir.
"""
from __future__ import annotations

import argparse
import html as html_lib
import pathlib
import re
import shutil
import subprocess
import sys

import markdown

unescape = html_lib.unescape

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs" / "informe"
SALIDA_HTML = ROOT / "docs" / "informe-consolidado.html"
SALIDA_PDF = ROOT / "docs" / "HIA-2026-informe-final.pdf"
SALIDA_MD = ROOT / "docs" / "informe-consolidado.md"

TITULO = "Práctica Integradora Final 2026"
SUBTITULO = "Informe técnico consolidado"
FECHA = "17 de noviembre de 2026"
REPO = "https://github.com/TomasGudi/HIA-2026"

ROLES = [
    ("R1", "Infraestructura y base de datos", "§4, §5, §6"),
    ("R2", "Aplicación y CI/CD", "§1, §3, §7, §8"),
    ("R3", "Observabilidad e incidencias", "§10, §11"),
    ("R4", "Automatización", "§12, §13"),
    ("R5", "Seguridad y documentación", "§9, §14, §15"),
]

CSS = """
@page { size: A4; margin: 18mm 16mm 18mm 16mm; }
* { box-sizing: border-box; }
body {
  font-family: "Segoe UI", "Helvetica Neue", Arial, sans-serif;
  font-size: 10.5pt; line-height: 1.5; color: #1a1a1a; margin: 0;
}
h1, h2, h3, h4 { font-family: "Segoe UI Semibold", "Segoe UI", Arial, sans-serif;
  color: #0f2b46; line-height: 1.25; }
h1 { font-size: 20pt; margin: 0 0 6pt; padding-bottom: 6pt;
     border-bottom: 2px solid #0f2b46; page-break-before: always; }
h2 { font-size: 14pt; margin: 16pt 0 5pt; color: #14456b; }
h3 { font-size: 11.5pt; margin: 12pt 0 4pt; color: #1c5a86; }
h2, h3, h4 { page-break-after: avoid; }
p { margin: 0 0 6pt; text-align: justify; }
ul, ol { margin: 0 0 7pt; padding-left: 16pt; }
li { margin-bottom: 2pt; }
table { width: 100%; border-collapse: collapse; margin: 6pt 0 10pt;
        font-size: 8.6pt; page-break-inside: auto; }
th { background: #0f2b46; color: #fff; text-align: left; padding: 4pt 5pt;
     font-weight: 600; }
td { border: 0.5pt solid #c9d4de; padding: 3.5pt 5pt; vertical-align: top; }
tr:nth-child(even) td { background: #f4f7fa; }
tr { page-break-inside: avoid; }
code { font-family: "Cascadia Mono", Consolas, monospace; font-size: 8.6pt;
       background: #eef2f6; padding: 0.5pt 3pt; border-radius: 2pt; }
pre { background: #f6f8fa; border: 0.5pt solid #d7dee5; border-left: 3pt solid #1c5a86;
      padding: 6pt 8pt; margin: 6pt 0 9pt; overflow-x: auto; page-break-inside: avoid;
      white-space: pre-wrap; word-break: break-word; }
pre code { background: none; padding: 0; font-size: 8.2pt; }
blockquote { margin: 6pt 0; padding: 4pt 10pt; border-left: 3pt solid #b8c6d2;
             background: #f7f9fb; color: #33475b; }
a { color: #14456b; text-decoration: none; }
hr { border: none; border-top: 0.5pt solid #c9d4de; margin: 12pt 0; }
.portada { height: 245mm; display: flex; flex-direction: column;
           justify-content: space-between; page-break-after: always; }
.portada .marca { font-size: 9pt; letter-spacing: 2pt; text-transform: uppercase;
                  color: #1c5a86; }
.portada h1 { border: none; page-break-before: avoid; font-size: 30pt;
              margin: 12pt 0 4pt; padding: 0; }
.portada .sub { font-size: 14pt; color: #33475b; margin-bottom: 18pt; }
.portada .meta { font-size: 9.5pt; color: #4a5b6b; }
.portada table { font-size: 9pt; }
.toc { page-break-after: always; }
.toc h1 { page-break-before: avoid; }
.toc ul { list-style: none; padding-left: 0; }
.toc li { margin: 3pt 0; font-size: 10pt; }
.toc .n1 { font-weight: 600; margin-top: 7pt; }
.toc .n2 { padding-left: 14pt; color: #33475b; font-size: 9.2pt; }
.aviso { font-size: 8.6pt; color: #4a5b6b; }
.diagrama { margin: 6pt 0 10pt; text-align: center; page-break-inside: avoid; }
.diagrama svg { max-width: 100%; height: auto; }
"""

MERMAID_SCRIPT = """
<script type="module">
import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs";
mermaid.initialize({ startOnLoad: false, theme: "neutral", securityLevel: "loose" });
const bloques = Array.from(document.querySelectorAll("pre.mermaid"));
for (let i = 0; i < bloques.length; i++) {
  try {
    const { svg } = await mermaid.render("diagrama-" + i, bloques[i].textContent);
    const caja = document.createElement("div");
    caja.className = "diagrama";
    caja.innerHTML = svg;
    bloques[i].replaceWith(caja);
  } catch (e) {
    bloques[i].textContent = "No se pudo renderizar el diagrama: " + e.message;
  }
}
document.body.dataset.mermaid = "listo";
</script>
"""


def slug(texto: str, usados: dict[str, int]) -> str:
    base = re.sub(r"[^a-z0-9]+", "-", texto.lower()).strip("-") or "seccion"
    n = usados.get(base, 0) + 1
    usados[base] = n
    return base if n == 1 else f"{base}-{n}"


def limpiar_enlaces(html: str) -> str:
    """Convierte enlaces relativos a texto: en el PDF no llevan a ningún lado."""
    return re.sub(r'<a href="(?!#)[^"]*">([^<]*)</a>', r"\1", html)


def convertir(ruta: pathlib.Path, usados: dict[str, int]) -> tuple[str, list[tuple[int, str, str]]]:
    texto = ruta.read_text(encoding="utf-8")
    md = markdown.Markdown(
        extensions=["tables", "fenced_code", "sane_lists", "attr_list"],
        output_format="html5",
    )
    html = md.convert(texto)
    html = re.sub(
        r'<pre><code class="language-mermaid">(.*?)</code></pre>',
        lambda m: '<pre class="mermaid">' + unescape(m.group(1)) + "</pre>",
        html,
        flags=re.S,
    )
    html = limpiar_enlaces(html)

    indice: list[tuple[int, str, str]] = []
    for nivel, texto_h in re.findall(r"<h([12])>(.*?)</h\1>", html, flags=re.S):
        limpio = re.sub(r"<[^>]+>", "", texto_h).strip()
        ident = slug(limpio, usados)
        html = html.replace(f"<h{nivel}>{texto_h}</h{nivel}>",
                            f'<h{nivel} id="{ident}">{texto_h}</h{nivel}>', 1)
        indice.append((int(nivel), limpio, ident))
    return html, indice


def portada() -> str:
    filas = "\n".join(
        f"<tr><td><strong>{rol}</strong></td><td>{nombre}</td><td>{secciones}</td></tr>"
        for rol, nombre, secciones in ROLES
    )
    return f"""
<section class="portada">
  <div>
    <div class="marca">Práctica Integradora Final · 2026</div>
    <h1>{TITULO}</h1>
    <div class="sub">{SUBTITULO}</div>
    <div class="meta">
      Aplicación Conduit/RealWorld contenerizada con PostgreSQL 16, réplica streaming,
      CI/CD, monitoreo, automatización con n8n y gestión de incidencias con Mantis.
    </div>
  </div>
  <div>
    <table>
      <thead><tr><th>Rol</th><th>Responsabilidad</th><th>Secciones</th></tr></thead>
      <tbody>{filas}</tbody>
    </table>
    <p class="aviso">
      Repositorio: {REPO}<br>
      Backlog: Jira HIA-Scrum-2026 · Tablero HS2<br>
      Fecha: {FECHA}
    </p>
  </div>
</section>
"""


def indice_html(indice: list[tuple[int, str, str]]) -> str:
    items = []
    for nivel, texto, ident in indice:
        clase = "n1" if nivel == 1 else "n2"
        items.append(f'<li class="{clase}"><a href="#{ident}">{texto}</a></li>')
    return f'<section class="toc"><h1>Índice</h1><ul>{"".join(items)}</ul></section>'


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--solo-html", action="store_true", help="no generar PDF")
    args = ap.parse_args()

    documentos = sorted(DOCS.glob("*.md"))
    if not documentos:
        print("no hay documentos en docs/informe/", file=sys.stderr)
        return 1

    usados: dict[str, int] = {}
    cuerpo: list[str] = []
    indice: list[tuple[int, str, str]] = []
    partes_md: list[str] = []

    for doc in documentos:
        html, idx = convertir(doc, usados)
        cuerpo.append(f'<section class="doc" data-fuente="{doc.name}">{html}</section>')
        indice.extend(idx)
        partes_md.append(doc.read_text(encoding="utf-8").strip())

    html = f"""<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<title>{TITULO} — {SUBTITULO}</title>
<style>{CSS}</style>
</head><body>
{portada()}
{indice_html(indice)}
{''.join(cuerpo)}
{MERMAID_SCRIPT}
</body></html>
"""
    SALIDA_HTML.write_text(html, encoding="utf-8")
    print(f"HTML: {SALIDA_HTML.relative_to(ROOT)} ({len(html) // 1024} KB, {len(documentos)} documentos)")

    SALIDA_MD.write_text(
        f"# {TITULO} — {SUBTITULO}\n\n"
        f"Repositorio: {REPO}  \nFecha: {FECHA}\n\n"
        "> Generado con `python scripts/informe.py`. No editar a mano.\n\n---\n\n"
        + "\n\n---\n\n".join(partes_md) + "\n",
        encoding="utf-8",
    )
    print(f"Markdown: {SALIDA_MD.relative_to(ROOT)}")

    if args.solo_html:
        return 0

    edge = next(
        (p for p in (
            pathlib.Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
            pathlib.Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"),
        ) if p.exists()),
        None,
    )
    if edge is None:
        edge = shutil.which("chrome") or shutil.which("google-chrome") or shutil.which("msedge")
    if not edge:
        print("No se encontró Edge/Chrome para imprimir el PDF", file=sys.stderr)
        return 2

    if SALIDA_PDF.exists():
        SALIDA_PDF.unlink()

    cmd = [
        str(edge),
        "--headless=new",
        "--disable-gpu",
        "--no-pdf-header-footer",
        "--virtual-time-budget=30000",
        f"--print-to-pdf={SALIDA_PDF}",
        SALIDA_HTML.as_uri(),
    ]
    subprocess.run(cmd, check=False, capture_output=True, timeout=180)

    if not SALIDA_PDF.exists():
        print("El PDF no se generó", file=sys.stderr)
        return 3

    datos = SALIDA_PDF.read_bytes()
    paginas = len(re.findall(rb"/Type\s*/Page[^s]", datos))
    print(f"PDF: {SALIDA_PDF.relative_to(ROOT)} "
          f"({len(datos) / 1024 / 1024:.1f} MB, {paginas} páginas)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
