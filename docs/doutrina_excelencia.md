# Great Fireball — Doutrina de Excelência Comercial

> Documento-bússola. Organiza a meta monumental (bater de frente com Hollow
> Knight) em **pilares masterizáveis um por vez**. Cada pilar tem uma RÉGUA
> (como saber se está bom) e um BENCH (ferramenta que mede a cada teste).
>
> Princípio-mestre: **o que não é medido não melhora de forma confiável.**
> Foi régua + loop de ver-e-corrigir que tirou a Soph do procedural pro
> desenhado. Aplicamos o mesmo a cada pilar.

## Visão
Um metroidvania de ação onde cada personagem é inspirado numa pessoa real amada
pelo autor — um **álbum de família encantado** que também é um **forte produto
comercial**: belo, divertido por muitas horas, e acessível no preço (modelo HK).
Meta de sucesso: conforto para a família real através do sucesso do jogo.

---

## Os 5 Pilares (e por que cada um vende)

### Pilar 1 — Belas Artes 🎨
Arte coesa, legível e com alma. *Por que vende:* primeira impressão, trailers,
prints que viralizam.
- **Régua:** silhueta, legibilidade-no-pequeno, paleta coesa, borda limpa,
  leitura facial, apelo emocional.
- **Bench:** `tools/art_director/quality_bench.py` ✅ (existe). Soph HD ~6.4/10.
- **Próximo alvo:** subir Soph para 8+ (borda/anti-alias é o ponto fraco).

### Pilar 2 — Jogabilidade / Game Feel 🎮
A resposta na mão. *Por que vende:* é o que faz o jogador dizer "isso é
gostoso de jogar" e não largar. O que MAIS separa best-seller de hobby.
- **Régua:** pulo responsivo (coyote+buffer+pulo variável+gravidade de queda),
  hitstop no impacto, knockback com peso, input lag baixo, "juice" (screen
  shake, partículas, squash&stretch) na medida.
- **Bench:** `tools/art_director/feel_bench.py` ✅ (criado). Audita as
  constantes de movimento/combate contra alvos de referência do gênero.
- **Estado:** coyote 0.12s ✅, buffer 0.12s ✅. FALTA: pulo variável e
  gravidade de queda assimétrica (achado mensurável).

### Pilar 3 — Sistema de Build 🧩
Armas, armaduras, amuletos (estilo charms do HK) que alteram status e
destravam combos. *Por que vende:* a sensação "EU montei isso, EU sou
inteligente" (analogia do deck autoral de Magic). Builds viram conteúdo de
comunidade — jogadores testam e validam as criações uns dos outros.
- **Régua:** ≥2 eixos de escolha que se cruzam (sinergia real, não só +dano);
  trade-offs (ganhar X custa Y); espaço para combos emergentes que o designer
  não previu; legível (o jogador entende o que sua build faz).
- **Bench:** a definir (simulador de build — calcula DPS/sobrevivência de
  combinações, acha combos quebrados/inúteis).
- **Estado:** embrião — já há mísseis com variantes (spread/piercing/giant/
  curved), custo de mana e cooldown. Falta a camada de itens que modifica isso.

### Pilar 4 — Curva de Dificuldade 📈
Nem fácil (sem recompensa), nem impossível (desiste). O "difícil na medida
certa" onde o grind recompensa. *Por que vende:* é o vício saudável — mantém
o jogador na cadeira e dá a catarse da superação.
- **Régua:** flow channel (desafio sobe junto com a habilidade do jogador);
  morte ensina (o jogador sabe por que morreu); recompensa proporcional ao
  risco; picos (bosses) seguidos de alívio.
- **Bench:** a definir (telemetria — tentativas até vencer, taxa de morte por
  sala/boss, tempo de sessão). Mede no playtest real.
- **Estado:** existe dano de queda escalonado, bosses (ogro, golem). Falta
  instrumentar a medição.

### Pilar 5 — Lore & Personagens 📖
A história que prende, com personagens cativantes (e carregada de elementos da
vida real). *Por que vende:* é o que faz o jogador SE IMPORTAR — a diferença
entre "zerei" e "isso me marcou".
- **Régua:** personagens com desejo claro e arco; stakes pessoais; mistério que
  puxa pra frente (o Mago Graduado / a Bola de Fogo); temas universais
  (família, proteção, fé) que ressoam.
- **Bench:** revisão qualitativa contra `docs/lore_personagens.md` + o privado.
- **Estado:** rico. Família mapeada, motor narrativo definido (busca pela Bola
  de Fogo). Falta expandir arcos e diálogos.

### Pilar transversal — Trilha Sonora 🎵
Casa com tudo. *Por que vende:* a memória emocional do jogo mora no som.
- **Régua:** tema por área/personagem; reforça a emoção da cena; mixagem limpa.
- **Estado:** há AudioManager + sfx. Música a desenvolver.

---

## Estratégia de Execução — "masterizar parte por parte"

Não atacamos os 5 de uma vez. Ordem por **maior alavanca comercial × menor
custo de prova**:

1. **Game Feel primeiro** (Pilar 2). Barato de ajustar (constantes), efeito
   imediato e enorme no "isso é gostoso". Já temos o `feel_bench.py` e o Godot
   pra testar de verdade.
2. **Arte da Soph a 8+** (Pilar 1) em paralelo — já temos bench e loop.
3. **Build system** (Pilar 3) — o motor de retenção e comunidade. Maior
   esforço de design; começa quando feel+arte estiverem sólidos.
4. **Dificuldade** (Pilar 4) — precisa de conteúdo (salas/bosses) e de
   playtest pra instrumentar. Vem depois do build.
5. **Lore & Trilha** — evoluem continuamente, costuradas em tudo.

## Como medimos o progresso
Cada pilar grava no seu scorecard (ex.: `iterations/quality_scorecard.json`).
A cada sessão: rodar os benches, comparar com a rodada anterior, travar
regressão, atacar o ponto mais fraco. A curva subindo é a prova de que estamos
chegando ao nível comercial.

---
_Documento vivo. Atualizado conforme masterizamos cada parte._
