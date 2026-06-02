# 🌙 Night Shift — log de trabalho autônomo

> Sessão autônoma (Will dormindo). Direção dada: **master direto, ousado, prato
> cheio**. Prioridade: Combate/feel → bugs → conteúdo → polish. Tudo validado no
> Godot headless antes de commitar. Este log é pra você bater o olho de manhã.

## Regras que segui
- Cada mudança compila limpo no headless (`$GODOT`) antes do commit.
- Commits pequenos e temáticos, mensagem clara, direto no master.
- Nada destrutivo; mexidas reversíveis.
- Onde o "tato" final depende de você sentir, deixei constantes no topo dos
  arquivos e anotei aqui pra teu playtest.

## Linha do tempo

### 1. Juice de combate unificado em TODOS os inimigos
**Problema:** só o goblin tinha o tratamento "delicioso" (faísca direcional de
impacto, squash elástico ao apanhar, screenshake proporcional, hitstop escalado
ao golpe, som de hit com pitch variado). Archer, leader, ogre, golem e a versão
de fogo apanhavam "seco" — só flash branco + knockback.

**Fix:** criei `VFX.enemy_impact(...)` — um helper reutilizável que centraliza o
tato de impacto. Agora bater em QUALQUER inimigo tem o mesmo nível de feedback
do goblin. Cada inimigo mantém sua identidade (knockback, flash, morte, HP).
- Hitstop escalado (golpe letal congela mais).
- Faísca de impacto direcional + estalo branco.
- Squash elástico ao apanhar (robusto a hits repetidos e a sprites com escala
  != 1 via `rest_scale` em meta).
- Screenshake proporcional ao dano.
- Som de hit com pitch aleatório (some a repetição monótona).
- Goblin refatorado pra usar o mesmo helper (uma fonte de verdade, feel idêntico).

_(continua…)_
