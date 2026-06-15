#!/usr/bin/env python3
"""
gen_action_keyframes.py — gera key frames estratégicos pra cada ação (run, jump, fall, attack, cast, hurt).

Usa os 10 walk frames já prontos + 1-2 frames por ação = animação boa.
Depois monta em Godot AnimationPlayer pra conectar suave.

Uso:
    python tools/art_director/gen_action_keyframes.py [--token sk_...]
"""
from __future__ import annotations
import os, sys, urllib.parse, urllib.request, json, base64
from pathlib import Path

BASE_IMG2IMG = "https://gen.pollinations.ai/v1/images/edits"

# walk frames já estão prontos em continuous_anim/anim_walk_*.png

KEYFRAMES = [
    # run: pegar frame 6 de walk como base e iterar
    ("run", 0, "anim_walk_06.png", "Soph maga running right, energetic fast pace, leaning forward, legs extended"),
    ("run", 1, "anim_walk_10.png", "Soph maga running fast right, dynamic motion, arms pumping"),

    # jump: começar de walk idle
    ("jump", 0, "anim_walk_05.png", "Soph maga jumping right, ascending into air, legs bent for power"),
    ("jump", 1, "anim_walk_05.png", "Soph maga at peak of jump, floating in air, right arm raised"),
    ("jump", 2, "anim_walk_05.png", "Soph maga falling from jump, descending, about to land"),

    # fall: queda mais longa
    ("fall", 0, "anim_walk_05.png", "Soph maga falling down through air, body vertical, surprised"),
    ("fall", 1, "anim_walk_05.png", "Soph maga crashing to ground, impact, lying down"),

    # attack com espada
    ("attack", 0, "anim_walk_05.png", "Soph maga drawing red sword, ready stance, sword raised"),
    ("attack", 1, "anim_walk_05.png", "Soph maga mid-sword swing, blade slashing downward"),
    ("attack", 2, "anim_walk_05.png", "Soph maga sword finishing swing, returning to ready"),

    # cast mágico
    ("cast", 0, "anim_walk_05.png", "Soph maga casting spell, arms raised, blue mana energy forming around her"),
    ("cast", 1, "anim_walk_05.png", "Soph maga releasing magical projectile, spell complete"),

    # hurt: levando dano
    ("hurt", 0, "anim_walk_05.png", "Soph maga hit by attack, reacting to damage, knocked back"),
    ("hurt", 1, "anim_walk_05.png", "Soph maga recovering from hit, getting up, back to ready"),
]

def img2img_edit(input_image_path: str, prompt: str, out_path: str,
                 token: str, model: str = "gptimage") -> int:
    """Edit uma imagem via POST /v1/images/edits (multipart form)."""
    token = token or os.environ.get("POLLINATIONS_TOKEN")
    if not token:
        print("✗ falta a chave")
        return 1

    try:
        with open(input_image_path, "rb") as f:
            image_data = f.read()
    except Exception as e:
        print(f"✗ erro ao ler: {e}")
        return 1

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
                        print(f"  ✓ {out_path}")
                        return 0
            except json.JSONDecodeError:
                pass

            if resp_data[:4] == b'\x89PNG':
                Path(out_path).write_bytes(resp_data)
                print(f"  ✓ {out_path} (raw)")
                return 0

            print(f"✗ resposta inválida")
            return 1
    except urllib.error.HTTPError as e:
        body_err = e.read().decode("utf-8", "ignore")[:300]
        if "safety" in body_err.lower():
            print(f"✗ safety system: prompt pode ser muito sugestivo")
        else:
            print(f"✗ HTTP {e.code}")
        return 1
    except Exception as e:
        print(f"✗ rede: {type(e).__name__}")
        return 1

def main() -> int:
    args = sys.argv[1:]
    token = None
    if "--token" in args:
        i = args.index("--token")
        token = args[i + 1]
        del args[i:i + 2]

    token = token or os.environ.get("POLLINATIONS_TOKEN")

    out_dir = Path("tools/art_director/iterations/continuous_anim")
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"gerando key frames de ações...")
    print()

    for action, frame_num, base_img, prompt in KEYFRAMES:
        base_path = out_dir / base_img
        if not base_path.exists():
            print(f"✗ base não encontrada: {base_img}")
            continue

        out_file = out_dir / f"anim_{action}_{frame_num:02d}.png"

        print(f"[{action} {frame_num:02d}] {prompt[:60]}...")
        ret = img2img_edit(str(base_path), prompt, str(out_file), token)

        if ret != 0:
            print(f"  pulando esta ação.")
            continue

    print()
    print(f"✓ key frames prontos em {out_dir}/")
    return 0

if __name__ == "__main__":
    sys.exit(main())
