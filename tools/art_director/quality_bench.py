#!/usr/bin/env python3
"""
quality_bench.py — "esta em nivel comercial?"

Mede assets do Great Fireball contra uma REGUA de excelencia inspirada nos
principios que fazem arte tier-HK funcionar (NAO usa nenhum asset de terceiro
— so principios + medidas objetivas). Roda a cada teste, da nota e pega
regressao.

Camadas:
  1. Metricas objetivas (este arquivo): paleta, contraste, silhueta, borda,
     legibilidade-no-pequeno. Numeros reproduziveis, sem API.
  2. Crentica visual do Claude (na sessao): olha o screenshot real e pontua
     contra o RUBRIC abaixo.
  3. Scorecard versionado: iterations/quality_scorecard.json (curva + regressao).

Uso:
    python quality_bench.py assets/sprites/player/soph_hd_idle_0.png
    python quality_bench.py --all-hd          # todos os soph_hd_*
    python quality_bench.py <png> --save       # grava no scorecard
"""
from __future__ import annotations
import sys, json, argparse, math, warnings
from pathlib import Path
from PIL import Image, ImageFilter, ImageChops

warnings.filterwarnings("ignore", category=DeprecationWarning)  # getdata (Pillow 14)

HERE = Path(__file__).parent
SCORECARD = HERE / "iterations" / "quality_scorecard.json"

# ── A REGUA (rubric) — principios de arte comercial tier-HK ──────────────────
# Cada criterio: peso + o que medir. A nota objetiva cobre o que da pra medir;
# a crentica visual do Claude cobre o resto (arco de animacao, apelo, emocao).
RUBRIC = {
    "silhueta":      "Le como forma unica e reconhecivel? (teste do recorte preto)",
    "legibilidade":  "Continua legivel reduzido a 48-64px? (o truque do HK)",
    "paleta":        "Coesa e intencional, sem cores soltas/banding?",
    "contraste":     "Figura destaca do fundo; pontos focais guiam o olho?",
    "borda":         "Bordas limpas (anti-alias), sem serrilhado nem halo?",
    "leitura_facial":"Rosto/olhos lem a intencao a distancia de jogo?",
}


def _load(path):
    im = Image.open(path).convert("RGBA")
    return im


def m_palette(im):
    """Nº de cores perceptualmente distintas (quantizado). HK-tier: rico mas
    coeso — nem raso demais (chapado) nem ruidoso (banding/sujeira)."""
    rgb = im.convert("RGB").quantize(colors=64, method=Image.FASTOCTREE)
    used = len([c for c in rgb.getcolors(64*64) if c[0] > 8])  # cores com area real
    return used


def m_silhouette_legibility(im, small=56):
    """Quanto a silhueta sobrevive ao ser reduzida (teste do pequeno). Mede a
    razao de area opaca preservada + a 'limpeza' da borda no tamanho pequeno."""
    a = im.split()[3]
    big_area = sum(1 for p in a.getdata() if p > 40)
    sm = im.resize((small, small), Image.LANCZOS).split()[3]
    sm_area = sum(1 for p in sm.getdata() if p > 40)
    # fragmentacao: borda muito recortada perde area ao reduzir
    ratio = (sm_area / (small*small)) / max(1e-6, big_area/(im.width*im.height))
    return round(min(1.0, ratio), 3)


def m_edge_quality(im):
    """Suavidade de borda: fracao de pixels de borda com alpha intermediario
    (anti-alias real) vs. borda 'dura' serrilhada. Maior = mais suave/limpo."""
    a = im.split()[3]
    edges = a.filter(ImageFilter.FIND_EDGES)
    vals = [p for p in edges.getdata() if p > 10]
    if not vals:
        return 0.0
    soft = sum(1 for v in vals if 20 < v < 235)  # transicao gradual
    return round(soft / len(vals), 3)


def m_contrast(im):
    """Contraste da figura: desvio de luminancia DENTRO da silhueta. Arte chapada
    tem desvio baixo; arte com volume/foco tem desvio saudavel."""
    rgb = im.convert("RGB"); a = im.split()[3]
    lum = []
    for (r, g, b), al in zip(rgb.getdata(), a.getdata()):
        if al > 60:
            lum.append(0.299*r + 0.587*g + 0.114*b)
    if not lum:
        return 0.0
    mean = sum(lum)/len(lum)
    var = sum((x-mean)**2 for x in lum)/len(lum)
    return round(math.sqrt(var)/128.0, 3)  # ~0..2, normalizado


def analyze(path):
    im = _load(path)
    metrics = {
        "size": f"{im.width}x{im.height}",
        "palette_colors": m_palette(im),
        "silhouette_legibility": m_silhouette_legibility(im),
        "edge_quality": m_edge_quality(im),
        "contrast": m_contrast(im),
    }
    # Heuristica de nota objetiva (0-10) — sinaliza, nao e veredito final.
    # Faixas calibradas p/ arte de personagem suave (estilo dream).
    s = 0.0
    s += 2.0 if 14 <= metrics["palette_colors"] <= 48 else 1.0
    s += 3.0 * metrics["silhouette_legibility"]            # legibilidade pesa
    s += 2.5 * metrics["edge_quality"]
    s += min(2.5, metrics["contrast"] * 3.0)
    metrics["objective_score"] = round(min(10.0, s), 1)
    return metrics


def save_scorecard(path, metrics, visual_score=None, notes=""):
    SCORECARD.parent.mkdir(parents=True, exist_ok=True)
    data = {"entries": []}
    if SCORECARD.exists():
        data = json.loads(SCORECARD.read_text())
    import datetime
    entry = {
        "asset": str(Path(path).name),
        "ts": datetime.datetime.now().isoformat(timespec="seconds"),
        "metrics": metrics,
        "visual_score": visual_score,   # preenchido pelo Claude na sessao
        "notes": notes,
    }
    # regressao: compara com ultima nota objetiva do mesmo asset
    prev = [e for e in data["entries"] if e["asset"] == entry["asset"]]
    if prev:
        delta = metrics["objective_score"] - prev[-1]["metrics"]["objective_score"]
        entry["delta_vs_prev"] = round(delta, 1)
    data["entries"].append(entry)
    SCORECARD.write_text(json.dumps(data, indent=2, ensure_ascii=False))
    return entry.get("delta_vs_prev")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--all-hd", action="store_true")
    ap.add_argument("--save", action="store_true")
    args = ap.parse_args()

    paths = list(args.paths)
    if args.all_hd:
        d = HERE.parent.parent / "assets" / "sprites" / "player"
        paths += sorted(str(p) for p in d.glob("soph_hd_*.png"))
    if not paths:
        print("uso: quality_bench.py <png> [--save] | --all-hd")
        return

    print("REGUA (criterios):")
    for k, v in RUBRIC.items():
        print(f"  • {k}: {v}")
    print()
    print(f"{'asset':<28} {'pal':>4} {'leg':>5} {'borda':>6} {'contr':>6} {'NOTA':>5}")
    print("─" * 60)
    for p in paths:
        m = analyze(p)
        print(f"{Path(p).name:<28} {m['palette_colors']:>4} "
              f"{m['silhouette_legibility']:>5} {m['edge_quality']:>6} "
              f"{m['contrast']:>6} {m['objective_score']:>5}")
        if args.save:
            delta = save_scorecard(p, m)
            if delta is not None:
                print(f"    Δ vs anterior: {delta:+.1f}")


if __name__ == "__main__":
    main()
