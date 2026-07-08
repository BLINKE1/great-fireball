#!/usr/bin/env python3
"""find_loop.py — acha (ou descarta) um ponto de loop natural numa sequencia de
frames renderizados, por autocorrelacao de imagem (em vez de escolher a janela
"no olho", que foi como a costura antiga de walk/run saiu ruim).

Renderiza primeiro uma amostragem FINA cobrindo a anim inteira:
  "$GODOT" --path . -s tools/rig3d/render_player_sheet.gd -- <which> <n> 0.0 1.0

Depois roda este script apontando pra pasta de saida. Ele testa todo periodo L
(em unidades de amostra) no range [lmin,lmax], mede a distancia de imagem
media entre frame[i] e frame[i+L] pra todas as fases i, e reporta os melhores
L + fases. Compara sempre com a distancia media entre frames CONSECUTIVOS
(passo nativo) -- se o melhor seam achado for pior que o pior passo
consecutivo, a fonte NAO tem loop natural (e' o caso do walking.fbx do
Mixamo: nenhum L/fase fecha, confirmado ate' L=n-1 = clipe inteiro) e a saida
e' fechar por crossfade 2D (finalize_frames.py), nao insistir na busca.

Uso:
  python tools/rig3d/find_loop.py tools/rig3d/out/player_sheet/run 6 60
"""
import sys
import glob, os, re
import numpy as np
from PIL import Image


def load_seq(d):
    files = sorted(glob.glob(os.path.join(d, "f*.png")),
                    key=lambda p: int(re.findall(r"\d+", os.path.basename(p))[0]))
    if not files:
        raise SystemExit(f"nenhum frame em {d}")
    return [np.asarray(Image.open(f).convert("RGBA"), dtype=np.float32) for f in files]


def dist(a, b):
    aa = a[:, :, 3:4] / 255.0
    ba = b[:, :, 3:4] / 255.0
    w = np.maximum(aa, ba)
    wsum = w.sum()
    if wsum < 1.0:
        return 0.0
    d = ((a[:, :, :3] - b[:, :, :3]) ** 2).sum(axis=2, keepdims=True) * w
    return float(d.sum() / (wsum * 3.0)) ** 0.5


def main():
    d = sys.argv[1]
    lmin = int(sys.argv[2])
    lmax = int(sys.argv[3])
    arrs = load_seq(d)
    n = len(arrs)
    print(f"loaded {n} frames from {d}")

    D = np.zeros((n, n))
    for i in range(n):
        for j in range(i, n):
            v = dist(arrs[i], arrs[j])
            D[i, j] = v
            D[j, i] = v

    scores = []
    for L in range(lmin, min(lmax, n - 1) + 1):
        seams = [D[i, i + L] for i in range(n - L)]
        scores.append((float(np.median(seams)), L))
    scores.sort()
    print("Top 8 candidate periods (median seam dist, L samples):")
    for s, L in scores[:8]:
        print(f"  L={L:3d}  median_seam={s:7.2f}")

    best_L = scores[0][1]
    seams = [(D[i, i + best_L], i) for i in range(n - best_L)]
    seams.sort()
    print(f"\nBest L={best_L} -- top 5 phases (seam_dist, i0, i0+L):")
    for sd, i0 in seams[:5]:
        print(f"  i0={i0:3d}  i1={i0+best_L:3d}  seam_dist={sd:7.2f}  t0={i0/n:.4f}  t1={(i0+best_L)/n:.4f}")

    consec = [D[i, i + 1] for i in range(n - 1)]
    print(f"\nreference: avg consecutive-frame dist (native sampling) = {np.mean(consec):.2f}, max={np.max(consec):.2f}")
    print("(se o melhor seam acima for >= o max consecutivo, nao ha loop natural -- usa finalize_frames.py com crossfade)")


if __name__ == "__main__":
    main()
