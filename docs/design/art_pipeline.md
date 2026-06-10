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

## Primeiros ganhos sugeridos (ordem)
1. Adicionar um **engine de GERAÇÃO** (Gemini imagem) ao `art_director` ao lado dos
   de crítica → loop "rascunho → imagem boa → eu critico → refina".
2. Pipeline **imagem→sprite procedural** (skill "referência→sprite"), com **andar
   fluido** (mais quadros + easing) — melhoria direta no jogo.
3. **Teaser** com ffmpeg quando houver clipes.
4. Vídeo de unhas: roteiro de prompts + montagem.
