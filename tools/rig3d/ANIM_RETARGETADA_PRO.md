# Anim PRO retargetada → entrega pro dream rig (santo graal)

> **Pra instância do PC (Blender).** A nuvem assou a **anim Mixamo PRO** (idle +
> walk, retarget de verdade, **braços abaixados** — sem o placeholder de braço
> aberto) e exportou num `.glb` com a animação **embutida nos ossos**. Aqui é só
> importar e rodar o cloth em cima. Resultado = **anim PRO + dream rig cloth +
> identidade da maga**.

## 📦 O que chegou no repo (master)
| arquivo | o que é |
|---|---|
| `tools/rig3d/in/soph_idle_retargeted.glb` | Soph texturizada (rig Mixamo) **+ animação `idle`** assada — 180 frames, 6.0s, 30fps, loop |
| `tools/rig3d/in/soph_walk_retargeted.glb` | idem **+ animação `walk`** — 56 frames, 1.87s, 30fps, loop |
| `tools/rig3d/export_retargeted_anim.gd` | o exportador (como foi feito) |
| `tools/rig3d/_verify_retargeted.gd` | smoke que toca a anim do glb e renderiza (prova que a anim está embutida) |

**Importante:** a malha é **a mesma** `soph_textured_rigged.glb` (mesma topologia,
154k verts) — só ganhou a AnimationPlayer. Então o **pin map do cloth é idêntico**:
dá pra reaproveitar o `cloth_pin` que o `auto_pin_map.py` já gera, sem recalcular.

## 🧠 O que tem dentro do .glb (técnico)
- **Tracks**: rotação por osso Mixamo (`mixamorig_X`) + posição do `Hips`. 30fps, `LOOP_LINEAR`.
- A pose já inclui: **retarget por DESVIO** `t_rest * (m_rest⁻¹ · m_pose)` (fiel, em pé)
  **+ adução de braço** (22° trazendo os cotovelos pro tronco). Ou seja: **é a pose
  boa**, não a T-pose nem o procedural.
- Anim embutida nomeada `idle` / `walk` (a AnimationPlayer do glb chama `RetargetAnim`).

## ✅ Passo a passo no PC (Blender)

1. **Pull do master** pra pegar os dois `.glb`:
   ```bash
   git checkout master && git pull origin master
   # (ou: estando no claude/soph-3d-pipeline, git merge origin/master)
   ls tools/rig3d/in/soph_idle_retargeted.glb tools/rig3d/in/soph_walk_retargeted.glb
   ```

2. **Importa o glb no Blender** (File ▸ Import ▸ glTF 2.0). Vem a malha + armature
   Mixamo + a **Action** (`idle` ou `walk`). Confere: dá play na timeline → a Soph
   anda/respira com **os braços abaixados**.

3. **NÃO rode mais o `make_idle_loop.py` / `make_walk_loop.py`.** Eles eram o
   **placeholder procedural** (o braço aberto era de propósito, esperando esta anim).
   Esta anim **substitui** aquilo. Os `_*.py` (inspect/test_right_arm) seguem úteis
   só pra debugar.

4. **Aplica o pin do cloth nesta malha:**
   - rode `auto_pin_map.py` na malha importada → gera o vertex group `cloth_pin`
     (mesma topologia da base, então o mapa é o mesmo de antes).

5. **Cloth + bake com a anim PRO rodando** (em vez da T-pose do `cloth_test.py`):
   - adicione o **Cloth modifier** com os settings do `cloth_test.py` (pin group =
     `cloth_pin`, gravidade/stiffness já calibrados pra robe não virar gel);
   - corpo como **Collision** (ou pule, pelo atalho do `DREAM_RIG_FREE.md`: a câmera
     3/4 esconde penetração);
   - **Bake** do cloth no **frame range da Action** (idle 0–180 / walk 0–56) → o pano
     e o cabelo oscilam **acompanhando a anim boa**.

6. **Render → gif** com `_make_gif.py` pra visualizar. Saída em `out/dream_rig/`.

7. **Resultado = santo graal.** Aí é só repetir pro `walk` e seguir pras outras
   ações (run/cast) gerando mais `.glb` com `export_retargeted_anim.gd` (já aceita
   trocar o FBX de origem).

## 🔁 Pra gerar mais ações (lado nuvem, quando quiser)
O `export_retargeted_anim.gd` tem um dicionário `ANIMS`. É só adicionar
`"run": "res://assets/mixamo/running.fbx"` (etc.) e rodar:
```bash
xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/rig3d/export_retargeted_anim.gd -- run
```
→ sai `soph_run_retargeted.glb` pro mesmo fluxo.

## ⚠️ Notas honestas
- Os `.glb` têm **25 MB** cada (mesh texturizado embutido). Se preferir só a anim
  (sem duplicar a malha), dá pra exportar um glb só-armature depois — avisa que eu ajusto.
- O retarget foi validado tocando a anim **de dentro do próprio glb** (`_verify_retargeted.gd`),
  não só no render — então a anim **está mesmo embutida**, não é só pose de tela.

## 🎞️ Poses disponiveis (todas no master, mesmo fluxo)
| glb | anim | frames |
|---|---|---|
| soph_idle_retargeted.glb | idle | 180f/6.0s |
| soph_walk_retargeted.glb | walk | 56f/1.87s |
| soph_run_retargeted.glb | run | 236f/7.87s |
| soph_jump_retargeted.glb | jump | 73f/2.43s |
| soph_cast_retargeted.glb | cast | 69f/2.30s |
| soph_slash_retargeted.glb | slash | 50f/1.67s |
| soph_hurt_retargeted.glb | hurt | 181f/6.03s |

**Aducao de braco:** ligada so na locomocao (idle/walk/run/jump -> bracos
abaixados). Combate (cast/slash/hurt) NAO aduz, pra preservar a pose do mocap
(braco erguido no cast, golpe no slash). Controlado pelo campo `adduct` no dict
`ANIMS` do export_retargeted_anim.gd.
