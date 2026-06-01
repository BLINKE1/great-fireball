# Vertical Slice — A Demo da Bola de Fogo

> 🎯 O alvo: uma fatia **jogável do início até a Grande Bola de Fogo**, em
> qualidade **comercial (AAA-indie)**, pronta pra página da Steam (wishlist,
> trailer, despertar interesse). É a primeira pedra do monumento — e a que vai
> financiar as próximas.

## A experiência do jogador (visão do Will)

1. Inicia o jogo e **testa as mecânicas iniciais** (movimento gostoso, magias).
2. **Luta contra goblins** de um jeito que seja **uma delícia** bater neles.
3. Enfrenta o **Goblin Mutante (boss)** — dificuldade **deliciosa** de early
   game (nem fácil demais, nem impossível).
4. No limite, vê a **Grande Bola de Fogo gigante** salvar a Soph. Fim da demo.
   _(É só o início da história grandiosa.)_

## O que já existe (não construímos do zero — lapidamos)

- **Cap. 1 inteiro já implementado** (11 cenas `🎬 FILMADA`, ver Grimório).
- **Inimigos:** goblin, archer, leader, versões de fogo, `forest_ogre`, golem.
- **Kit de magia:** míssil (+4 variantes), dash, escudo, parar tempo, cura,
  duplo salto, **golpe de cajado** (`sword`/Q — a "arma secundária" já existe).
- **Game feel de movimento:** 10/10 no `feel_bench` (pulo variável, gravidade
  assimétrica, apex hang, coyote, buffer, hitstop, shake, squash).
- **SkillManager** com `unlock()`/`reset()` — dá e tira habilidades fácil.

## Frentes de trabalho

### A. Combate "delicioso" contra goblins  🎮
O game feel de *movimento* está 10/10; falta levar o mesmo nível ao *combate*.
- Feedback de impacto: flash de dano, knockback com peso, **hitstop escalado**
  ao golpe, congelamento curtinho no acerto.
- Morte satisfatória do goblin: squash, "poof", partículas, som com punch.
- Screen shake proporcional. Áudio de impacto encorpado.
- **Bench novo:** estender medição pra "combat feel" (a definir).

### B. Goblin Mutante (Boss)  🎨⚔️
- **Arte:** Will rascunha (inspiração MTG); refinamos com o motor de arte +
  `quality_bench`. _(Pode evoluir o `forest_ogre` ou ser criatura nova.)_
- **Luta:** ataques telegrafados, padrão justo, talvez 2 fases.
- **Dificuldade "deliciosa":** o *flow channel* — desafio que recompensa o
  aprendizado. Fácil demais = sem interesse; impossível = desistência.

### C. Economia de mana  🔵 (pedido específico do Will)
- **Problema atual:** orbe cai de *todo* goblin + auto-atração + regen passivo
  → mana nunca acaba (sem tensão de recurso).
- **Direção:** tornar a mana um **recurso com peso** e uma decisão. _(Modelo a
  decidir junto — ver pergunta aberta.)_
- Liga com a **arma secundária**: sem mana → parte pro cajado.

### D. Kit inicial (habilidades emprestadas)  🧰
Pro slice, a Soph começa "turbinada" (depois o jogo principal vai **tirar** e
reensinar). Tudo via `SkillManager.unlock()`:
- **Air Hike** (`double_jump`) — emprestado; recolhido no jogo principal.
- **Dash** (`magic_dash`).
- **Parry** — NOVO (nasce do "corte preciso" do vídeo). A criar.
- **Auto-cura** (`heal`) — consome mana.
- **Parar o tempo** (`time_stop`) — consome mana.
- **Míssil Mágico** (`magic_missile`) + **Golpe de Cajado** (`sword`).

### E. Curva de dificuldade  📈
Goblins sobem em intensidade até o pico (o boss). Instrumentar com playtest.

### F. Clímax da Bola de Fogo  🔥
`anime_fireball` já existe — polir ao nível AAA (timing, impacto, som).

## Definição de "pronto" (a demo está boa quando…)

- [ ] Joga do boot até a Bola de Fogo sem travas nem bugs.
- [ ] Bater nos goblins é **visceralmente gostoso**.
- [ ] O Goblin Mutante dá uma luta **justa e memorável**.
- [ ] Mana é um **recurso que importa** (decisões reais).
- [ ] Soph tem um **kit inicial curado** e legível.
- [ ] As cenas do Cap. 1 estão **polidas** ao nível de vitrine.

## Sequenciamento sugerido (maior alavanca primeiro)

1. **Economia de mana + loop com o cajado** (código/tuning, não depende de arte).
2. **Combate delicioso nos goblins** (juice — medível).
3. **Kit inicial** (rápido, via SkillManager) + **Parry** (novo).
4. **Boss Mutante** (em paralelo, assim que o Will mandar o rascunho).
5. **Polimento final** das cenas + clímax.

---
_Escopo trava na Bola de Fogo. Tudo além (Cap. 2 / Rei Lucius / build system /
endgame) fica registrado, mas fora desta entrega._
