# refs/ — referências e paint-overs do Will

Solte aqui imagens de referência ou paint-overs (PNG/JPG). O Claude lê do disco
e roda no crivo do Gemini:

    cd tools/art_director
    python critique.py refs/<arquivo>.png

Assim a imagem do chat (que o Claude não acessa como arquivo) entra no loop de
avaliação. Use nomes descritivos, ex.: `soph_paintover_2026-06-01.png`.
