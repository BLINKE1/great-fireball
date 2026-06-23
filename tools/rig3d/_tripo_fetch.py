"""Baixa um modelo do Tripo via API (contorna o gate de export da UI web).
Uso:  TRIPO_KEY=tsk_... python tools/rig3d/_tripo_fetch.py <img> <out.glb>
Faz: upload da imagem -> cria task image_to_model -> poll -> baixa GLB.
A KEY vem do ambiente (nao fica no arquivo).
"""
import os, sys, time, requests

KEY = os.environ.get("TRIPO_KEY", "").strip()
IMG = sys.argv[1] if len(sys.argv) > 1 else "docs/concept_art/soph_base_tpose.png"
OUT = sys.argv[2] if len(sys.argv) > 2 else "tools/rig3d/in/soph_mesh.glb"
BASE = "https://api.tripo3d.ai/v2/openapi"
H = {"Authorization": "Bearer " + KEY}
if not KEY:
    print("ERRO: defina TRIPO_KEY no ambiente"); sys.exit(2)

ext = os.path.splitext(IMG)[1].lstrip(".").lower() or "png"

print("[1/4] upload da imagem...")
with open(IMG, "rb") as f:
    r = requests.post(BASE + "/upload", headers=H,
                      files={"file": (os.path.basename(IMG), f, "image/" + ext)})
print("   ", r.status_code, r.text[:200])
r.raise_for_status()
tok = r.json()["data"]["image_token"]

print("[2/4] criando task image_to_model...")
body = {"type": "image_to_model",
        "file": {"type": ext, "file_token": tok},
        "texture": True, "pbr": True}
r = requests.post(BASE + "/task", headers={**H, "Content-Type": "application/json"}, json=body)
print("   ", r.status_code, r.text[:300])
r.raise_for_status()
tid = r.json()["data"]["task_id"]
print("    task_id:", tid)

print("[3/4] aguardando geracao...")
st = None
while True:
    r = requests.get(BASE + "/task/" + tid, headers=H)
    d = r.json()["data"]
    st, pr = d.get("status"), d.get("progress")
    print("    status:", st, pr)
    if st in ("success", "failed", "cancelled", "banned", "expired", "unknown"):
        break
    time.sleep(5)

if st != "success":
    print("FALHOU:", d); sys.exit(1)

out = d.get("output", {}) or {}
url = (out.get("pbr_model") or out.get("model")
       or out.get("base_model") or out.get("rendered_image"))
print("[4/4] baixando:", str(url)[:120])
mr = requests.get(url); mr.raise_for_status()
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "wb") as f:
    f.write(mr.content)
print("OK -> %s (%d bytes)" % (OUT, len(mr.content)))
