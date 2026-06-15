#!/usr/bin/env python3
"""
gen_hd_from_idle.py — Regera os frames HD da Soph usando o idle como ANCORA
via Pollinations kontext (img2img). Mesmo personagem, mesmo enquadramento,
muda só a pose conforme o prompt de cada anim.

Pre-req:
  - POLLINATIONS_TOKEN no env (ou --token sk_...)
  - Idle anchor publica em ANCHOR_URL (repo precisa ser publico).

Uso:
  python tools/art_director/gen_hd_from_idle.py --one walk_0          # teste de 1 frame
  python tools/art_director/gen_hd_from_idle.py --anim walk           # 1 anim completa
  python tools/art_director/gen_hd_from_idle.py --all                 # tudo (17 frames)
  python tools/art_director/gen_hd_from_idle.py --dry                 # mostra prompts so

Saidas:
  - --one/--anim: assets/sprites/player/_preview/<key>.png (nao sobrescreve)
  - --all/--apply: assets/sprites/player/<key>.png (sobrescreve oficial)
"""
from __future__ import annotations
import argparse, io, os, sys, time, urllib.parse, urllib.request
from pathlib import Path
from PIL import Image, ImageFilter

HERE   = Path(__file__).parent
ASSETS = HERE.parent.parent / "assets" / "sprites" / "player"

# Master anchor v2 (2026-06-15): 3/4, robe FECHADA, chapeu integro, maos vazias,
# fundo transparente. Eleita via gen_hd_sheet --set anchor. Substitui o ref antigo
# (que segurava o cajado e tinha a robe aberta). Resolve apos merge no master.
ANCHOR_URL = "https://raw.githubusercontent.com/BLINKE1/great-fireball/master/docs/concept_art/soph_anchor_v2.png"
ENDPOINT   = "https://gen.pollinations.ai/image/"
MODEL      = "kontext"
W, H            = 540, 1024   # ratio ~100x192 (Pollinations ignora pra kontext)
CANVAS_W        = 100         # canvas final pro jogo
CANVAS_H        = 192
TARGET_CHAR_H   = 180         # altura do personagem dentro do canvas (presenca AAA)
WHITE_THRESHOLD = 240         # pixels >= isso em todos canais viram alpha 0
BASE_SEED  = 7

# Descricao curta do personagem (reforca em todo prompt p/ a kontext nao
# "perder" o design). Repeticao agressiva da exigencia de fundo branco
# liso (pra remover via threshold/rembg depois) e side-view facing right
# (pra unificar a orientacao de toda a anim).
CHAR = (
    "same anime mage girl character (pointed red wizard hat, long blue "
    "hair, round black-framed glasses, red robe with dark inner lining, "
    "brown boots, blue glowing crystal staff). FULL BODY SIDE VIEW PROFILE, "
    "facing right, full character visible head to feet, isolated character "
    "on PURE WHITE BACKGROUND, flat solid white background, no scenery, "
    "no shadow, no gradient, sprite cutout style, game asset"
)

# Cada entrada: (anim_base, frame_idx, prompt_da_pose, seed)
JOBS = [
    # IDLE 2 frames — respiro sutil (mesma pose, leve variacao)
    ("idle", 0, "idle standing pose, relaxed stance, staff held in left hand at side, slight smile, facing right, eyes open looking forward, breathing in slightly", 1),
    ("idle", 1, "idle standing pose, relaxed stance, staff held in left hand at side, slight smile, facing right, eyes open looking forward, breathing out slightly", 2),
    # WALK cycle 6 frames — mid-stride poses, side view facing right
    ("walk", 0, "walking right, contact pose, right foot striking ground forward, left foot back, staff in left hand at side", 100),
    ("walk", 1, "walking right, passing pose, right leg straight under body, left leg lifting behind, staff in left hand at side", 101),
    ("walk", 2, "walking right, high point pose, left foot lifted highest behind, right leg straight, staff in left hand at side", 102),
    ("walk", 3, "walking right, contact pose, left foot striking ground forward, right foot back, staff in left hand at side", 103),
    ("walk", 4, "walking right, passing pose, left leg straight under body, right leg lifting behind, staff in left hand at side", 104),
    ("walk", 5, "walking right, high point pose, right foot lifted highest behind, left leg straight, staff in left hand at side", 105),
    # RUN cycle 4 frames — wider stride, staff swung back, hair flowing
    ("run", 0, "running right, full sprint, right foot extended forward, hair streaming behind, staff held back in left hand", 200),
    ("run", 1, "running right, mid-air passing, both feet off ground briefly, hair streaming", 201),
    ("run", 2, "running right, left foot extended forward, hair streaming behind", 202),
    ("run", 3, "running right, mid-air passing opposite, both feet off ground", 203),
    # AIR
    ("jump", 0, "jumping up to the right, legs tucked, robe billowing, staff in left hand, upward motion", 300),
    ("fall", 0, "falling down to the right, legs extended, robe blown up by wind, staff in left hand", 400),
    ("hurt", 0, "hit reaction, body recoiling back to the left, head tilted, staff in left hand, pained expression", 500),
    # ATTACKS
    ("cast", 0, "casting spell, both hands raising staff overhead, crystal orb glowing brighter, magical light around her, facing right", 600),
    ("cast", 1, "casting spell, staff aimed forward and right, crystal orb beaming bright magic, body braced forward", 601),
    ("slash", 0, "slash attack windup, staff drawn back over right shoulder, body coiled for swing, facing right", 700),
    ("slash", 1, "slash attack release, staff swung forward-down to the right, motion blur, body extended", 701),
]


def build_url(prompt: str, seed: int) -> str:
    full = f"{CHAR}. Pose: {prompt}."
    enc = urllib.parse.quote(full, safe="")
    params = urllib.parse.urlencode({
        "model":  MODEL,
        "image":  ANCHOR_URL,
        "width":  W,
        "height": H,
        "seed":   seed,
        "nologo": "true",
        "private": "true",
    })
    return f"{ENDPOINT}{enc}?{params}"


def whiten_to_alpha(im: Image.Image) -> Image.Image:
    """RGB com fundo branco -> RGBA com fundo transparente (threshold simples)."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    t = WHITE_THRESHOLD
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r >= t and g >= t and b >= t:
                px[x, y] = (r, g, b, 0)
    return im


def normalize_to_canvas(im: Image.Image) -> Image.Image:
    """Crop no conteudo opaco, escala p/ TARGET_CHAR_H, centra horizontal,
    cola com pes na base do canvas CANVAS_W x CANVAS_H."""
    bbox = im.getbbox()
    if not bbox:
        return im.resize((CANVAS_W, CANVAS_H), Image.LANCZOS)
    cropped = im.crop(bbox)
    cw, ch = cropped.size
    scale = TARGET_CHAR_H / ch
    new_w = max(1, int(round(cw * scale)))
    new_h = TARGET_CHAR_H
    resized = cropped.resize((new_w, new_h), Image.LANCZOS)
    out = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    # centraliza horizontal, alinha pes ao fundo do canvas
    x = (CANVAS_W - new_w) // 2
    y = CANVAS_H - new_h
    # se a largura escalada estourar o canvas, reduz proporcionalmente
    if new_w > CANVAS_W:
        scale2 = CANVAS_W / new_w
        nw2 = CANVAS_W
        nh2 = max(1, int(round(new_h * scale2)))
        resized = resized.resize((nw2, nh2), Image.LANCZOS)
        x = 0
        y = CANVAS_H - nh2
    out.paste(resized, (x, y), resized)
    return out


def postprocess(raw: bytes) -> Image.Image:
    """Pipeline: bytes Pollinations -> sprite 100x192 RGBA pronto pro jogo."""
    im = Image.open(io.BytesIO(raw))
    im = whiten_to_alpha(im)
    return normalize_to_canvas(im)


def fetch(url: str, token: str, retries: int = 2) -> bytes:
    for attempt in range(retries + 1):
        req = urllib.request.Request(url, headers={
            "User-Agent": "great-fireball-art-director",
            "Authorization": f"Bearer {token}",
        })
        try:
            with urllib.request.urlopen(req, timeout=240) as r:
                ct = r.headers.get("Content-Type", "")
                data = r.read()
            if "image" not in ct:
                head = data[:160]
                raise RuntimeError(f"resposta nao-imagem ({ct}): {head!r}")
            return data
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "ignore")[:200]
            print(f"  HTTP {e.code} (tentativa {attempt+1}): {body}")
            if e.code in (401, 402, 403):
                raise RuntimeError(f"auth: {e.code}: {body}")
            if attempt < retries:
                time.sleep(3.0 * (attempt + 1))
                continue
            raise
        except Exception as e:
            print(f"  erro {type(e).__name__} (tentativa {attempt+1}): {e}")
            if attempt < retries:
                time.sleep(3.0 * (attempt + 1))
                continue
            raise


def gen_one(anim: str, idx: int, prompt: str, seed: int, token: str,
            preview: bool, skip_existing: bool = True) -> Path:
    key = f"soph_hd_{anim}_{idx}"
    if preview:
        out_dir = ASSETS / "_preview"
    else:
        # --apply: vai pra STAGING (_pending_regen/) ate todos os 19 estarem
        # prontos. So depois um --apply-final copia tudo pro lugar oficial.
        out_dir = ASSETS / "_pending_regen"
    out_dir.mkdir(exist_ok=True)
    out = out_dir / f"{key}.png"
    if skip_existing and out.exists() and out.stat().st_size > 1000:
        print(f"-> {key}  SKIP (ja existe em {out_dir.name}/)")
        return out
    url = build_url(prompt, seed)
    print(f"-> {key}  seed={seed}")
    print(f"   {url[:120]}...")
    data = fetch(url, token)
    raw_dir = out_dir / "_raw"
    raw_dir.mkdir(exist_ok=True)
    (raw_dir / f"{key}.png").write_bytes(data)
    sprite = postprocess(data)
    sprite.save(out)
    print(f"   ok {out}  raw={len(data)}b  sprite={sprite.size}")
    return out


def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--one",  help="ex.: walk_0")
    g.add_argument("--anim", help="ex.: walk, run, cast")
    g.add_argument("--all",  action="store_true")
    g.add_argument("--dry",  action="store_true")
    ap.add_argument("--token", help="POLLINATIONS_TOKEN (ou usa env)")
    ap.add_argument("--apply", action="store_true",
                    help="grava em _pending_regen/ (staging); default = _preview/")
    ap.add_argument("--apply-final", action="store_true",
                    help="copia _pending_regen/soph_hd_*.png p/ assets oficiais")
    ap.add_argument("--no-skip", action="store_true",
                    help="re-gera mesmo se ja existir em _pending_regen/")
    return ap.parse_args()


def apply_final() -> int:
    """Copia _pending_regen/soph_hd_*.png p/ assets oficiais."""
    src = ASSETS / "_pending_regen"
    if not src.exists():
        print(f"x staging nao existe: {src}"); return 1
    pending = sorted(src.glob("soph_hd_*.png"))
    if not pending:
        print("x staging vazio"); return 1
    missing = []
    for anim, idx, _, _ in JOBS:
        if not (src / f"soph_hd_{anim}_{idx}.png").exists():
            missing.append(f"{anim}_{idx}")
    if missing:
        print(f"x faltam frames: {', '.join(missing)}")
        print(f"  rode --all --apply de novo p/ completar")
        return 1
    print(f"-> aplicando {len(pending)} frames staged p/ assets oficiais")
    for f in pending:
        dst = ASSETS / f.name
        dst.write_bytes(f.read_bytes())
        print(f"   ok {dst.name}")
    return 0


def main() -> int:
    args = parse_args()
    if args.apply_final:
        return apply_final()
    token = args.token or os.environ.get("POLLINATIONS_TOKEN", "")
    if not args.dry and not token:
        print("x defina POLLINATIONS_TOKEN ou passe --token")
        return 1

    if args.dry:
        for anim, idx, prompt, seed in JOBS:
            print(f"{anim}_{idx}  seed={seed}")
            print(f"  CHAR: {CHAR}")
            print(f"  POSE: {prompt}")
        return 0

    if args.one:
        target = args.one
        for anim, idx, prompt, seed in JOBS:
            if f"{anim}_{idx}" == target:
                gen_one(anim, idx, prompt, seed, token, preview=not args.apply, skip_existing=not args.no_skip)
                return 0
        print(f"x frame nao encontrado: {target}")
        return 1

    if args.anim:
        targets = [j for j in JOBS if j[0] == args.anim]
        if not targets:
            print(f"x anim nao encontrada: {args.anim}")
            return 1
        for anim, idx, prompt, seed in targets:
            gen_one(anim, idx, prompt, seed, token, preview=not args.apply, skip_existing=not args.no_skip)
            time.sleep(1.0)
        return 0

    if args.all:
        for anim, idx, prompt, seed in JOBS:
            gen_one(anim, idx, prompt, seed, token, preview=not args.apply, skip_existing=not args.no_skip)
            time.sleep(1.0)
        return 0

    return 1


if __name__ == "__main__":
    sys.exit(main())
