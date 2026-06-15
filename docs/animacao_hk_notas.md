# Animação 2D — notas do HK e ferramentas de coerência

> Doc pessoal do Will. Guardado a pedido: as dicas que apareceram na conversa
> sobre como o Hollow Knight mantém coerência e quais ferramentas os artistas
> usam pra "ancorar" o desenho. Pra quando eu for me aprofundar em animação.

## O ouro do Hollow Knight

**HK é frame-by-frame desenhado à mão. Não é rig.** O Team Cherry fez o jogo no
Unity, mas a animação do Cavaleiro e da maioria dos personagens **não é
esqueleto/bones** — o Ari Gibson desenhou **quadro a quadro**, cada pose na
perspectiva final que ela precisava ter. O Unity só **troca os sprites** em
sequência (sprite swap).

**No nosso projeto:** isso é exatamente o que o `player.gd::_build_soph_frames_hd`
faz — `AnimatedSprite2D` + `SpriteFrames` = troca de frame = método do HK. Já
estamos na arquitetura certa.

### Por que rig de T-pose frontal não vira ação lateral

Bones em 2D só **transladam, rotacionam e escalam pixels que já existem**. Eles
NÃO conseguem:
- revelar o *outro lado* do rosto/chapéu quando vira de frente pra 3/4 ou perfil;
- redesenhar um membro em *foreshortening* (perna chutando na direção da câmera);
- mudar a **silhueta**, que é o que vende ação.

Uma T-pose frontal não carrega a informação visual do perfil. Nenhum rig 2D
"inventa" o lado que não foi desenhado. Por isso o HK não tentou rigar pose
frontal pra gerar ação — eles desenharam cada ângulo na fonte.

### Onde o HK *sim* usa rig/cutout

Alguns NPCs/bosses grandes têm peças recortadas (cutout puppet) pra movimentos
amplos de partes que **mantêm o mesmo ângulo de câmera**. Translação/rotação no
mesmo plano é onde bone 2D brilha. Ação com mudança de perspectiva = sempre
frame novo desenhado.

## Como artistas mantêm coerência (os 4 dispositivos de ancoragem)

Não é talento mágico — são técnicas conscientes. Quem "sai sem ancoragem"
desenha a *superfície* direto, sem essas camadas embaixo.

1. **Model sheet / turnaround — A ÂNCORA.** Antes de animar, desenha-se o
   personagem de frente/lado/costas/3-4 + folha de expressões + guia de
   proporção, e deixa colado do lado / numa layer. *Toda* pose nova é conferida
   contra essa folha. O termo da indústria é **"on-model"** (dentro do modelo).

2. **Construção por volumes (o pulo do gato).** Não começa pelo contorno.
   Começa com formas simples — esferas, cilindros, "ball and stick", *line of
   action*. A coerência vem do **esqueleto de formas**, não de copiar pixels.
   Por isso a personagem fica igual num ângulo novo: a estrutura embaixo é a
   mesma. Pular isso = "sai diferente toda vez".

3. **Proporção medida em cabeças.** "X cabeças de altura, olho na metade do
   crânio." Medir em *head-units* trava tamanho/proporção entre poses. É régua,
   não olho.

4. **Onion skinning / lightbox / pegbar.** Ver o frame anterior como fantasma
   embaixo → o próximo nasce consistente. Tradicional = mesa de luz + pino;
   digital = "papel cebola".

> Bônus: repetição. O Ari Gibson desenhou o Cavaleiro milhares de vezes —
> familiaridade também é ancoragem.

## Ferramentas (o recurso-chave é onion skin + reference layer)

| Ferramenta | Nota |
|---|---|
| **Photoshop** | O que o HK usou. Tem timeline de animação + onion skin. |
| **Toon Boom Harmony** | Padrão de estúdio (TV/cinema). Frame-by-frame + cutout/rig. |
| **TVPaint** | Animação tradicional raster, muito querida por animadores 2D. |
| **Clip Studio Paint EX** | Excelente pra desenho + animação; barato; popular em anime/mangá. |
| **OpenToonz** | Grátis, open source. É o software que o Studio Ghibli usa (Toonz). |
| **Krita** | Grátis, open source. Tem onion skin e timeline de animação. |
| **Blender (Grease Pencil)** | Grátis. Desenho 2D dentro de espaço 3D; onion skin forte. |
| **Procreate Dreams** | iPad, animação acessível. |

**Pra posar ângulos (anchor de pose):** apps de manequim 3D — **Magic Poser**,
**Design Doll** — você posa um boneco no ângulo certo e desenha por cima. Outra
forma de âncora.

## Tradução pro nosso pipeline de geração (Soph HD)

A nossa rota de IA imita o **model sheet**: uma referência forte (anchor) +
geração na MESMA imagem = identidade travada (provado no 1º sheet —
`tools/art_director/gen_hd_sheet.py`).

- **Economia do HK:** poucos frames com silhueta forte + timing. O "juice" vem
  do `player.gd::_update_visuals` (lean/stretch/squash), não da quantidade de
  frames. Manter ciclos enxutos.
- **Silhueta antes de detalhe:** critério de garimpo — se a pose lê só pela
  mancha, presta.
- **Espelhamento:** Soph é *side view facing right*; o lado esquerdo é grátis no
  Godot (`flip_h`).
- **Anchor chaining:** o 1º sheet aprovado pode virar a nova master anchor
  (`gen_hd_sheet.py --anchor <url>`) — igual ao turnaround colado na mesa.
