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
- **Herói:** a **maga Soph** (nosso asset) no lugar do protagonista; cospe
  "plasma" (reusar o sistema de míssil dela).
- **Escopo:** somente o **estágio 1 até o primeiro boss**.

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
