#!/usr/bin/env python3
"""
critique.py — "Óculos de entrada": usa o Gemini como segunda dupla de olhos pra
criticar o sprite atual da Soph (soph_px64). Não reescreve código — só devolve
uma crítica priorizada que eu (Claude) leio e aplico à mão.

Uso: python critique.py
"""
from PIL import Image
from engines import GeminiEngine
from art_director import load_env
import soph_px64 as S

PROMPT = """Você é um diretor de arte de PIXEL ART de jogos (estilo metroidvania,
tipo "Tale of the Magician"). Avalie este sprite com olhar técnico e honesto.

CONTEXTO: é a Soph, uma maga JOVEM e bonita, em vista 3/4 VIRADA PARA A DIREITA
(o nariz aponta para a direita de quem vê). Deve ter:
- chapéu de mago navy tombando
- cabelo azul longo ondulado, FRANJA RETA (blunt bangs)
- olhos VERDES, óculos redondos de aro fino, lábios berry, pele clara
- robe escura esguia

A imagem está ampliada (nearest-neighbor) — avalie a ARTE, não a ampliação.

PROBLEMA CONHECIDO: o rosto tende a parecer "gremlin"/duende (pontudo, torto,
proporção estranha) e o 3/4 às vezes parece frontal-chapado ("cubista").

Responda em PORTUGUÊS, OBJETIVO e PRIORIZADO:
1. NOTA 0–10 de quão crível/bonito está o rosto 3/4.
2. Os 3 ERROS mais graves, do pior pro menor — diga ONDE (olho/nariz/queixo/
   mandíbula/orelha/testa/cabelo) e POR QUÊ quebra a leitura.
3. Pra cada erro, uma CORREÇÃO concreta e específica (ex: "estreitar a mandíbula
   esquerda 2px", "descer os olhos 1px", "queixo arredondado, não pontudo").
4. UMA coisa que já está boa (pra preservar).
Seja conciso. Sem rodeios."""


def main():
    key = load_env("gemini")
    if not key:
        raise SystemExit("Sem GEMINI_API_KEY no .env")
    eng = GeminiEngine(key)
    frame = S.compose(0)
    # recorta a cabeça e amplia bastante p/ o Gemini ver os pixels do rosto
    head = frame.crop((8, 28, 56, 60))
    head = head.resize((head.width * 12, head.height * 12), Image.NEAREST)
    bg = Image.new("RGBA", head.size, (40, 38, 52, 255))
    head = Image.alpha_composite(bg, head)
    print("== enviando rosto ao Gemini (óculos de entrada) ==\n")
    print(eng.call(PROMPT, head))


if __name__ == "__main__":
    main()
