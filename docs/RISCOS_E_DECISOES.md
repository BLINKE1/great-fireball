# 🚨 Riscos & Decisões — Great Fireball

> Pontos cegos, riscos e decisões pendentes que o Claude levantou (sessão de
> 2026-06-24) e que o Will **não estava perguntando**. Documento vivo — atualizar
> conforme decidir. Ordenado por importância.

## 🔴 Riscos altos

### R1 — O ativo mais valioso da Soph 3D só existe no PC
O mesh **vestido + texturizado** (69MB, Hunyuan 3D Studio) **não está no repo** —
só no cache local `D:\...\great-fireball-local-cache\soph3d\`. Se o PC pifar/
formatar ou o histórico do Hunyuan expirar, **perde-se a Soph 3D definitiva**.
Os 3 PNGs multiview (`docs/concept_art/multiview/`) permitem regerar, mas **não
deterministicamente** — não sai igual.
- **Ação:** backup redundante (Git LFS, drive externo, etc.) — **urgente**.

### R2 — O 3D é trilha paralela e NÃO está plugado no jogo (sem go/no-go)
Hoje o jogo roda a **Soph 2D HD** (`USE_HD_SOPH=true`). O pipeline 3D é R&D que
ainda não substituiu nada. Risco: virar **tech demo que nunca embarca**.
- **Decisão pendente (GATE):** definir o critério de "quando/SE o 3D entra no
  lugar do 2D". Sem gate, refina-se 3D pra sempre sem lançar.

### R3 — Ninguém respondeu: a Soph 3D é MELHOR que a 2D HD atual?
Todos os renders 3D foram **cinza**. Nunca se viu a **Soph 3D texturizada na
escala do jogo**. Pode ser que, pintada e pequena, **não ganhe** da 2D HD.
- **Ação (barata, faz antes de mais 3D):** render texturizado no PC → comparar
  lado a lado com a 2D → **decidir se o 3D vale o esforço**.

## 🟠 Riscos médios

### R4 — Escopo vs. vida (Arthur chegando ~2 meses, dev solo)
O Capítulo 1 / vertical slice **já está implementado**. Com bebê chegando e dev
solo, **terminar e lançar a fatia 2D** provavelmente vale mais que reconstruir
em 3D. O 3D é **want**, não **need** pra ter algo jogável.
- **Princípio:** não deixar o 3D (fascinante) atrasar o "lançar algo".

### R5 — Backup do insubstituível e afetivo
Fotos da família (Sophia+Chanel de 12 anos, a Mel que partiu, o biscuit), fontes
em alta — parte pode viver só no celular/zap. Código se reescreve; a foto da Mel
não.
- **Ação:** backup redundante das fontes originais (fotos, refs).

### R6 — Áudio / game feel é alavanca intocada
Zero discussão de som. Música/SFX é o **maior multiplicador de "sensação" por
hora** investida, e começa barato. Ponto cego.

## ⚪ Notas de coerência
- **Soph NUNCA aprende Fireball** (motor narrativo). Ao desenhar os eixos de
  progressão (`docs/design/grind_loop.md`), nenhum upgrade pode virar Fireball.

## ✅ Ordem recomendada (se fosse o Claude)
1. **Backup** do mesh 69MB + fotos de família (hoje, ~10 min — protege o irreparável).
2. **Render texturizado** da Soph 3D no PC → comparar com a 2D → **go/no-go do 3D** (R3).
3. Se **go**: seguir o pipeline (Mixamo locomoção → render → sheet, ou Plano B).
   Se **no-go**: **lançar a fatia 2D** e usar 3D só onde brilha.

---

## 🏛️ Marco preservado — "Era da arte primitiva de IA"
Decisão (Will, 2026-06-24): **congelar todo o jogo + código procedural atual**
como snapshot (tag git) — um registro da era artesanal/manual de dev com IA — e
**partir dele pro jogo novo**, onde tudo será re-trabalhado.
- **Mobs:** serão **todos re-trabalhados** (ex.: o Boss Goblin procedural é um
  espetáculo, mas não é a versão final). Antes disso, **encontrar o fluxo de
  produção de mob que funciona** (o equivalente do que fizemos pra Soph).
- O snapshot garante que o estado "primitivo" nunca se perde, mesmo reescrevendo tudo.
