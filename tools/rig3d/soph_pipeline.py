#!/usr/bin/env python3
"""Orquestrador API-first: concept art -> 3D rigado/animado -> entrega pro render.

Automatiza o pedaço manual do pipeline Soph3D (hoje feito na mao no Hunyuan
Studio + Mixamo) usando uma API de image-to-3D (Tripo por padrao). Fluxo:

    multiview PNGs -> [mesh+textura] -> [rig] -> [anim preset] -> baixa GLB
                    -> imprime o comando do render 3/4 que JA' existe no repo

Filosofia (ver INSTRUCOES_PC.md): NAO e' "gera tudo sozinho e confia". Entre
cada etapa generativa ele salva um PREVIEW e PARA pra voce aprovar ("e' a Soph
em 3/4, consistente?"). --yes pula os portoes (por sua conta e risco).

Uso:
    export TRIPO_API_KEY=...            # sua chave (nunca commitar)
    python tools/rig3d/soph_pipeline.py --stages mesh,rig,anim
    python tools/rig3d/soph_pipeline.py --dry-run --yes   # testa a logica, sem rede
    python tools/rig3d/soph_pipeline.py --resume          # continua de onde parou

Notas:
 - Endpoints/campos da Tripo ficam em PROVIDERS["tripo"]; se a API mudar, ajuste
   ali (confira em https://platform.tripo3d.ai / docs). O --dry-run nao toca a
   rede, entao valida o fluxo mesmo se os campos precisarem de ajuste fino.
 - Estado salvo em out/pipeline/state.json -> resumivel.
 - Nada de chave hardcoded: so' via env TRIPO_API_KEY.
"""
from __future__ import annotations
import argparse
import json
import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MV_DIR = ROOT / "docs/concept_art/multiview"
OUT_DIR = ROOT / "tools/rig3d/out/pipeline"   # previews + estado (gitignored)
GLB_DIR = OUT_DIR / "glb"                      # GLBs gerados (gitignored, SEGURO)
STATE = OUT_DIR / "state.json"
# IMPORTANTE: o pipeline NUNCA escreve em tools/rig3d/in/ (assets reais do repo).
# Os GLBs gerados vao pra GLB_DIR (dentro de out/, gitignored). Depois de aprovar,
# voce copia o que quiser pra in/ na mao.

# Vistas multiview -> ordem que a Tripo espera: [front, left, back, right].
# Voce tem front/side/back; "side" entra como left, right fica vazio.
VIEWS = {
    "front": MV_DIR / "soph_mv_front.png",
    "left":  MV_DIR / "soph_mv_side.png",
    "back":  MV_DIR / "soph_mv_back.png",
    # "right": (sem asset; ok deixar de fora)
}

# Presets de animacao a gerar (nomes de preset da Tripo; locomocao = o que riga
# limpo no biped, ver INSTRUCOES_PC.md).
ANIM_PRESETS = ["idle", "walk", "run"]

PROVIDERS = {
    "tripo": {
        "base": "https://api.tripo3d.ai/v2/openapi",
        "upload": "/upload",            # multipart 'file' -> data.image_token
        "task": "/task",               # POST cria; GET /task/{id} consulta
        "auth_env": "TRIPO_API_KEY",
        "poll_secs": 5.0,
        "timeout_secs": 900.0,
    },
}


# ─────────────────────────────── util ────────────────────────────────────────
def log(msg: str) -> None:
    print(f"[soph3d] {msg}", flush=True)


def load_state() -> dict:
    if STATE.exists():
        return json.loads(STATE.read_text())
    return {"stages": {}}


def save_state(st: dict) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(st, indent=2))


def approve(stage: str, preview: Path | None, auto: bool) -> bool:
    if preview is not None and preview.exists():
        log(f"preview de '{stage}': {preview}")
    if auto:
        log(f"[--yes] aprovando '{stage}' automaticamente")
        return True
    ans = input(f"  >> '{stage}' ok? Olhe o preview. Seguir? [s/N] ").strip().lower()
    return ans in ("s", "sim", "y", "yes")


# ─────────────────────────── cliente (real) ─────────────────────────────────
class Tripo:
    def __init__(self, cfg: dict):
        import requests  # so' importa quando for de verdade
        self._requests = requests
        self.cfg = cfg
        key = os.environ.get(cfg["auth_env"], "")
        if not key:
            sys.exit(f"ERRO: defina {cfg['auth_env']} (sua chave da Tripo).")
        self.h = {"Authorization": f"Bearer {key}"}

    def upload(self, path: Path) -> str:
        url = self.cfg["base"] + self.cfg["upload"]
        with open(path, "rb") as f:
            r = self._requests.post(url, headers=self.h, files={"file": (path.name, f)})
        r.raise_for_status()
        data = r.json().get("data", {})
        tok = data.get("image_token") or data.get("file_token")
        if not tok:
            raise RuntimeError(f"upload sem token: {r.text[:200]}")
        return tok

    def create(self, payload: dict) -> str:
        url = self.cfg["base"] + self.cfg["task"]
        r = self._requests.post(url, headers=self.h, json=payload)
        r.raise_for_status()
        tid = r.json().get("data", {}).get("task_id")
        if not tid:
            raise RuntimeError(f"task sem id: {r.text[:200]}")
        return tid

    def poll(self, task_id: str) -> dict:
        url = f"{self.cfg['base']}{self.cfg['task']}/{task_id}"
        t0 = time.time()
        while True:
            r = self._requests.get(url, headers=self.h)
            r.raise_for_status()
            d = r.json().get("data", {})
            status = d.get("status", "?")
            prog = d.get("progress", 0)
            log(f"  task {task_id[:8]}… {status} {prog}%")
            if status in ("success", "completed"):
                return d
            if status in ("failed", "cancelled", "banned", "expired", "error"):
                raise RuntimeError(f"task {task_id} {status}: {d}")
            if time.time() - t0 > self.cfg["timeout_secs"]:
                raise TimeoutError(f"task {task_id} passou de {self.cfg['timeout_secs']}s")
            time.sleep(self.cfg["poll_secs"])

    def download(self, url: str, dest: Path) -> None:
        dest.parent.mkdir(parents=True, exist_ok=True)
        r = self._requests.get(url, headers=self.h, stream=True)
        r.raise_for_status()
        with open(dest, "wb") as f:
            for chunk in r.iter_content(8192):
                f.write(chunk)


# ─────────────────────────── cliente (mock) ─────────────────────────────────
class MockTripo:
    """Simula a Tripo sem tocar a rede — valida o fluxo/portoes/estado/handoff."""
    def __init__(self, cfg: dict):
        self.cfg = cfg
        self._n = 0

    def upload(self, path: Path) -> str:
        log(f"  (mock) upload {path.name}")
        return f"MOCK_TOK_{path.stem}"

    def create(self, payload: dict) -> str:
        self._n += 1
        tid = f"MOCK_TASK_{payload.get('type','?')}_{self._n}"
        log(f"  (mock) create {payload.get('type')} -> {tid}")
        return tid

    def poll(self, task_id: str) -> dict:
        log(f"  (mock) task {task_id} success 100%")
        return {"status": "success", "output": {
            "model": f"mock://{task_id}.glb",
            "rendered_image": f"mock://{task_id}.png"}}

    def download(self, url: str, dest: Path) -> None:
        dest.parent.mkdir(parents=True, exist_ok=True)
        # gera um placeholder pra o handoff/preview existir de verdade no disco
        if dest.suffix == ".png":
            _placeholder_png(dest, url)
        else:
            dest.write_bytes(b"MOCK GLB placeholder for " + url.encode())
        log(f"  (mock) baixou {url} -> {dest.name}")


def _placeholder_png(dest: Path, label: str) -> None:
    try:
        from PIL import Image, ImageDraw
        im = Image.new("RGB", (256, 320), (28, 40, 46))
        d = ImageDraw.Draw(im)
        d.rectangle([20, 20, 236, 300], outline=(120, 200, 160), width=3)
        d.text((30, 150), "MOCK\n" + label[-24:], fill=(200, 230, 210))
        im.save(dest)
    except Exception:
        dest.write_bytes(b"mock png")


# ─────────────────────────────── etapas ─────────────────────────────────────
def stage_mesh(cli, st: dict, auto: bool) -> bool:
    log("ETAPA 1/3 — MESH multiview (geometria + textura)")
    # A Tripo espera 'files' como ARRAY em ORDEM [front, left, back, right]
    # (posicao = vista; sem chave "view"). VIEWS ja' esta' nessa ordem; right
    # ausente -> array mais curto (a "side" da Soph entra como left).
    files = []
    for view, path in VIEWS.items():
        if not path.exists():
            sys.exit(f"ERRO: falta a vista {view}: {path}")
        files.append({"type": "png", "file_token": cli.upload(path)})
    task = cli.create({"type": "multiview_to_model", "files": files,
                       "texture": True, "pbr": True})
    out = cli.poll(task)
    prev = OUT_DIR / "01_mesh_preview.png"
    if out["output"].get("rendered_image"):
        cli.download(out["output"]["rendered_image"], prev)
    glb = GLB_DIR / "soph_dressed_mesh.glb"
    cli.download(out["output"]["model"], glb)
    st["stages"]["mesh"] = {"task_id": task, "glb": str(glb)}
    save_state(st)
    return approve("mesh", prev, auto)


def stage_rig(cli, st: dict, auto: bool) -> bool:
    log("ETAPA 2/3 — RIG (auto-rig do esqueleto)")
    mesh = st["stages"].get("mesh")
    if not mesh:
        sys.exit("ERRO: rode a etapa 'mesh' antes (ou --resume).")
    task = cli.create({"type": "animate_rig",
                       "original_model_task_id": mesh["task_id"], "out_format": "glb"})
    out = cli.poll(task)
    prev = OUT_DIR / "02_rig_preview.png"
    if out["output"].get("rendered_image"):
        cli.download(out["output"]["rendered_image"], prev)
    glb = GLB_DIR / "soph_rigged.glb"
    cli.download(out["output"]["model"], glb)
    st["stages"]["rig"] = {"task_id": task, "glb": str(glb)}
    save_state(st)
    return approve("rig", prev, auto)


def stage_anim(cli, st: dict, auto: bool) -> bool:
    log(f"ETAPA 3/3 — ANIM (presets: {', '.join(ANIM_PRESETS)})")
    rig = st["stages"].get("rig")
    if not rig:
        sys.exit("ERRO: rode a etapa 'rig' antes (ou --resume).")
    anims = {}
    for preset in ANIM_PRESETS:
        log(f"  animando '{preset}'…")
        task = cli.create({"type": "animate_retarget",
                           "original_model_task_id": rig["task_id"],
                           "animation": f"preset:{preset}", "out_format": "glb"})
        out = cli.poll(task)
        glb = GLB_DIR / f"soph_{preset}.glb"
        cli.download(out["output"]["model"], glb)
        anims[preset] = str(glb)
    st["stages"]["anim"] = {"glbs": anims}
    save_state(st)
    prev = OUT_DIR / "01_mesh_preview.png"  # reusa o preview do mesh p/ aprovar
    return approve("anim", prev if prev.exists() else None, auto)


STAGE_FUNCS = {"mesh": stage_mesh, "rig": stage_rig, "anim": stage_anim}


def handoff(st: dict) -> None:
    log("── PRONTO. Proximo passo = RENDER 3/4 (ja' existe no repo):")
    anims = st["stages"].get("anim", {}).get("glbs", {})
    for preset, glb in anims.items():
        rel = os.path.relpath(glb, ROOT)
        print(f"  # {preset}")
        print(f"  blender --background --python tools/rig3d/render_soph_3q.py -- \\")
        print(f"      --fbx {rel} --out tools/rig3d/out/{preset} --res 512x768 \\")
        print(f"      --az 35 --el 12 --outline 0.02 --toon")
        print(f"  python tools/rig3d/pack_sheet.py --in tools/rig3d/out/{preset} --cols 8")
    if not anims:
        print("  (rode a etapa 'anim' pra gerar os GLBs animados)")


def main() -> None:
    ap = argparse.ArgumentParser(description="Orquestrador Soph3D (concept art -> 3D).")
    ap.add_argument("--provider", default="tripo", choices=list(PROVIDERS))
    ap.add_argument("--stages", default="mesh,rig,anim",
                    help="quais etapas rodar (ex.: mesh  |  rig,anim)")
    ap.add_argument("--resume", action="store_true", help="continua do state.json")
    ap.add_argument("--yes", action="store_true", help="pula os portoes de aprovacao")
    ap.add_argument("--dry-run", action="store_true", help="mock, sem rede")
    args = ap.parse_args()

    cfg = PROVIDERS[args.provider]
    cli = MockTripo(cfg) if args.dry_run else Tripo(cfg)
    st = load_state() if args.resume else {"stages": {}}
    if args.resume:
        log(f"retomando: etapas ja' feitas = {list(st['stages'])}")

    stages = [s.strip() for s in args.stages.split(",") if s.strip()]
    for s in stages:
        if s not in STAGE_FUNCS:
            sys.exit(f"etapa desconhecida: {s} (use mesh,rig,anim)")
        ok = STAGE_FUNCS[s](cli, st, args.yes)
        if not ok:
            log(f"parado em '{s}' (nao aprovado). Ajuste e rode --resume.")
            return
    handoff(st)
    log("fim ✓")


if __name__ == "__main__":
    main()
