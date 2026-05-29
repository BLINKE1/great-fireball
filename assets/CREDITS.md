# Créditos de Assets — Great Fireball

Registro de origem e licença de todo asset de terceiros usado no projeto.
Mantido mesmo para assets CC0 (que não exigem crédito) por segurança jurídica:
se um asset for reclassificado no futuro, há prova da licença vigente no momento do uso.

## Arte autoral

Sprites e tilesets gerados pelo **assets-creator** (projeto do autor) e os rascunhos
em `assets/cutscenes/referencias-desenhos/` são arte original e propriedade do autor.
Estes têm prioridade sobre qualquer asset de terceiros.

## Assets procedurais

Todos os sprites em `scripts/autoload/sprite_setup.gd` são gerados em código pelo
projeto — sem dependência externa, sem questões de licença.

## Assets de terceiros

### Kenney Asset Pack 1 — RPG Sounds & UI Sounds
- **Autor:** Kenney (kenney.nl)
- **Fonte:** https://github.com/iwenzhou/kenney (mirror CC0 completo)
- **Licença:** CC0 1.0 Universal — uso comercial livre, sem atribuição obrigatória
- **Data de integração:** 2026-05-29
- **Arquivos (em assets/audio/):**
  - `step.ogg` ← RPG/footstep00.ogg
  - `land.ogg` ← RPG/footstep04.ogg
  - `sword.ogg` ← RPG/knifeSlice.ogg
  - `hit.ogg` ← RPG/metalPot1.ogg
  - `hit_player.ogg` ← RPG/metalPot2.ogg
  - `unlock.ogg` ← RPG/metalLatch.ogg
  - `chest.ogg` ← RPG/bookOpen.ogg

### Kenney Interface Sounds (Calinou/kenney-interface-sounds)
- **Autor:** Kenney (kenney.nl), portado por Calinou
- **Fonte:** https://github.com/Calinou/kenney-interface-sounds
- **Licença:** CC0 1.0 Universal
- **Data de integração:** 2026-05-29
- **Arquivos (em assets/audio/):**
  - `tick.wav` ← tick_001.wav
  - `qte_alert.wav` ← bong_001.wav
  - `orb_pickup.wav` ← pluck_001.wav
  - `victory.wav` ← confirmation_001.wav
  - `no_mana.wav` ← error_001.wav
  - `glass_break.wav` ← glass_001.wav

<!--
Modelo de entrada (preencher ao integrar cada pacote):

### <Nome do pacote>
- **Autor:** <autor>
- **Fonte:** <url>
- **Licença:** <CC0 / CC-BY 4.0 / etc.>
- **Atribuição exigida:** <sim/não — se sim, texto exato>
- **Arquivos:** <quais chaves/arquivos vieram daqui>
- **Data de integração:** <AAAA-MM-DD>
-->
