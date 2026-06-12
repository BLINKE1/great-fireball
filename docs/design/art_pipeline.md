# Pipeline de Arte — do rascunho ao anime (desejos do Will)

> Objetivo do Will: trazer a SUA visão de desenho pra dentro do jogo. Ele rascunha
> (acima da média da população, mas abaixo de um desenhista pro) e quer que esses
> rascunhos virem **assets do jogo** e **anime** (cutscenes hoje; talvez um anime
> de verdade no futuro).

## Os 6 desejos (fonte da verdade)
1. **Rascunho → imagem estática boa** (limpar/elevar o desenho mantendo a visão dele).
2. **Imagem boa → assets do jogo** (sprites; a maga andando com **andar fluido perfeito**).
3. **Imagem boa → storyboard** (quadros de cena).
4. **Storyboard → anime** (animação de verdade).
5. **Tudo → game teaser** (montagem).
6. **IA → vídeo concept de unhas** pra irmã (TikTok).

## O "óculos" que já temos
`tools/art_director/art_director.py` — loop de feedback visual ("Óculos do Claude"):
gera sprite procedural → motor com visão critica (Gemini free / Claude / Ollama via
`engines.py`) → reescreve o código → `quality_bench.py` dá nota. Hoje é **olho+crítica**
de arte procedural. `.env` tem `GEMINI_API_KEY` (gitignored).

## Mapa de viabilidade (jun/2026)
| Etapa | Como fazer | Posso aqui? | Precisa |
|------|-----------|-------------|---------|
| 1. Rascunho→imagem | Gemini "Nano Banana" (img2img/edição) ou Flux; eu escrevo o prompt e **critico/itero** (visão) | Parcial | egress de rede p/ a API + chave (já temos Gemini) |
| 2. Imagem→sprite | **Procedural** (nosso forte, nativo) OU img→pixel + limpeza; andar fluido = mais frames + curvas de easing | **Sim** (procedural) | — |
| 3. Imagem→storyboard | Gemini/Flux gera quadros a partir de descrições; eu monto a sequência/decupagem | Parcial | API de imagem |
| 4. Storyboard→anime | Motor de **vídeo** (ex.: Veo/Kling/Runway/Sora-like) img2video; ou animação 2D por código/Godot | Não local | API de vídeo (paga) |
| 5. Teaser | Montagem com ffmpeg (temos ffmpeg aqui) a partir dos clipes/sprites | **Sim** | os clipes prontos |
| 6. Vídeo de unhas (irmã) | Gemini imagem + motor de vídeo img2video | Parcial | API de imagem/vídeo |

## Realidade técnica (honesta)
- **Eu não gero raster/anime sozinho** (sou modelo de linguagem). Sou ótimo como
  **diretor**: escrevo prompts, **enxergo e critico** o resultado, itero, e faço
  **pós-produção por código** (PIL/ffmpeg/Godot).
- **Geração nativa sem API:** procedural (sprites), SVG/vetor, canvas — funciona já.
- **Geração realista/anime/vídeo:** precisa de **motor externo** (imagem: Gemini
  Nano Banana free / Flux; vídeo: pago). Já temos chave Gemini; falta confirmar
  **egress de rede** neste ambiente.

## Soph HD definitiva — fluxo da base (status)
- **Referência base** em `docs/concept_art/soph_base_ref.png` (a "naked"):
  leotard preto sem mangas/pernas, descalça, sem acessórios. Rosto guiado
  pelas fotos da musa (irmã do Will) + espírito Little Witch Academia:
  rosto redondo, olhos castanho-escuros, franja reta, sorriso gentil.
- **Cabelo = pool de mana** (ver CLAUDE.md): preto na raiz com degradê
  **azul-mana nas pontas** — a base retrata ~meia mana, o visual
  "cabelo pintado" da musa. Gasto raiz→pontas, regen pontas→raiz
  (a pixel-art atual faz o inverso; inverter ao regenerar estados).
- **Receita de geração** (reproduzível): `flux` 640x1280 **seed 7** — a seed
  fixa preserva o rosto entre variações de roupa/cabelo. Chroma verde +
  recorte tratando verde-dominante fechado e mantendo o maior componente
  conexo (mata assinaturas fantasma e buracos entre ondas do cabelo).
- **Vestida (canônica)**: `docs/concept_art/soph_dressed_ref.png` (3/4 olhando
  pra direita, posição de jogador) + `soph_dressed_front.png` (frontal, útil
  pra retratos). Robe e chapéu de maga VERMELHOS (homenagem Chariot/LWA),
  botas marrons de cano alto, óculos redondos, sem cajado por ora.
- **img2img que funciona**: `POST gen.pollinations.ai/v1/images/edits`
  (multipart: image=@arquivo, prompt, model=kontext, seed). O kontext
  preserva a personagem; pedir o giro de vista num SEGUNDO passe (de uma
  vez só ele quase não gira). Resposta JSON: data[0].b64_json.
- **Próximos passos**: idle definitivo a partir da vestida → conjunto
  completo (walk/run/jump/fall/hurt/cast) → estados de mana do cabelo HD
  (recoloração procedural por máscara, raiz→pontas).

## Motor de imagem do óculos (status)
- ✅ **FUNCIONANDO (testado 2026-06-12).** **Pollinations.ai** (modelo Flux) via
  a **API nova `gen.pollinations.ai`**:
  `tools/art_director/gen_pollinations.py "<prompt>" <saida> [w] [h] [seed] [model]`.
- **Requer** chave gratuita `sk_...` de <https://enter.pollinations.ai>,
  exportada como **`POLLINATIONS_TOKEN`** (env var do ambiente no
  claude.ai/code), e o host **`gen.pollinations.ai`** na allowlist de rede.
- ⚠️ Config de ambiente (rede e env vars) é **fixada no início da sessão** —
  depois de mudar, **iniciar sessão NOVA**.
- ⚠️ O host antigo `image.pollinations.ai` virou **legacy**: em cloud (IP de
  saída compartilhado) responde **402 "Queue full for IP"** sempre, mesmo com
  chave — não usar.
- Modelos disponíveis na API nova: `flux`, `zimage`, `gptimage`, `kontext`,
  `seedream5`.
- Alternativa paga: Gemini com billing (`tools/art_director/gen_image.py`).

1. Adicionar um **engine de GERAÇÃO** (Gemini imagem) ao `art_director` ao lado dos
   de crítica → loop "rascunho → imagem boa → eu critico → refina".
2. Pipeline **imagem→sprite procedural** (skill "referência→sprite"), com **andar
   fluido** (mais quadros + easing) — melhoria direta no jogo.
3. **Teaser** com ffmpeg quando houver clipes.
4. Vídeo de unhas: roteiro de prompts + montagem.
