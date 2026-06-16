# Fluxo de desenho IA — "óculos 2.0" + ControlNet local (plano)

> Anotado a pedido do Will (2026-06-16). Captura o método validado de "eu
> desenho → a IA pinta" e o plano pra travar pose 3/4 via ControlNet local.

## O que já funciona (validado no pollen)

**"Óculos 2.0" — eu desenho a estrutura, a IA pinta por cima.**

1. Eu autoro a **estrutura** da Soph em **SVG** (`tools/art_director/soph_svg.py`):
   Bézier + gradientes + blur + lineart = cel-shading determinístico (zero drift).
   - `build_svg()` = frontal; `build_svg_34()` = 3/4.
2. Renderizo a estrutura num **fundo verde** (cairosvg).
3. Mando como imagem de entrada do **img2img** do Pollinations
   (`/v1/images/edits`, modelo `gptimage`) com prompt de repintura — a difusão
   **pinta por cima seguindo minha pose/composição/identidade**.
4. **Pós-processo** automático: chroma key verde → erode 1px → normaliza pro
   canvas do jogo = sprite pronto.
   - Tudo em `tools/art_director/gen_repaint_from_svg.py`
     (`--pose 34 --eyes open|closed --token sk_...`).

**Por que verde:** chroma key por cor pega os bolsões entre as mechas (o
flood-fill em fundo creme deixava slivers brancos + halo). Cabelo "maçudo" =
massa sólida na estrutura + prompt "volumoso sem vãos".

### Limite conhecido do img2img (o motivo do ControlNet)
O `gptimage`/img2img **regulariza a pose**: uma estrutura 3/4 *suave* ele
**endireita pra frontal**. Também reenquadra (cortou os pés até darmos
head/footroom). Ou seja: img2img segue *aproximadamente* o traço, não trava.
- **Frontal:** o img2img respeita bem → usável já.
- **3/4 / poses de ação:** precisa de pose **travada** → ControlNet.

## O plano: ControlNet LOCAL via túnel (trava a pose, de graça)

Contexto: o Claude roda num contêiner na nuvem (independente do aparelho do
Will). Ele só alcança o que a política de rede permite. O PC do Will pode rodar
GPU pesada que o contêiner não roda.

**Arquitetura:**
1. Will sobe **Stable Diffusion + ControlNet** local no PC
   (**ComfyUI** ou **Automatic1111**) — grátis, usa a GPU dele.
   - Modelos: um checkpoint anime (SDXL/Pony/Illustrious) + ControlNet
     **lineart**/**openpose**/**depth** + opcional **IP-Adapter** (trava
     identidade a partir da `soph_anchor_v2.png`).
2. Expõe o servidor por um **túnel** → URL pública:
   - `cloudflared tunnel --url http://localhost:8188` (ComfyUI), ou `ngrok http 8188`.
3. Will passa a **URL do túnel** pro Claude.
4. Claude **chama o endpoint daqui**: manda o **lineart SVG** (estrutura, ex.
   3/4) como controle + prompt + âncora → o ControlNet **trava a pose** e a
   difusão pinta **obedecendo**. Itera com o "óculos" (gera → vê → ajusta).

**Resultado:** 3/4 (e poses de ação) com pose travada, identidade travada
(IP-Adapter), pintura bonita — **grátis, na GPU do Will**, sem o "endireitar"
do img2img.

### Condições / riscos honestos
- Precisa de **GPU decente** (NVIDIA ~6GB+ VRAM p/ SDXL+ControlNet).
- Claude só alcança o túnel **se a política de rede do contêiner permitir**
  chamar a URL externa (pip e Pollinations funcionam → provável; testar).
- Setup do ComfyUI + modelos + túnel tem trabalho inicial (Claude guia passo a
  passo).
- Túnel expõe o servidor publicamente enquanto aberto → usar URL com cuidado,
  fechar depois.

### Fallback (sem GPU / sem túnel)
Seguir no **pollen img2img**: frontal trava bem; deixar 3/4 e ação pro caminho
local quando der. O `gen_repaint_from_svg.py` já entrega frontal usável.

## Mapa dos arquivos
- `tools/art_director/soph_svg.py` — meu "lápis" (SVG cel, frontal + 3/4).
- `tools/art_director/gen_repaint_from_svg.py` — estrutura → repaint → sprite.
- `tools/art_director/gen_hd_sheet.py` — sheets HD via Pollinations + slicer.
- `docs/concept_art/soph_anchor_v2.png` — master anchor (identidade).
- `docs/animacao_hk_notas.md` — método HK + ferramentas de ancoragem.
