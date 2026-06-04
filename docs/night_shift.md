# 🌙 Night Shift — dinamismo AAA da Soph + repassada geral

> Sessão autônoma (Will dormindo). Pedido: repassar tudo e melhorar o melhorável,
> com **foco no dinamismo AAA da movimentação da Soph pixel**. Tudo no master,
> validado headless.

## Foco: dinamismo da movimentação (AAA)
A Soph é um manto-sino fechado (HK), então o dinamismo vem do cabelo, da barra
da capa, das botas e do corpo. Trabalhei em duas frentes:

**(A) Runtime (em `_update_visuals`, em cima da animação de frames):**
- **Lean (skew)** na direção do movimento — corpo/cabelo se inclinam pra frente
  ao andar/correr (mais forte no dash). Pés plantados (skew, não rotação).
- **Stretch por velocidade** — estica horizontal correndo; estica vertical no ar
  (sobe/cai rápido) → squash & stretch clássico.
- **Pop elástico** ao trocar de direção no chão.
- **Idle vivo** — sway de skew bem sutil quando parada (respiração).
- **Poeira** no impulso do pulo de solo.

**(B) Frames (no gerador `gen_all_frames`):**
- **Secondary motion amplificado** no walk/run — o cabelo chicoteia e a capa
  balança com mais energia (sway/hem_sway/bob maiores).
- **Corrida de 6 frames** (era 4) a 16fps → corrida visivelmente mais fluida.

## Repassada geral / regressão
- Boot do jogo sem erro; `scene_smoke` 19/19; `combat_probe` ✓; `boss_probe` ✓.
- Nada quebrou com as mudanças.

## Provas
- `tools/move_demo.gif` — idle → corrida (com lean) → pulo (com poeira).
- Capturas in-engine da pose de corrida inclinada.

## Em aberto / ideias pra depois
- Mais frames no walk (6→8) e um hurt de 2 frames (recoil) — diminishing returns.
- Skid/derrapada ao frear em alta velocidade (precisa de frame dedicado).
- Direção do nível ("corre pra esquerda") segue como está (dungeon é p/ direita).
