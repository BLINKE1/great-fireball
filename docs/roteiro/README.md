# 🔥 O Grimório das Duas Chamas

> O sistema de **roteiro vivo** do Great Fireball. Não é a bíblia de lore
> (quem-é-quem está em `docs/lore_personagens.md`) — é o **script**: cenas,
> falas, arcos, batidas emocionais. Cresce sessão a sessão, refinado a quatro
> mãos.

## As duas chamas

| | 🔥 **Chama Visível** | 🕯️ **Chama Oculta** |
|---|---|---|
| **O que é** | O roteiro público do jogo | O paralelo com a vida real |
| **Onde mora** | `docs/roteiro/` (este diretório) | [`docs/chama_oculta.md`](../chama_oculta.md) (repo privado) |
| **Quem lê** | Todo mundo | Só o Will e o Claude |
| **Função** | A história que se sustenta sozinha | A alma que dá calor a cada batida |

A Chama Oculta **enriquece o jogo mesmo para quem nunca souber** que os
personagens são a família do Will — porque a verdade vivida vaza como calor
através da ficção. O jogador sente; não precisa saber por quê.

## Como as duas ficam ligadas (sem vazar nada)

Cada cena tem um **ID** no formato `C<capítulo>·S<cena>` (ex.: `C1·S05`), e
cada batida dentro dela é numerada (`C1·S05 ▸ b2`).

- O roteiro público usa esses IDs normalmente — eles não revelam nada.
- A Chama Oculta (`chama_oculta.md`) referencia os **mesmos IDs** para dizer
  "esta batida espelha tal coisa real".

Assim as duas trilhas andam juntas e nunca se misturam no roteiro público.

## Legenda de status (por cena)

- `🎬 FILMADA` — já existe como cena jogável (`.tscn`) no jogo
- `✍️ ESCRITA` — roteiro pronto, ainda não implementada
- `🌱 ESBOÇO` — ideia/batidas soltas, a desenvolver
- `💭 SEMENTE` — só um conceito anotado pra não esquecer

## Mundo & lore profunda

- [`lore_profunda.md`](lore_profunda.md) — As Duas Coroas. A camada profunda
  (Rei Lucius, o tirano de rosto bondoso; o Outro Rei; Gui Fenrir anti-herói;
  o tema "homens bons a serviço do mal").

## Índice de capítulos

| Cap. | Título | Arquivo | Estado |
|------|--------|---------|--------|
| 1 | A Fuga da Torre | [`cap01_fuga_da_torre.md`](cap01_fuga_da_torre.md) | 🎬 filmado, roteiro em refino |
| 2 | _(a semear)_ | — | 💭 |

## Como adicionar uma cena nova

1. Copie o bloco-modelo de [`MODELO_cena.md`](MODELO_cena.md).
2. Dê um ID (`C<cap>·S<n>`) e preencha cabeçalho, ação, falas, nota de gameplay.
3. Se houver paralelo real, **não escreva aqui** — registre na Chama Oculta
   (`docs/chama_oculta.md`) referenciando o ID.
4. Atualize o estado no índice.

---
_O tom que guia tudo: proteção, zelo, amor familiar, fé. Cada fala lapidada é
uma homenagem a alguém que o Will ama. Tem que ficar **certo**._
