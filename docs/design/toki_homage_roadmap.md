# Roadmap — Homenagem "run-and-gun" (estágio 1 → boss) com a Soph

> **Status:** planejamento. Construir na próxima sessão.
> **Natureza:** jogo **original / homenagem** inspirado num clássico run-and-gun
> (herói que cospe projétil). NÃO é cópia: arte 100% procedural abstrata, código
> nosso. Sem assets, sprites, música ou texturas de terceiros.

## Direção de arte (decisão do Will — minimiza risco legal)
- **Chão / paredes / plataformas:** linhas **roxas** (wireframe/vetor procedural).
- **Fundo:** **preto** total. **Sem parallax**, **sem textura de cenário**.
- **Inimigos:** **formas geométricas procedurais** (sem textura), mas com
  **tamanho de hitbox igual ao do original** e **mesmas mecânicas** de movimento/ataque.
- **Herói:** a **maga Soph** (nosso asset) no lugar do protagonista.
- **Projétil:** **míssil mágico** (asset da Soph) NO LUGAR da bolinha de plasma —
  porém com a **mesma origem/altura e trajetória** do disparo original.
- **Escopo:** somente o **estágio 1 até o primeiro boss**.

## Mecânicas (FIÉIS) — spec
> Reimplementar o comportamento/medidas do original (funcional, não-protegido).
> Os **valores exatos** (velocidades, alturas, ângulos, hitboxes, roster de
> power-up) serão **fixados a partir de referência pública** na sessão de build —
> não inventar de cabeça.

### Movimento
- Correr esquerda/direita (velocidade-base fiel).
- **Pular** com arco fiel (confirmar: pulo fixo de arcade vs variável).
- **Agachar:** reduz a hitbox **e** permite **atirar agachado** → o míssil sai
  **mais baixo** (altura do disparo agachado do original).
- **Morte: 1 HIT** (estilo Mega Drive — sem barra de vida). Encostou em inimigo/
  projétil/perigo, morre. Vidas/continues + respawn no checkpoint da fase.

### Disparo (direções iguais ao original)
- Padrão: **reto à frente**, na **mesma altura** da bolinha original (em pé) e
  numa altura menor quando agachado.
- Replicar **todas as direções de tiro** do original (reto / pra cima / diagonais,
  conforme o power-up). Fixar os ângulos por referência.
- Cadência/limite de tiros na tela fiéis ao original.

### Power-ups (mesmos efeitos)
- Replicar o **mesmo conjunto** de power-ups e seus efeitos (tipos de tiro
  melhorado/spread/contínuo, velocidade de movimento, etc.). **Confirmar o roster
  exato e os efeitos via referência pública** antes de implementar.

### Medidas / hitboxes
- Hitbox da Soph em **pé / agachada / no pulo** e a de **cada inimigo** no
  **mesmo tamanho** do original (mesmo que o visual seja forma procedural).

## Reaproveitar do Great Fireball (já temos ~80%)
- `scripts/player/player.gd` — base de CharacterBody2D, pulo (coyote/buffer), dash.
- Mísseis (`scripts/spells/magic_missile.gd`) → vira o **projétil de plasma**.
- IA de inimigos (`scripts/enemies/*`) → base pros inimigos do estágio.
- Boss com **fases + ataques telegrafados** (`goblin_mutant.gd`) → base do boss.
- Probes headless (`tools/*_probe.gd`) e captura (`*_capture.gd`) → validação/GIF.

## Passos (ordem sugerida)
1. **Pesquisa de referência (fontes públicas):** mecânicas, lista de inimigos +
   **tamanhos de hitbox**, layout aproximado do estágio 1, padrões do 1º boss.
   (Usar só pra entender mecânica/medidas — não copiar arte.)
2. **Cena run-and-gun:** novo nível com **scroll horizontal** + câmera.
3. **Moveset da Soph (estilo Toki):** correr, pular (variável), agachar, **cuspir
   projétil** (reto; confirmar se mira cima/diagonal), power-ups (cadência/multi-shot,
   botas de pulo, etc.), **morte em 1 hit?** (confirmar na referência).
4. **Framework de inimigo procedural:** desenhar por forma ( retângulo/círculo)
   no **tamanho do hitbox real**, com a IA/spawn da fase.
5. **Layout do estágio 1:** segmentos de plataforma (linhas roxas) até a **arena do boss**.
6. **Primeiro boss:** padrões telegrafados (reusar a máquina de estados do boss).
7. **Win/lose + validação:** probe headless do fluxo + GIF de captura.

## Decidir na próxima sessão (perguntar ao Will)
- **Fidelidade de mecânica:** morte em 1 hit como o original, ou barra de vida?
- **Lista de power-ups** a incluir.
- **Mira:** só reto, ou cima/diagonal também?
- **Boss:** confirmar identidade/padrões via referência pública.
- **Modo:** spin-off solto ou um "modo arcade" dentro do projeto Great Fireball.

## Lembrete de IP
Reimplementar **mecânica/gênero/medidas** = ok. **Não** reproduzir arte, áudio,
personagem nem níveis 1:1. A arte abstrata (linhas roxas + preto) já garante isso.
