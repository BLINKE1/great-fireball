extends SceneTree
## Prova numérica do modelo HÍBRIDO de mana (sem abrir o jogo todo).
##   $GODOT --headless -s tools/mana_probe.gd

func _initialize() -> void:
	var ManaScript = load("res://scripts/player/mana.gd")
	var m = ManaScript.new()
	m.max_mana = 100.0
	m._ready()                 # current_mana = 100
	m.regen_rate = 4.0
	m.out_of_combat_delay = 2.0

	print("═══ MODELO HÍBRIDO DE MANA ═══")
	print("início: %.0f" % m.current_mana)

	# Gasta 60 (lançou magias) → regen deve PAUSAR
	m.spend(60.0)
	print("após gastar 60: %.0f  (lull liga em %.1fs)" % [m.current_mana, m.out_of_combat_delay])

	# 1.5s ainda em combate (dentro do lull) → NÃO regenera
	_tick(m, 1.5)
	print("+1.5s (em combate): %.1f  → esperado ~40 (sem regen)" % m.current_mana)

	# levar dano renova o lull
	m.bump_combat()
	_tick(m, 1.0)
	print("+1.0s após levar dano: %.1f  → esperado ~40 (regen ainda pausada)" % m.current_mana)

	# agora 3s SEM nada (fora de combate) → regen lenta liga
	_tick(m, 3.0)
	print("+3.0s fora de combate: %.1f  → esperado subindo (~44)" % m.current_mana)

	# golpe de cajado devolve 12 na hora (agressão)
	m.restore(12.0)
	print("após 1 golpe de cajado (+12): %.1f" % m.current_mana)

	var ok: bool = m.current_mana > 50.0 and m.current_mana < 70.0
	print("\nRESULTADO: %s" % ("✓ híbrido coerente" if ok else "⚠ revisar tuning"))
	quit(0)

func _tick(m, secs: float) -> void:
	# simula frames de ~60fps
	var step := 1.0 / 60.0
	var t := 0.0
	while t < secs:
		m._process(step)
		t += step
