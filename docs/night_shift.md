# 🌙 Night Shift — remodelagem da parte jogável (Cap. 1)

> Sessão autônoma (Will dormindo). Pedido: remodelar TODA a parte jogável —
> "faz o jogo virar um jogo". Stage contínuo, QTE da torre mantido (embelezar),
> ponta-a-ponta primeiro, híbrido procedural+free. Tudo no master, validado
> headless.

## O que mudou (fluxo do Cap. 1, agora coerente e JOGÁVEL)
```
anime → TORRE QTE (noturna) → queda → FLORESTA JOGÁVEL DE VERDADE
        (grama, céu, árvores; goblins reais → Goblin Mutante, arena trancada
         por pedras) → Grande Bola de Fogo (clímax) → fim do capítulo
```
Antes, a parte "jogável" do intro eram **cutscenes scriptadas com sprites
estáticos** (landing/goblin_encounter/forest_fight) — "feio, conceitual". Agora
o jogador cai da torre e entra no **nível real** (Player físico, física,
inimigos de verdade, boss com rockfall).

## Commits da noite
1. **Tema floresta** — a dungeon (que o diálogo já chamava de floresta) deixa de
   ser caverna: tiles de **grama** (chão/plataformas), **céu de entardecer em
   gradiente**, e **árvores decorativas** no mundo (atrás do gameplay). 
   _(O parallax de árvores não renderiza no contexto da dungeon — limites de
   câmera —, então usei árvores como sprites no mundo + o céu-gradiente; fica
   bem mais confiável.)_
2. **Boss room de verdade (estilo Megaman)** — ao entrar, uma **avalanche de
   pedras** desaba atrás da Soph (queda + stomp + shake + poeira), prendendo-a na
   arena com o Goblin Mutante. Na morte do boss, a barreira desmorona.
3. **Rewire do capítulo** — depois da queda, `change_scene` pro nível real
   (`dungeon_1`); a vitória do boss leva ao **clímax da Bola de Fogo**
   (`anime_fireball`) → `chapter_end`. As cutscenes scriptadas saem do fluxo
   (ficam no codebase).
4. **Torre embelezada** — o `qte_tower` (QTE mantido) ganhou cenário: **topo de
   torre ao luar** (céu estrelado, lua com glow, ameias de pedra, piso).

## Validação
- Parse limpo; **boot do jogo sem erro de script**.
- Cenas-chave do fluxo carregam (qte_tower, dungeon_1, anime_fireball,
  chapter_end).
- `rockwall_probe` (a barreira cria/colide/some).
- Capturas in-engine: floresta (grama+céu+árvore), torre noturna, rockwall.

## 🎚️ Pro teu playtest / decisões
- **Direção do nível**: você falou "corre pra esquerda", mas o `dungeon_1` é
  construído da esquerda p/ a direita (goblins → boss em x crescente). Mantive
  como está (refazer espelhado é arriscado). Se quiser invertido, a gente vê.
- **Parallax de árvores**: as árvores hoje são decorativas no mundo. Se quiser
  o parallax "de verdade" (movendo em camadas), dá pra investigar os limites de
  câmera da dungeon — fica como polish.
- **Tutorial**: continua tema caverna (o intro pula direto pra floresta). Posso
  retematizar depois se quiser.
- **Cutscenes antigas** (landing/goblin_encounter/forest_fight) seguem no repo,
  fora do fluxo — dá pra apagar quando você confirmar que não quer reaproveitar.
- Constantes de tato do rockfall e do boss estão no topo dos arquivos.
