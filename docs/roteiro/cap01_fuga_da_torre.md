# Capítulo 1 — A Fuga da Torre

> 🔥 Chama Visível. Primeiro capítulo, já **filmado** (todas as cenas existem
> como `.tscn`). Este roteiro consolida o que está no jogo e lapida as falas.
> Paralelos reais vivem na Chama Oculta (`soph_lore.env`), por ID de cena.

**Premissa do capítulo:** Soph, uma jovem maga de cabelos azuis, está presa no
alto de uma Torre. Quando uma horda a encurrala, ela escapa pela própria
coragem — e, no limite, uma Grande Bola de Fogo vinda de um mago encapuzado
desconhecido a salva e some. Soph jura descobrir quem é, e aprender aquela
magia. É o motor do jogo inteiro.

**Arco de Soph no capítulo:** de _presa e protegida_ → a _capaz de se defender_.
Ela ainda não é a heroína completa; dá o primeiro passo.

---

## `C1·S01` — Abertura  `🎬 FILMADA`

**Onde / quando:** Anime de abertura · sobre a Torre · crepúsculo
**Arquivo do jogo:** `scenes/intro/anime_placeholder.tscn`
**Logline:** Estabelece o mundo, a Torre e a menina-maga presa nela.

**Personagens:** Soph.

### Ação
- **b1** — Painéis em estilo anime apresentam a Torre solitária contra o céu.
- **b2** — Lá no topo, uma silhueta de cabelos azuis à janela. Pequena diante
  da imensidão. A imagem diz: *alguém aqui foi deixada para trás.*

### Falas
> _(Sem diálogo — só atmosfera e título.)_

### Nota de gameplay
Cutscene não-interativa. Prepara o tom antes do primeiro controle.

### Liga com
Abre o jogo → entrega o controle no QTE da Torre (`C1·S02`).

---

## `C1·S02` — O Tempo Parado (QTE)  `🎬 FILMADA`

**Onde / quando:** INT · Câmara no topo da Torre · noite
**Arquivo do jogo:** `scenes/intro/qte_tower.tscn`
**Logline:** Sob ameaça iminente, Soph descobre que pode **parar o tempo** — e
o jogador aprende a primeira mecânica num momento de pânico.

**Personagens:** Soph; a ameaça (sombras/guardas).

### Ação
- **b1** — Algo invade a câmara. Não há para onde correr.
- **b2** — No instante do desespero, Soph ergue o cajado — o jogador acerta o
  QTE — e **o tempo congela**. O mundo prende a respiração.

### Falas
> **SOPH** _(ofegante)_: "Para… PARA!"

### Nota de gameplay
Quick-Time Event ensina **Parar o Tempo** (Time Stop). Falhar leva à tela de
captura (`C1·S11`); acertar abre a fuga.

### Liga com
Vem da abertura → o congelamento permite a fuga (`C1·S03`).

---

## `C1·S03` — Entre Estátuas  `🎬 FILMADA`

**Onde / quando:** INT · Câmara congelada no tempo
**Arquivo do jogo:** `scenes/intro/time_stop_aftermath.tscn`
**Logline:** Com tudo paralisado, Soph respira pela primeira vez — e percebe
que a janela é a única saída.

**Personagens:** Soph; ameaças congeladas.

### Ação
- **b1** — Soph caminha entre inimigos suspensos no ar, imóveis como estátuas.
- **b2** — O olhar dela encontra a janela aberta. Lá fora: o vazio e a queda.
  A decisão se forma — sair pela janela é loucura, e é a única chance.

### Falas
> **SOPH** _(baixo, para si)_: "A janela. É só… não olhar pra baixo."

### Nota de gameplay
Movimento livre tutorial, ritmo calmo. Ensina a andar/observar sem perigo.

### Liga com
Do QTE (`C1·S02`) → leva ao corredor rumo à janela (`C1·S04`).

---

## `C1·S04` — O Corredor  `🎬 FILMADA`

**Onde / quando:** INT · Corredor da Torre
**Arquivo do jogo:** `scenes/intro/tower_corridor.tscn`
**Logline:** O primeiro trecho de plataforma de verdade — a Torre tenta segurá-la.

**Personagens:** Soph.

### Ação
- **b1** — O tempo volta a correr atrás dela. Soph atravessa o corredor.
- **b2** — Saltos e quedas curtas ensinam o pulo (agora com peso e controle de
  altura — ver Doutrina, Pilar 2).

### Nota de gameplay
Tutorial de plataforma: pulo variável, coyote time, queda. Sem combate ainda.

### Liga com
Da câmara (`C1·S03`) → desemboca na janela (`C1·S05`).

---

## `C1·S05` — A Queda e o Air Hike  `🎬 FILMADA`

**Onde / quando:** EXT · Lado de fora da Torre, em queda · noite
**Arquivo do jogo:** `scenes/intro/window_fall_anime.tscn`
**Logline:** Soph se joga pela janela e, no ar, descobre o **Air Hike** — o
segundo impulso que transforma uma queda mortal em voo controlado.

**Personagens:** Soph.

### Ação
- **b1** — Ela salta. O chão da Torre some sob seus pés. Vento, cabelo azul,
  coração na garganta.
- **b2** — No ponto mais baixo do medo, o instinto age: um **segundo salto no
  ar**. A queda vira arco. Ela não está mais caindo — está escolhendo onde
  pousar.

### Falas
> **SOPH** _(grito que vira riso)_: "Eu consigo — EU CONSIGO!"

### Nota de gameplay
Ensina **Air Hike** (Shift). Primeira habilidade de mobilidade que define o
movimento do jogo todo.

### Liga com
Do corredor (`C1·S04`) → ao pouso na floresta (`C1·S06`).

---

## `C1·S06` — Pouso e a Primeira Ferida  `🎬 FILMADA`

**Onde / quando:** EXT · Clareira na floresta, ao pé da Torre · noite
**Arquivo do jogo:** `scenes/intro/landing_gameplay.tscn`
**Logline:** Soph toca o chão pela primeira vez livre — e aprende a **se curar**.

**Personagens:** Soph.

### Ação
- **b1** — Pouso. O impacto cobra seu preço; ela sente a primeira dor da
  jornada.
- **b2** — A mão brilha — ela aprende a **Cura**. Pequeno milagre: ela pode
  cuidar de si mesma agora.

### Falas
> **SOPH:** "Ainda inteira. Tá bom. Tá bom…"

### Nota de gameplay
Tutorial de **Cura** (C) e do sistema de dano de queda. Primeiro respiro seguro.

### Liga com
Da queda (`C1·S05`) → ao primeiro inimigo (`C1·S07`).

---

## `C1·S07` — O Primeiro Goblin  `🎬 FILMADA`

**Onde / quando:** EXT · Floresta
**Arquivo do jogo:** `scenes/intro/goblin_encounter.tscn`
**Logline:** Um goblin ataca; Soph aprende a revidar com o **Míssil Mágico** —
sua primeira arma ofensiva, e o embrião do poder que ela levará ao limite.

**Personagens:** Soph; Goblin.

### Ação
- **b1** — Um goblin salta dos arbustos. O medo dela vira foco.
- **b2** — O cajado dispara o primeiro **Míssil Mágico**. O goblin cai. Soph
  encara a própria mão, surpresa com o que é capaz.

### Falas
> **SOPH** _(quase um sussurro)_: "…eu fiz isso."

### Nota de gameplay
Tutorial de **Míssil Mágico** (Z) e de combate. _Setup do arco de poder:_ é
daqui que cresce, capítulo a capítulo, até o Míssil Mágico Gigante do end-game.

### Liga com
Do pouso (`C1·S06`) → à provação na floresta (`C1·S08`).

---

## `C1·S08` — A Floresta Cerra  `🎬 FILMADA`

**Onde / quando:** EXT · Coração da floresta · noite
**Arquivo do jogo:** `scenes/intro/forest_fight.tscn`
**Logline:** Três goblins, um boss mutante e, no fim, uma **horda** inteira —
mais do que Soph, sozinha, pode vencer. O capítulo a empurra além do limite.

**Personagens:** Soph; 3 goblins; boss mutante; a horda.

### Ação
- **b1** — Soph aguenta três goblins usando tudo que aprendeu.
- **b2** — Um boss mutante surge; luta dura, vitória apertada.
- **b3** — Então a floresta inteira se move: uma **horda** sem fim a cerca. Ela
  recua, cajado erguido, sem mais espaço para onde ir. *Não vai dar.*

### Nota de gameplay
Pico de dificuldade do capítulo (ver Doutrina, Pilar 4). A horda é desenhada
para ser **impossível de vencer sozinha** — prepara o resgate.

### Liga com
Do primeiro goblin (`C1·S07`) → ao milagre da Bola de Fogo (`C1·S09`).

---

## `C1·S09` — A Grande Bola de Fogo  `🎬 FILMADA`

**Onde / quando:** EXT · Floresta cercada · auge da noite
**Arquivo do jogo:** `scenes/intro/anime_fireball.tscn`
**Logline:** No instante final, um **mago encapuzado** desconhecido surge e
consome a horda inteira com uma única **Grande Bola de Fogo** — depois
desaparece. Nasce o mistério que move o jogo.

**Personagens:** Soph; **o Mago Graduado** (rosto oculto pelo capuz).

### Ação
- **b1** — Quando tudo parece perdido, o ar esquenta. Uma silhueta de capuz
  surge entre Soph e a horda.
- **b2** — Ele ergue a mão. Uma **Grande Bola de Fogo** — enorme, dourada —
  varre a floresta. A horda vira cinza e luz.
- **b3** — Ele diz sua frase. Olha para Soph por um instante. E **some**, sem
  nome, sem explicação.

### Falas
> **MAGO GRADUADO:** "Não importa o tamanho do problema, o que importa é o
> tamanho da bola de fogo."

### Nota de gameplay
Cutscene-clímax. Estabelece a magia-mito (que **Soph nunca aprende**) e o alvo
da jornada: descobrir quem é ele e honrar aquele poder ao modo dela.

### Liga com
Da horda (`C1·S08`) → ao fecho do capítulo (`C1·S10`). Setup do motor narrativo
de todo o jogo.

---

## `C1·S10` — O Juramento  `🎬 FILMADA`

**Onde / quando:** EXT · Floresta, fumaça baixando · antes do amanhecer
**Arquivo do jogo:** `scenes/intro/chapter_end.tscn`
**Logline:** Sozinha de novo, mas viva, Soph encara o lugar onde o mago estava
e decide o que fará com a vida que ganhou de volta.

**Personagens:** Soph.

### Ação
- **b1** — Silêncio. Só cinzas mornas e o cheiro de fogo. Soph respira.
- **b2** — Ela olha o próprio cajado, depois o horizonte. A decisão: *descobrir
  quem era — e aprender a fazer aquilo.* O primeiro passo da heroína.

### Falas
> **SOPH:** "Quem quer que você seja… eu vou te encontrar. E vou aprender."

### Nota de gameplay
Fecho de capítulo. Transição para o mapa/mundo aberto do Capítulo 2.

### Liga com
Da Bola de Fogo (`C1·S09`) → abre o Capítulo 2.

---

## `C1·S11` — Captura (Derrota)  `🎬 FILMADA`

**Onde / quando:** Tela de desfecho ruim
**Arquivo do jogo:** `scenes/intro/outcome_screen.tscn`
**Logline:** Se Soph falha (ex.: erra o QTE), é capturada — o custo do fracasso,
que dá peso à vitória.

**Personagens:** Soph.

### Nota de gameplay
Tela de game-over narrativo. Reforça que a fuga importava.

### Liga com
Ramo de falha de `C1·S02` (e outros pontos letais) → tela de captura.

---

_Próximo: Capítulo 2 (a semear). Soph no mundo aberto, atrás do Mago Graduado._
