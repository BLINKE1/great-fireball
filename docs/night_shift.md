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

### 2. Fim do feedback dobrado ao acertar inimigo
Armas (cajado + mísseis) tocavam `hit` + hitstop/shake por conta própria, e como
o `enemy.take_damage` agora também faz tudo isso, cada acerto disparava **som de
hit dobrado, hitstop dobrado e shake dobrado**. Limpei a divisão: a **arma** fica
só com sua explosão visual (burst/ring na cor da magia); o **inimigo** é dono da
reação de impacto. (`missile_giant` mantido — explosão AoE deliberada.)

### 3. Jitter automático de pitch nos SFX repetitivos
A maioria das chamadas tocava em pitch fixo → repetição monótona ao bater/andar/
atirar em sequência. O `AudioManager.play()` agora aplica jitter sutil de pitch
(curado por som) quando o chamador usou pitch padrão; sons musicais/dramáticos
ficam de fora. Quebra a monotonia sem tocar em dezenas de call sites.

### 4. Goblin com ataque TELEGRAFADO (combate legível e justo)
Antes o goblin dava dano por toque instantâneo, sem aviso — "barato" e
inesquivável. Agora ele **arma o golpe**: brilho quente + recua o "braço"
(anticipation) por ~0,3s, então desfere um **lunge** pra frente. O dano **só
acontece se o player ainda estiver perto** (dá pra esquivar no windup), e
**levar dano cancela o golpe** (recompensa trocar na hora certa).
- Validado em `tools/goblin_attack_probe.gd`: entra em windup, golpe acerta,
  e hit cancela — tudo sem crash.
- 🎚️ **Pro teu playtest:** `ATTACK_WINDUP` (0.30), `ATTACK_LUNGE` (160),
  `STRIKE_RANGE` (46) no topo de `goblin.gd`. Windup curto = agressivo; longo =
  mais fácil de ler. Só apliquei no goblin básico (inimigo central do slice).

### 5. Golpe de cajado com peso (Q)
O ataque de cajado era "chapado" (só spawnava o slash). Agora tem compromisso
físico: **passo/lunge pra frente** no chão (`SWORD_LUNGE`) + **squash horizontal**
no corpo. A Soph avança no golpe — bater fica mais gostoso. Constante de tato no
topo de `player.gd`.

### 6. Números de dano com cor por magnitude + deriva
- Cor escala com o dano: branco-azulado (leve) → amarelo (padrão) → laranja
  (crit ≥45) → vermelho-laranja (pesado ≥70); fonte maior por tier.
- Deriva horizontal aleatória: números empilhados se espalham (legibilidade ao
  acertar rápido).
- Pop maior pros crits.

### 📸 Prova visual
`tools/combat_capture.gd` (determinístico) gera dois closes em
`tools/art_director/iterations/godot_shots/`:
- `juice_windup.png` — goblin telegrafando (brilho quente + "!").
- `juice_impact.png` — faísca direcional + anel branco + número "20" + flash
  vermelho + barra de HP danificada. Tudo num quadro.

### 7. Telegraph estendido a TODOS os inimigos
- **goblin_leader** (durão, melee): mesmo windup/lunge do goblin, janela 0.36s.
- **goblin_archer** e **fire_goblin_archer** (ranged): "puxam o arco" (~0.45s)
  com brilho quente (laranja flamejante no de fogo) antes de soltar a flecha;
  levar dano cancela a mira.
- Resultado: **combate inteiro legível e justo** — todo ataque tem aviso e dá
  pra esquivar/interromper. Constantes de tato no topo de cada inimigo.

### 9. Ferramentas de validação (rede de segurança)
- `tools/goblin_attack_probe.gd` (parametrizável por cena `-- <path>`):
  windup/strike/cancel — valida goblin e leader.
- `tools/archer_attack_probe.gd` (parametrizável): draw/release/cancel — valida
  os dois archers.
- `tools/scene_smoke.gd`: instancia 18 cenas de gameplay e pega erros de `_ready`
  (nó faltando, path errado, null). **18/18 OK.**
- Use esses + `combat_probe`/`mana_probe` como regressão antes de mexer no combate.

## Como testar de manhã
1. `git pull` no master.
2. Test room (`soph_test_room.tscn`, F6): bate nos goblins (Q cajado / Z míssil),
   spawna mais com **G**. Sente o juice + o windup deles (brilho antes de bater —
   dá pra esquivar/interromper batendo).
3. Se algum "tato" estiver off, os números estão em constantes no topo dos
   arquivos (`goblin.gd`: ATTACK_WINDUP/LUNGE/STRIKE_RANGE; `player.gd`:
   SWORD_LUNGE). Fácil de afinar.

_(continua…)_
