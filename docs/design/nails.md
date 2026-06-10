# Unhas Poderosas — item de build (afinidade elemental)

> A Soph conjura com as mãos → as **unhas são o foco mágico**. Cada conjunto
> (nail set) dá uma **afinidade elemental** que muda o COMPORTAMENTO das magias,
> não só números. Inspirado nas "unhas impossíveis" (lava, raios, gelo…).
>
> **Cross-promo:** cada design real que a irmã do Will postar no TikTok pode
> virar um nail set aqui. A arte detalhada vive no **ícone** (`nail_<set>`); o
> efeito aparece in-game nas mãos e nas magias. Loop: vídeo mostra a unha → no
> jogo ela vira poder → "essas unhas existem no Great Fireball".

## Como funciona (código)
- Autoload **`Nails`** (`scripts/autoload/nails.gd`): guarda o conjunto equipado e
  expõe:
  - `equip(id)` / `cycle()` / `display_name()`
  - `tint()` → cor do projétil
  - `cast_glow(pos, parent)` → brilho elemental nas mãos ao conjurar
  - `on_hit(enemy, pos)` → aplica o efeito elemental ao acertar
- As magias chamam esses 3 pontos: os 5 mísseis + o cajado pintam o projétil com
  `Nails.tint()`, disparam `cast_glow` (via `_set_attack_pose("cast")`) e chamam
  `Nails.on_hit` no acerto. **Nenhum inimigo precisou ser editado** — os efeitos
  usam os métodos públicos que todos já têm (`take_damage` / `hp` / `sleep`).
- Queimadura = nó `nail_burn.gd` anexado ao inimigo (DoT universal).

## Conjuntos atuais
| Set | Cor | Efeito |
|-----|-----|--------|
| **Lava** 🌋 | laranja | Queimadura (DoT) — `apply` via `nail_burn`. |
| **Raios** ⚡ | ciano | Corrente: salta pra um inimigo próximo. |
| **Gelo** ❄️ | azul | Chance de congelar (reusa `sleep`). |
| **Aurora** 🌈 | shifting | Unhas impossíveis: a cada acerto, um elemento aleatório. |

## Como adicionar um NOVO nail set (futuro design do TikTok)
1. Em `nails.gd`: adicione a entrada em `SETS` (+ `ORDER`) com nome/cor/desc e um
   case em `on_hit` (ou reuse um efeito existente).
2. Em `sprite_setup.gd::_nail_px`: adicione o padrão do ícone (`nail_<id>`).
3. Pronto — entra no ciclo (tecla **U** no test room) e na cor das magias.

## Testar
- Test room: já entra com **Lava** equipada; tecla **U** cicla os conjuntos
  (mostra o nome no overlay). Lança magia (Z) e veja cor + efeito.
- Probe headless: `tools/nails_probe.gd` (valida Lava/Raios/Gelo/Tint).

## Ideias guardadas
- HUD com o ícone da unha equipada (hoje só aparece no overlay do test room).
- Slot de equipamento de verdade (loja/drop) pra compor build com as magias.
- Sinergias: Lava + pai Zé (fogo), Gelo + mãe Rose / Juju, etc.
- Mais sets a partir dos vídeos: cosmético + efeito (ex.: "galáxia", "veneno").
