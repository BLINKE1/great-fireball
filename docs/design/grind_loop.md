# 🧭 Sistema de Grind — Quadro de Insights (Great Fireball)

> Insights de retenção/loop tirados de **Tibia** (vivo desde 1997) e **Hollow
> Knight**, adaptados pro nosso jogo. Documento de **análise** — ainda não é
> decisão fechada; ver "Decisões em aberto" no fim. **Trabalhar em momento
> oportuno.**
>
> **Princípios-mãe:**
> - "Não é gráfico que segura, é o **loop**." (Tibia é feio e vive há ~30 anos.)
> - "Trava o que define a **identidade**, libera o resto." (vale pra dye, montaria,
>   cosmético — protege a Soph enquanto dá expressão ao jogador.)

## A. Progressão & Economia — *o motor*
| Insight | Origem (Tibia/HK) | Vira no nosso game |
|---|---|---|
| **Eixos múltiplos** de progressão | XP + magic level + skill + gear (3 barras subindo sempre) | Nível da Soph + **upgrades de mana/spell (cabelo)** + gear (chapéu/cajado) |
| **Loop econômico auto-sustentável** | hunt→loot→gold→gear→hunt melhor (banca a premium) | dungeon-floresta → **essência-mana** → forja/upgrade → dungeon mais fundo |
| **Conteúdo diário estruturado** | warzones 1/2/3 → rotina vira **hábito** | tiers de dungeon diários (1/2/3) com recompensa diária |

## B. Risco & Maestria — *o motor emocional*
| Insight | Origem | Vira no nosso game |
|---|---|---|
| **Penalização real** (stakes) | Tibia: XP/itens · HK: geo | morrer **dropa a essência-mana** da run |
| **Perda recuperável** (2º pico de tensão) | HK shade / Souls bloodstain | volta ao ponto de morte e recupera — se sobreviver de novo |
| **Penalidade escala com a profundidade** | — | floresta rasa = leve (convida) · profundezas = pesada (medo gostoso) |
| **Maestria visível e recompensada** | — | badge / rota rápida / drop garantido ao dominar a área → vira identidade |
| **Ciclo medo→tentativa→triunfo→maestria** | vivência (Will no Abyssador) | área nova assusta → vencer satisfaz → vira sua "farm" |

## C. Cosmético & Prestígio
| Insight | Origem | Vira no nosso game |
|---|---|---|
| **Grind por status, zero poder** | addons Tibia (cosméticos) | variantes de chapéu/robe/efeito de cabelo como chase |
| **Sem power-creep + nunca acaba** | addon não dá stat | colecionável infinito sem quebrar balanço |
| **Event-gated** (FOMO + timing) | Mage's Cap (World Change "Their Master's Voice", última wave, dropa do Mad Mage) | drop de **boss de evento** em janelas |
| **Vias múltiplas de aquisição** | lootar OU comprar com kks | dropar você mesmo **OU** craftar caro |
| **Cosmético é o melhor sink** | — | escoa moeda **sem** dar poder |

## D. Personalização (Dye) — *ownership barato*
| Insight | Origem | Vira no nosso game |
|---|---|---|
| **Tinta bounded = ownership** | dye do Tibia (c/ ressalvas, zonas não-tingíveis) | **paletas/skins desbloqueáveis** (não RGB livre) |
| **Zona não-tingível preserva identidade** | gema do cajado tinge, cajado não | dye em acessórios/gema · robe parcial |
| **Identidade é sagrada** | — | **cabelo-mana NÃO entra no dye** (é mecânica/estado de gameplay) |

## E. Montaria — *speed floor + a tensão cosmético×stat*
| Insight | Origem (Tibia / vivência) | Vira no nosso game |
|---|---|---|
| **Floor utilitário universal** | TODA montaria dá **+10 speed** (Donk → Manta Ray, tanto faz) | toda montaria dá **+move speed base** → ninguém fica pra trás |
| **Chase cosmético** (fora o floor) | raridade muda só o visual | montaria rara = prestígio |
| ⚠️ **"Gap do jogador racional"** | Will de Water Buffalo por *ages* — sem stat, sem razão pra trocar | se todas = mesmo stat, **só status puxa**, e o racional estaciona |
| **Fadiga de cosmético é real** | "com o tempo você só sente que precisa mudar" | até o racional **cansa e quer novidade/status** — só num prazo longo |
| **Sidegrade > upgrade** (insight nosso) | — | montaria difícil dá **utilidade DIFERENTE**, não "melhor": uma regenera **mana** ao cavalgar, outra atravessa **hazard**, outra dá **dash**, outra puxa **essência**. Motiva sem power-creep |
| **Montaria content-gated** (insight nosso) | — | área **exige** montaria (voadora p/ acessar zona nova, aquática p/ travessia) → razão funcional, sem gap de poder |
| **Montaria = familiar/identidade** | — | **os pets da família** (ver `docs/familia_pets.md`): Chanel, Julie, Bylu como familiares/montarias; Thor/Mel como memorial. ⚠️ nada de vassoura (regra maga≠bruxa) |

> **Tensão central da montaria:** Tibia (todas iguais, egalitário, racional não
> chasa) ⟷ lean do Will (stat por dificuldade, motiva MAS gera power-creep +
> montaria "obrigatória"). **Meio-termo proposto: floor universal + sidegrades.**

---

## 🔶 Decisões em aberto (pra analisarmos)
1. **Sink principal:** poder (gear/boost) vs cosmético — Will tende a poder, cosmético como exceção (o chapéu). Definir a proporção.
2. **Dureza da penalização:** achar o *sweet spot* do medo sem virar frustração que trava exploração.
3. **Dye:** paletas curadas vs liberdade parcial — quanto liberar sem diluir a Soph?
4. **Moeda:** única (gold) ou dupla (gold + essência-mana)? Dupla separa "comprar" de "upgradar".
5. **Tiers diários:** quantos, e o que muda entre 1/2/3 (dificuldade? loot? modificadores?).
6. **Montaria:** floor universal + sidegrades (voto do Claude) · cosmético puro (Tibia) · ou stats escalantes (lean do Will)?
7. **Sidegrades de montaria:** mana-regen ao montar · traversal de hazard · dash · pickup de essência — quais entram? E como os **familiares-pets** se encaixam (Julie "vê" o mapa por memória, etc.)?

---
*Status: rascunho de design pra refinar. Pilares A–E + 7 decisões em aberto.*
