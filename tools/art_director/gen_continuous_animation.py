#!/usr/bin/env python3
"""
gen_continuous_animation.py — gera frames de ação da Soph HD via img2img.

Sequência: walk (10) → run (8) → jump (8) → fall (6) → attack (8) →
cast (8) → dano (6). ~54 frames. Usa gptimage (~0.009 pollen/frame).

⚠️ DRIFT: o modo encadeado (cada frame parte do anterior) acumula erro —
estilo/identidade/cor derivam (vide iterations/continuous_anim/, frames 1→11
viram outro personagem). Por isso o DEFAULT ancora todo frame na idle MASTER
(identidade travada, resolução cheia por pose). Use --chain p/ o modo morph.

Uso:
    python tools/art_director/gen_continuous_animation.py [--token sk_...] [--chain]
"""
from __future__ import annotations
import os, sys, urllib.parse, urllib.request, json, base64
from pathlib import Path

BASE_IMG2IMG = "https://gen.pollinations.ai/v1/images/edits"

SEQUENCE = [
    # walk: 10 frames (corpo relaxado, passo fluido, esquerda pra direita)
    ("walk", 1, "Soph maga walking left to right, casual relaxed stride, full body, anime style, frame 1/10"),
    ("walk", 2, "Soph maga walking right, left leg forward, smooth gait, frame 2/10"),
    ("walk", 3, "Soph maga walking right, fluid motion, frame 3/10"),
    ("walk", 4, "Soph maga walking right, right leg forward, frame 4/10"),
    ("walk", 5, "Soph maga walking right, continuing smooth stride, frame 5/10"),
    ("walk", 6, "Soph maga walking right, left leg forward again, frame 6/10"),
    ("walk", 7, "Soph maga walking right, fluid motion, frame 7/10"),
    ("walk", 8, "Soph maga walking right, right leg forward, frame 8/10"),
    ("walk", 9, "Soph maga walking right, smooth stride, frame 9/10"),
    ("walk", 10, "Soph maga walking right, left leg forward, frame 10/10, slowing"),

    # run: 8 frames (energetic, mais rápido, postura ativa)
    ("run", 1, "Soph maga running right, energetic pace, body leaning forward, frame 1/8"),
    ("run", 2, "Soph maga running right, left leg extended, quick motion, frame 2/8"),
    ("run", 3, "Soph maga running right, dynamic stride, frame 3/8"),
    ("run", 4, "Soph maga running right, right leg extended, rapid motion, frame 4/8"),
    ("run", 5, "Soph maga running right, energetic movement, frame 5/8"),
    ("run", 6, "Soph maga running right, left leg forward, speed frame 6/8"),
    ("run", 7, "Soph maga running right, right leg extended, frame 7/8"),
    ("run", 8, "Soph maga running right, finishing sprint, slowing frame 8/8"),

    # jump: 8 frames (subindo, no ar, caindo)
    ("jump", 1, "Soph maga jumping right, legs bending to jump, preparing, frame 1/8"),
    ("jump", 2, "Soph maga jumping right, leaving ground, ascending, frame 2/8"),
    ("jump", 3, "Soph maga jumping right, mid-air, rising, frame 3/8"),
    ("jump", 4, "Soph maga jumping right, peak of jump, frame 4/8"),
    ("jump", 5, "Soph maga jumping right, starting to descend, frame 5/8"),
    ("jump", 6, "Soph maga jumping right, falling, frame 6/8"),
    ("jump", 7, "Soph maga jumping right, about to land, frame 7/8"),
    ("jump", 8, "Soph maga jumping right, landing, legs bent, frame 8/8"),

    # fall: 6 frames (caindo, assustada, batendo)
    ("fall", 1, "Soph maga falling, body vertical, surprised expression, frame 1/6"),
    ("fall", 2, "Soph maga falling down, arms out, trying to balance, frame 2/6"),
    ("fall", 3, "Soph maga falling, body tilted, frame 3/6"),
    ("fall", 4, "Soph maga falling fast, arms flailing slightly, frame 4/6"),
    ("fall", 5, "Soph maga falling, about to hit ground, frame 5/6"),
    ("fall", 6, "Soph maga hit ground, lying down, impact, frame 6/6"),

    # attack com espada: 8 frames (sacando, cortando, voltando)
    ("attack", 1, "Soph maga drawing red sword, ready stance, frame 1/8"),
    ("attack", 2, "Soph maga sword swing starting, raising blade, frame 2/8"),
    ("attack", 3, "Soph maga sword swing upward, frame 3/8"),
    ("attack", 4, "Soph maga sword swing downward, blade mid-swing, frame 4/8"),
    ("attack", 5, "Soph maga sword slash finishing, frame 5/8"),
    ("attack", 6, "Soph maga sword returning to ready, frame 6/8"),
    ("attack", 7, "Soph maga sword in hand, ready stance, frame 7/8"),
    ("attack", 8, "Soph maga sheathing sword, returning to neutral, frame 8/8"),

    # cast mágico: 8 frames (invocando, mana saindo, magia disparando)
    ("cast", 1, "Soph maga casting spell, arms raised, mana gathering, frame 1/8"),
    ("cast", 2, "Soph maga casting, blue mana energy forming, frame 2/8"),
    ("cast", 3, "Soph maga casting, spell circle forming, frame 3/8"),
    ("cast", 4, "Soph maga casting, powerful magic building, frame 4/8"),
    ("cast", 5, "Soph maga releasing spell, magic projectile launching, frame 5/8"),
    ("cast", 6, "Soph maga spell released, magical energy dissipating, frame 6/8"),
    ("cast", 7, "Soph maga after cast, arms lowering, frame 7/8"),
    ("cast", 8, "Soph maga spell finished, returning to neutral stance, frame 8/8"),

    # dano: 6 frames (levando hit, recuando, recuperando)
    ("hurt", 1, "Soph maga hit, reacting to damage, frame 1/6"),
    ("hurt", 2, "Soph maga knocked back, pain expression, frame 2/6"),
    ("hurt", 3, "Soph maga flying backward from hit, frame 3/6"),
    ("hurt", 4, "Soph maga landing from knockback, frame 4/6"),
    ("hurt", 5, "Soph maga getting up, recovering, frame 5/6"),
    ("hurt", 6, "Soph maga standing again, recovering stance, frame 6/6"),
]

def img2img_edit(input_image_path: str, prompt: str, out_path: str,
                 token: str, model: str = "gptimage") -> int:
    """Edit uma imagem via POST /v1/images/edits (multipart form)."""
    token = token or os.environ.get("POLLINATIONS_TOKEN")
    if not token:
        print("✗ falta a chave: defina POLLINATIONS_TOKEN")
        return 1

    try:
        with open(input_image_path, "rb") as f:
            image_data = f.read()
    except Exception as e:
        print(f"✗ erro ao ler imagem: {e}")
        return 1

    # Montar form multipart manualmente
    boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"

    body = b''
    body += f'--{boundary}\r\n'.encode()
    body += f'Content-Disposition: form-data; name="prompt"\r\n\r\n'.encode()
    body += f'{prompt}\r\n'.encode()

    body += f'--{boundary}\r\n'.encode()
    body += f'Content-Disposition: form-data; name="image"; filename="input.png"\r\n'.encode()
    body += f'Content-Type: image/png\r\n\r\n'.encode()
    body += image_data
    body += b'\r\n'

    body += f'--{boundary}\r\n'.encode()
    body += f'Content-Disposition: form-data; name="model"\r\n\r\n'.encode()
    body += f'{model}\r\n'.encode()

    body += f'--{boundary}\r\n'.encode()
    body += f'Content-Disposition: form-data; name="seed"\r\n\r\n'.encode()
    body += b'7\r\n'

    body += f'--{boundary}--\r\n'.encode()

    req = urllib.request.Request(
        BASE_IMG2IMG,
        data=body,
        headers={
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Authorization": f"Bearer {token}",
            "User-Agent": "great-fireball-anim-gen",
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            resp_data = r.read()
            try:
                resp_json = json.loads(resp_data.decode())
                if "data" in resp_json and len(resp_json["data"]) > 0:
                    b64_img = resp_json["data"][0].get("b64_json")
                    if b64_img:
                        img_bytes = base64.b64decode(b64_img)
                        Path(out_path).write_bytes(img_bytes)
                        print(f"  → {out_path}")
                        return 0
            except json.JSONDecodeError:
                pass

            # Fallback: try to save raw response if it's PNG
            if resp_data[:4] == b'\x89PNG':
                Path(out_path).write_bytes(resp_data)
                print(f"  → {out_path} (raw PNG)")
                return 0

            print(f"✗ resposta inválida: {resp_data[:200]}")
            return 1
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "ignore")[:300]
        print(f"✗ HTTP {e.code}: {body}")
        if e.code in (401, 402):
            print("  → Chave inválida ou saldo insuficiente em pollen.")
        return 1
    except Exception as e:
        print(f"✗ rede: {type(e).__name__}: {e}")
        return 1

def main() -> int:
    args = sys.argv[1:]
    token = None
    if "--token" in args:
        i = args.index("--token")
        token = args[i + 1]
        del args[i:i + 2]

    # --chain: modo antigo (ancora no frame anterior -> DRIFT acumulado).
    # Default: ancora SEMPRE na idle master -> identidade travada, resolucao
    # cheia por pose. A continuidade do ciclo e' do sistema de animacao.
    chain = "--chain" in args
    if chain:
        args.remove("--chain")

    token = token or os.environ.get("POLLINATIONS_TOKEN")

    base_image = Path("assets/sprites/player/soph_hd_idle_0.png")
    if not base_image.exists():
        print(f"✗ imagem base não encontrada: {base_image}")
        return 1

    out_dir = Path("tools/art_director/iterations/continuous_anim")
    out_dir.mkdir(parents=True, exist_ok=True)

    mode = "chain (DRIFT)" if chain else "anchor-master (identidade travada)"
    print(f"gerando animação contínua em {out_dir}/ ...")
    print(f"base: {base_image}")
    print(f"model: gptimage (~0.009 pollen/frame) | modo: {mode}")
    print()

    current_frame = base_image

    for action, frame_num, prompt in SEQUENCE:
        out_file = out_dir / f"anim_{action}_{frame_num:02d}.png"

        print(f"[{action} {frame_num:02d}] {prompt[:60]}...")
        ret = img2img_edit(str(current_frame), prompt, str(out_file), token)

        if ret != 0:
            print(f"✗ falhou na sequência. parando.")
            return 1

        # anchor-master: proximo frame parte SEMPRE da idle (sem drift).
        # chain: parte do frame recem-gerado (efeito morph, acumula erro).
        current_frame = out_file if chain else base_image

    print()
    print(f"✓ sequência concluída! {len(SEQUENCE)} frames em {out_dir}/")
    print(f"  Para fracionar em GIF: ffmpeg -i 'anim_%*.png' -vf fps=12 anim.gif")
    return 0

if __name__ == "__main__":
    sys.exit(main())
