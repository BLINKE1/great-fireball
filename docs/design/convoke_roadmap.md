# Convoke — roadmap & ideias guardadas

> A maga Soph **convoca** um aliado que entra em campo, faz um efeito e sai.
> Cada aliado é um personagem com personalidade própria.

## Implementados
| Aliado | Tecla | Arquétipo | Resumo |
|--------|-------|-----------|--------|
| **Juju** (fada) | V | Controle | Voa ~3s (vulnerável; >2 hits cortam) e adormece todos por 10s. |
| **Will** (cavaleiro) | B | Defesa | Cai do céu, esmaga quem está no ponto de queda, guarda 10s com escudo gigante (HP real; só o facho do boss o estoura). |
| **Gus** (dagger/aventureiro) | G | Dano single-target / execução | Duas adagas (hit-kill em mobs) + finalização de jiu-jítsu; no boss arranca o braço mutante. Aloca alvos pela contagem de mobs. |
| **Di** (elfa, esposa do Gus) | T | Dano à distância / multi-alvo | Sentinela: marca todos e despeja chuva de flechas ~4s, finalizando feridos e perfurando; chip no boss. |

## Ideias guardadas (futuro)
Da conversa sobre a Di — manter pra próximos aliados/variações:

1. **Bênção da Floresta (suporte/cura):** planta uma Árvore da Vida que cura a
   Soph ao longo do tempo, dá regeneração e uma aura de espinhos que fere
   inimigos próximos. Preenche o *sustain* que o grupo não tem.
2. **Flecha do Crepúsculo (dano-em-linha + CC):** UMA flecha encantada gigante
   que atravessa tudo numa linha reta (boss + mobs alinhados) e prende os
   sobreviventes em raízes (root). Espetáculo num golpe só.
3. **Convokes em dupla / tandem:** comportamento que muda conforme outro aliado
   esteja em campo. Ex.: Di dá cobertura/marcação que faz as adagas do Gus darem
   crit; finalizações em tandem do casal. (O Will/Juju também podem ganhar
   sinergias.) **O Will pediu pra desenvolvermos convokes combinados.**

## Família (lore + Convoke) — Rose & Zé
> Personagens da lore que também ganham Convoke. **New Game+**: por serem os pais
> (magos veteranos), os golpes deles podem ser **OVERKILL até no Boss**. Liberados
> em NG+, mas já dá pra **adicionar na fase de testes**.

- **Mãe Rose — maga graduada de GELO:** paira por cima da Soph e lança uma
  *execução aurora* (algo nesse estilo) — nuke de gelo. Overkill em tudo.
- **Pai Zé — mago de FOGO:** paira por cima da Soph e lança a **Grande Bola de
  Fogo**. Overkill em tudo (amarra com o clímax "Great Fireball" do jogo).

## Convokes COMBINADOS (ideias do Will — só anotado, NÃO desenvolver ainda)
> A ideia é detectar dois aliados em campo (ou um botão de dupla) e disparar uma
> coreografia conjunta. Anotações cruas:

- **Will + Gus:** Will cai, esmaga e defende. Gus vem por trás, **pula por cima
  do Will** com as duas adagas em punho pra **cravar** no inimigo e ainda
  **finaliza no jiu-jítsu**.
- **Will + Juju:** Will cai, esmaga e bloqueia. A Juju vê que ele está apanhando,
  **fica irada** e voa por cima se lançando — solta um **facho fino porém
  poderoso de luz verde**, muito dano numa **linha diagonal**.
- **Gus + Di (o casal):** atacam em conjunto, flechadas e adagas pra todos os
  lados, estilo uma **dança**. Forte contra **muitos mobs** na sala (AoE).
- **Juju + Di:** *a confirmar.*
- **Will + Di:** *a confirmar.*
- **Gus + Juju:** *a confirmar.*

### Progressão de Convokes combinados (ideia — só anotado)
- **Double Convoke** desbloqueado no **New Game+**.
- **Triple Convoke** liberado conforme o nível sobe.
- No **nível máximo**: **TODOS os aliados atacando juntos** — o hit mais épico de
  todos os tempos (full party ultimate).

## Evolução dos Convokes (NÍVEIS) — pipeline
> Cada aliado pode ter **níveis** (upgrade do mesmo convoke). O nível 1 é a
> versão "base/balanceada"; níveis maiores são mais fortes/vistosos, liberados
> por progressão (XP do convoke, itens, NG+ — a definir).

- **Di — nível 1 (atual):** chuva de flechas **curta** (`VOLLEY_TIME = 2.0`) —
  reduzida pra não ficar overkill.
- **Di — nível 2 (reservado):** a chuva **longa** original (`VOLLEY_TIME = 4.0`,
  ~dobro de flechas). É só restaurar a constante quando formos implementar os
  níveis. (Mesma lógica vale pra dar nível 2/3 aos outros: Juju dorme mais tempo,
  Will escudo mais forte, Gus dano maior, Gui mais fases de fúria, etc.)

## Notas de comportamento por Boss
- O comportamento do aliado pode mudar por **tipo de boss** (ex.: Gus arranca o
  braço do Goblin Mutante). `gus.gd::_do_finish_boss` está isolado pra ramificar
  por boss quando houver mais bosses.
