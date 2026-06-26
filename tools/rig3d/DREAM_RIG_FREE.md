# 🧚 Dream Rig — rota FREE (runbook pra a sessão do PC)

> **Objetivo:** levar a Soph do rig atual (Mixamo, biped, **manga e cabelo
> rígidos**) pro **dream rig**: corpo + **cabelo balançando** + **robe/manga/capa
> com pano dinâmico** — tudo **de graça** e **assado offline**.
>
> **Quem executa:** a **sessão do Claude no PC** (tem Blender + Blender MCP). A
> nuvem não tem Blender. Depois do bake, a **nuvem** faz retarget → render 3/4 →
> pixel-bake (Dead Cells) → sheet.

## 🔑 Por que a rota FREE basta pra nós
O jogo é **2D (sprites)**. Logo **não precisamos de pano em tempo real** — a
gente **simula offline, assa no frame e renderiza**. O que num jogo 3D custaria
caro (cloth runtime), pra nós é **Blender grátis**. O caro (Marvelous, Maya) é
**overkill**.

## Estado atual (ponto de partida)
- `tools/rig3d/in/soph_textured_rigged.glb` — Mixamo, **41 ossos + dedos**,
  texturizado. **Corpo OK**, mas: **manga larga rígida** (puffa, não cai) e
  **cabelo rígido** (não balança). Skinning evita clipping, mas **não é pano**.
- Stopgap já aplicado na nuvem: **adução dos braços** (`ARM_ADD` em
  `render_idle_textured.gd`) traz os cotovelos pro tronco. Ajuda, mas a manga
  baggy continua — **é isto que o dream rig resolve**.

## Ferramentas FREE
- **Blender** (já temos) — Cloth modifier (sim de pano), weight paint.
- **Wiggle Bones** ou **Spring Bones** (addon grátis) — jiggle de cabelo/saia.
- **Rigify** (addon nativo grátis) — *opcional*, se quiser re-rigar o corpo.
- *(Opcional pago ~$40: **Auto-Rig Pro** — facilita muito, mas não é obrigatório.)*

## Pipeline (passo a passo no Blender, lado PC)

### 1) Separar as malhas
No Blender, separar (P → by material/selection) o mesh em:
- **corpo+bodysuit** (segue o rig normal, skin do Mixamo),
- **robe/capa/mangas** (vai virar **cloth**),
- **cabelo** (vai virar **cadeia de ossos + jiggle**).

### 2) Cabelo dinâmico (spring bones)
- Criar uma **cadeia de ossos** descendo por cada mecha principal do cabelo
  (3–5 cadeias bastam), parentadas na cabeça.
- Weight paint o cabelo nessas cadeias.
- Aplicar **Wiggle/Spring Bones** nas cadeias → balanço com inércia.
- ⚠️ Lembrete de lore: cabelo = **mana** (raiz→pontas). O jiggle é só física; a
  cor/estado continua sendo gameplay.

### 3) Robe/manga/capa como CLOTH
- Selecionar o mesh da robe → **Physics → Cloth**.
- **Pin group** (weight paint) na **gola/ombros/cintura** (parte que gruda no
  corpo) — o resto cai/balança.
- Preset "Silk"/"Cotton" + ajustar. Para a **manga**: o pin no ombro + cloth no
  resto faz ela **cair** em vez de puffar.

> #### ⚡ Atalho do Will: cloth SEM colisão de corpo (truque dos jogos antigos)
> O que conserta o **splay** da manga é **gravidade + pin** (ela *cai*), **não**
> a colisão. E a **colisão de corpo é a parte mais chata e lenta** de ajustar.
> Como a gente assa um frame **3/4 com câmera fixa**, todo pano que **entra no
> corpo fica escondido atrás do corpo** — a câmera nunca vê o interior (igual
> PS1/PS2). Então:
> - **Pular o Collision do corpo.** Rodar cloth só com **gravidade + pin**.
> - A manga **cai** (resolve o splay); onde ela afundar no corpo, o 3/4 **oculta
>   de graça**.
> - Resultado: setup mais rápido, bake mais rápido, frame final igual.
> - ⚠️ Só vale porque a câmera é **fixa**. Se um dia girar a câmera, a
>   penetração apareceria — aí sim liga o Collision. Pro bake 2D, dispensa.
> - Cuidado tópico: só liga Collision se o pano **atravessar a silhueta** (sair
>   pelo outro lado e aparecer na borda visível). Aí é caso a caso.

### 4) Para CADA animação (idle, walk, run, cast…)
1. Aplicar a animação Mixamo no corpo (retarget — pode mandar a nuvem fazer, ou
   ARP no PC).
2. **Rodar a simulação** (cloth + jiggle) ao longo dos frames.
3. **Bake** (Cloth: "Bake"; jiggle: bake da action) → vira keyframes/cache.
4. **Exportar** o resultado (glTF com a malha já deformada por frame, ou Alembic
   `.abc` da geometria assada).

### 5) Entregar pra nuvem
- Pushar o(s) arquivo(s) assado(s) em `tools/rig3d/in/`.
- A **nuvem** renderiza 3/4 + pixel-bake Dead Cells → sheet. (Se vier Alembic com
  geometria já animada, a nuvem só renderiza câmera 3/4 — nem precisa retarget.)

## Caveats honestos
- **Cloth sim é fiçudo de configurar** (pin, colisão, settings) — é o passo que
  pede paciência. Vale começar **só com a robe** e validar antes do cabelo.
- **PC fraco (i7/8GB):** bake de cloth é pesadinho, mas **offline** → só demora,
  não trava o jogo.
- Começar pelo **idle** (pouco movimento, pano comporta) antes do walk/cast.

## Resumo
**Dream rig FREE = Blender: spring bones no cabelo + cloth sim na robe/manga,
tudo assado offline.** Corpo segue o Mixamo. Nuvem faz o render+bake. Custo: R$0.
