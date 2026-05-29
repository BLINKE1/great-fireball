---
name: godot-blackscreen-debug
description: Use quando uma cena Godot 4 mostra tela preta misteriosa ao carregar/transicionar (especialmente via change_scene_to_file ou load+instantiate). Diagnostica parse errors silenciosos, problemas de render, e erros de transicao que nao aparecem na tela mas estao no painel Output.
---

# Debugando tela preta em Godot 4

## Regra de ouro

**Tela preta + nenhuma mensagem de erro visivel = ABRIR O PAINEL OUTPUT PRIMEIRO.**

Em Godot 4, parse errors e erros de carregamento de script aparecem no painel **Output** do editor (View → Output), nao na tela do jogo. Antes de qualquer hipotese (fade overlay, _draw nao chamado, etc.), confirmar:

1. Abrir o editor com `godot -e --path <projeto>` (sem `--scene`, que ROOD a cena sem editor)
2. Rodar a cena com F6
3. Ler o painel Output

## Armadilhas comuns que causam tela preta silenciosa

### 1. Funcoes inexistentes em GDScript com nomes plausiveis

GDScript 4 NAO tem essas funcoes (parecem reais mas nao existem):

| Errado | Certo |
|--------|-------|
| `sinf(x)` | `sin(x)` |
| `cosf(x)` | `cos(x)` |
| `tanf(x)` | `tan(x)` |
| `sqrtf(x)` | `sqrt(x)` |
| `powf(x, y)` | `pow(x, y)` |

O sufixo `f` (single-precision) vem de C/C++. Quando isso aparece em `.gd`, da parse error, o script nao compila, a cena instancia mas o script **nao anexa** → todos os `_ready`, `_process`, `_draw` nunca rodam → tela preta.

Grep rapido pra checar:
```
grep -rn "sinf\|cosf\|tanf\|sqrtf\|powf" scripts/
```

### 2. Variaveis nao declaradas usadas em assignment

GDScript 4 rejeita uso de variavel nao declarada (parse error, nao warning):
```gdscript
# Em algum lugar do arquivo:
if not _soph_scared:   # ← parse error se _soph_scared nao foi declarado
    _soph_scared = true
```

Resultado: mesmo que so 1 linha use a variavel, o arquivo inteiro falha em compilar.

### 3. Semicolon depois de if single-line

```gdscript
# ERRADO - set_process(false) roda SEMPRE, fora do if
if _t >= 1.0: finished.emit(); set_process(false)

# CERTO - bloco
if _t >= 1.0:
    finished.emit()
    set_process(false)
```

Em GDScript, o `;` separa statements no mesmo nivel — nao continua dentro do `if`. A segunda funcao roda em todo frame, nao so quando a condicao bate.

### 4. Cena renderizada via `_draw()` sem `queue_redraw()`

`_draw()` so eh chamado quando o canvas item esta "sujo". Em scripts que desenham 100% via `_draw()`, **`queue_redraw()` tem que ser chamado em todo `_process()`**, senao o desenho nunca atualiza apos a primeira frame.

### 5. Rodar cena standalone que depende de fluxo anterior

Se a cena `forest_fight.tscn` espera ser carregada por `intro_flow.gd` (que chama `GameState.fade_in()` apos `add_child`), rodar standalone pode deixar overlays presos. Detectar standalone com:
```gdscript
if get_tree().current_scene == self:
    GameState.fade_in(0.6)
```

## Fluxo de debug recomendado

1. **Abrir Output panel.** Se tem erro vermelho → resolver isso, ignorar tudo mais.
2. **Se Output limpo:** adicionar um `_draw_rect` magenta no inicio do `_draw()` da cena suspeita. Se aparecer → `_draw()` roda, problema eh nas cores escuras / overlay opaco. Se nao aparecer → `_draw()` nao esta sendo chamado.
3. **Se `_draw()` nao roda:** verificar `queue_redraw()` em `_process`, e confirmar que `_process` nao foi desligado por `set_process(false)`.
4. **Se transicionando entre cenas:** confirmar com `print()` no `_ready()` da nova cena se ela carregou. Se nao printar → script tem parse error (volta pra Output panel).

## CLI Godot: o que cada flag faz

| Comando | Comportamento |
|---------|---------------|
| `godot --path <dir>` | Abre editor |
| `godot -e --path <dir>` | Forca abrir editor explicitamente |
| `godot --path <dir> --scene <tscn>` | **RODA a cena sem editor** (engana facil!) |
| `godot --path <dir> -d` | Roda projeto em modo debug |

Quando o usuario quer ver Output panel, **nao usar `--scene`**. Sempre abrir o editor primeiro.

## Anti-padrao: chutar fix antes de confirmar causa

Esse projeto deu trabalho porque comecei a chutar (fade_in, change_scene_to_packed, add_child como filho, add_child como irmao, visible=false, etc.) sem antes confirmar que o problema era parse error em `sinf()`. **Cada "fix" demorou ~5 minutos e nenhum funcionou** porque nenhum tocava na causa real.

Lic̀ao: 1 minuto lendo Output economiza 30 minutos chutando fix.
