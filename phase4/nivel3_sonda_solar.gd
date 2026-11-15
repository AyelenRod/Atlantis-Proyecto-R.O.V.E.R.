extends Node2D

@export var escena_fondo_3d: PackedScene = preload("fondo_orbital.tscn")
const GuiaTrayectoriaScript = preload("res://phase4/guia_trayectoria.gd")
const HudOperacionScript = preload("res://phase4/hud_operacion.gd")
const EfectosFalloScript = preload("res://phase4/efectos_fallo.gd")

enum EstadoNivel3 {
	SOLAR_ACTIVA,
	JUPITER_ASTEROIDES,
	JUPITER_LUNAS,
	COMPLETADO,
	FALLIDO,
}

var _destino: String = "sonda_solar" # "sonda_solar" | "jupiter"
var _estado: EstadoNivel3 = EstadoNivel3.SOLAR_ACTIVA
var _fondo_3d: Node3D = null
var _guia: GuiaTrayectoria
var _hud: HudOperacion
var _efectos: EfectosFallo

# Variables comunes
var _tiempo_transcurrido: float = 0.0
var _integridad: float = 100.0
var _perfil_nave: Dictionary = {}

# Variables Modo SONDA SOLAR (intacto)
var _sol_pos: Vector2 = Vector2(-120, 360)
var _ruta_orbital: PackedVector2Array = PackedVector2Array()
var _progreso_orbita: float = 0.0
var _sonda_pos: Vector2 = Vector2.ZERO
var _sonda_ang: float = PI
var _desfase_trayectoria: float = 0.0
var _temperatura_c: float = 420.0
var _temp_maxima_c: float = 420.0
var _temp_limite_c: float = 1550.0
var _datos_recopilados: float = 0.0
var _midiendo_ahora: bool = false

var _nave_jup_pos: Vector2 = Vector2(140, 280)
var _progreso_jupiter: float = 0.0 # 0.0..0.5 asteroides, 0.5..1.0 lunas
var _asteroides: Array[Dictionary] = []
var _timer_spawn_asteroide: float = 0.0
var _inmunidad_impacto: float = 0.0
var _asteroides_evitados: int = 0
var _lunas_jupiter: Array[Dictionary] = []
var _datos_jupiter_pct: float = 0.0
var _escaneando_lunas: bool = false


func _ready() -> void:
	_cargar_configuracion()
	_configurar_escena()


func _cargar_configuracion() -> void:
	if has_node("/root/Phase4Manager"):
		var mgr := get_node("/root/Phase4Manager")
		_perfil_nave = mgr.obtener_perfil_nave()
		_destino = str(mgr.get("destino_nivel3"))
	else:
		_perfil_nave = {"rotacion_vel": 2.9, "escudo_max": 1550.0, "empuje": 280.0}
		_destino = "sonda_solar"

	_temp_limite_c = float(_perfil_nave.get("escudo_max", 1550.0))
	_estado = EstadoNivel3.JUPITER_ASTEROIDES if _destino == "jupiter" else EstadoNivel3.SOLAR_ACTIVA


func _configurar_escena() -> void:
	var vp := get_viewport_rect().size

	_fondo_3d = _activar_fondo_orbital_3d()
	_mostrar_astro_3d("jupiter" if _destino == "jupiter" else "sol", _fondo_3d)

	_guia = GuiaTrayectoriaScript.new()
	add_child(_guia)

	_efectos = EfectosFalloScript.new()
	add_child(_efectos)

	_hud = HudOperacionScript.new()
	add_child(_hud)

	if _destino == "sonda_solar":
		_sol_pos = Vector2(-vp.x * 0.14, vp.y * 0.52)
		_ruta_orbital = PackedVector2Array([
			Vector2(vp.x * 0.56, vp.y * 0.86),
			Vector2(vp.x * 0.32, vp.y * 0.68),
			Vector2(vp.x * 0.24, vp.y * 0.50),
			Vector2(vp.x * 0.34, vp.y * 0.28),
			Vector2(vp.x * 0.58, vp.y * 0.14),
		])
		_sonda_pos = _ruta_orbital[0]
		_guia.color_puntos = Color("#F59E0B")
		_guia.color_objetivo = Color("#38BDF8")
		_guia.configurar_ruta(_ruta_orbital, _ruta_orbital[_ruta_orbital.size() - 1], 44.0)
		_hud.configurar_titulo(
			"NIVEL 3 · SONDA SOLAR (CORONA EXTREMA)",
			"Flechas Izq/Der: Orienta escudo de carbono al Sol · Mantén F o ESPACIO cerca de la corona para medir plasma"
		)
	else:
		_nave_jup_pos = Vector2(vp.x * 0.14, vp.y * 0.52)
		_lunas_jupiter = [
			{"nombre": "Ío", "pos": Vector2(vp.x * 0.28, vp.y * 0.30), "radio": 22.0, "color": Color("#FACC15"), "datos": 0.0},
			{"nombre": "Europa", "pos": Vector2(vp.x * 0.45, vp.y * 0.62), "radio": 20.0, "color": Color("#BAE6FD"), "datos": 0.0},
			{"nombre": "Ganímedes", "pos": Vector2(vp.x * 0.60, vp.y * 0.36), "radio": 26.0, "color": Color("#CBD5E1"), "datos": 0.0},
		]
		_guia.color_puntos = Color("#38BDF8")
		_guia.color_objetivo = Color("#F59E0B")
		_guia.configurar_ruta(
			PackedVector2Array([Vector2(vp.x * 0.10, vp.y * 0.52), Vector2(vp.x * 0.66, vp.y * 0.52)]),
			Vector2(vp.x * 0.66, vp.y * 0.52),
			38.0
		)
		_hud.configurar_titulo(
			"NIVEL 3 · JÚPITER (A: CINTURÓN DE ASTEROIDES · B: LUNAS)",
			"Etapa A: Flechas para esquivar asteroides · Etapa B: Acércate a Ío/Europa/Ganímedes y mantén F o ESPACIO"
		)


func _physics_process(delta: float) -> void:
	if _estado == EstadoNivel3.COMPLETADO or _estado == EstadoNivel3.FALLIDO:
		return

	_tiempo_transcurrido += delta

	if _estado == EstadoNivel3.SOLAR_ACTIVA:
		_procesar_sonda_solar(delta)
	elif _estado == EstadoNivel3.JUPITER_ASTEROIDES:
		_procesar_jupiter_asteroides(delta)
	elif _estado == EstadoNivel3.JUPITER_LUNAS:
		_procesar_jupiter_lunas(delta)

	queue_redraw()


# =============================================================================
# MODO 1: SONDA SOLAR (INTACTO)
# =============================================================================
func _procesar_sonda_solar(delta: float) -> void:
	var factor_corona := 1.0 - clampf(absf(_progreso_orbita - 0.5) * 2.0, 0.0, 1.0)
	var vel_avance := 0.036 + factor_corona * 0.022
	_progreso_orbita = minf(1.0, _progreso_orbita + vel_avance * delta)

	if Input.is_action_pressed("p4_arriba"):
		_desfase_trayectoria = clampf(_desfase_trayectoria - 60.0 * delta, -45.0, 45.0)
	if Input.is_action_pressed("p4_abajo"):
		_desfase_trayectoria = clampf(_desfase_trayectoria + 60.0 * delta, -45.0, 45.0)

	_sonda_pos = _evaluar_ruta(_progreso_orbita) + Vector2(_desfase_trayectoria, 0.0)
	

	var rot_vel := float(_perfil_nave.get("rotacion_vel", 2.9))
	if Input.is_action_pressed("p4_izquierda"):
		_sonda_ang -= rot_vel * delta
	if Input.is_action_pressed("p4_derecha"):
		_sonda_ang += rot_vel * delta
	_sonda_ang = wrapf(_sonda_ang, -PI, PI)

	var dir_al_sol := (_sol_pos - _sonda_pos).normalized()
	var dir_escudo := Vector2.RIGHT.rotated(_sonda_ang)
	var alineacion_escudo := clampf(dir_escudo.dot(dir_al_sol), -1.0, 1.0)
	var protegido := alineacion_escudo >= 0.85

	var calor_base := 260.0 + factor_corona * 1180.0
	var penalizacion_exposicion := (1.0 - maxf(0.0, alineacion_escudo)) * (700.0 + factor_corona * 1300.0)
	var temp_objetivo := calor_base + penalizacion_exposicion
	_temperatura_c = lerpf(_temperatura_c, temp_objetivo, 2.5 * delta)
	_temp_maxima_c = maxf(_temp_maxima_c, _temperatura_c)

	if not protegido and factor_corona > 0.25:
		_integridad = maxf(0.0, _integridad - (16.0 * factor_corona) * delta)

	if _temperatura_c >= _temp_limite_c or _integridad <= 0.0:
		_detonar_fallo("Sobrecarga térmica: el escudo no cubrió el casco frente a la corona solar.", _sonda_pos)
		return

	_midiendo_ahora = (Input.is_action_pressed("p4_medir") or Input.is_action_pressed("p4_accion")) and protegido
	if _midiendo_ahora:
		var tasa_ciencia := 14.0 + factor_corona * 18.0
		_datos_recopilados = minf(100.0, _datos_recopilados + tasa_ciencia * delta)

	if _progreso_orbita >= 1.0:
		if _datos_recopilados >= 75.0:
			_finalizar_exito_solar()
		else:
			_detonar_fallo("Datos científicos insuficientes (%.0f%% < 75%% requerido)." % _datos_recopilados, _sonda_pos)
		return

	_hud.actualizar_progreso(_progreso_orbita * 100.0)
	var col_escudo := Color("#34D399") if protegido else Color("#F87171")
	var col_temp := Color("#38BDF8") if _temperatura_c < 900.0 else (Color("#F59E0B") if _temperatura_c < 1350.0 else Color("#F87171"))
	_hud.actualizar_telemetria([
		{"etiqueta": "Modo Nivel 3", "valor": "SONDA SOLAR", "color": Color("#F59E0B")},
		{"etiqueta": "Escudo térmico", "valor": "ALINEADO" if protegido else "EXPUESTO", "color": col_escudo},
		{"etiqueta": "Temperatura escudo", "valor": "%d °C / %d °C" % [roundi(_temperatura_c), roundi(_temp_limite_c)], "color": col_temp},
		{"etiqueta": "Integridad casco", "valor": "%.0f%%" % _integridad, "color": Color("#E2E8F0")},
		{"etiqueta": "Datos científicos", "valor": "%.0f%%" % _datos_recopilados, "color": Color("#F59E0B")},
		{"etiqueta": "Sensores activos", "valor": "MIDIENDO" if _midiendo_ahora else "EN ESPERA (F)", "color": Color("#38BDF8")},
	])


func _evaluar_ruta(t: float) -> Vector2:
	var n := _ruta_orbital.size() - 1
	var seg_f := clampf(t * float(n), 0.0, float(n) - 0.0001)
	var idx := int(floor(seg_f))
	var local_t := seg_f - float(idx)
	return _ruta_orbital[idx].lerp(_ruta_orbital[idx + 1], local_t)


# =============================================================================
# MODO 2: JÚPITER — SUB-MISIÓN A (CINTURÓN DE ASTEROIDES) + B (LUNAS)
# =============================================================================
func _mover_nave_jupiter(delta: float) -> void:
	var vp := get_viewport_rect().size
	var vel := 215.0 + (float(_perfil_nave.get("empuje", 280.0)) - 220.0) * 0.45
	var dir := Vector2.ZERO
	if Input.is_action_pressed("p4_izquierda"):
		dir.x -= 1.0
	if Input.is_action_pressed("p4_derecha"):
		dir.x += 1.0
	if Input.is_action_pressed("p4_arriba"):
		dir.y -= 1.0
	if Input.is_action_pressed("p4_abajo"):
		dir.y += 1.0
	if dir.length() > 0.0:
		_nave_jup_pos += dir.normalized() * vel * delta
	_nave_jup_pos.x = clampf(_nave_jup_pos.x, 42.0, vp.x * 0.68)
	_nave_jup_pos.y = clampf(_nave_jup_pos.y, 92.0, vp.y - 42.0)
	


func _procesar_jupiter_asteroides(delta: float) -> void:
	var vp := get_viewport_rect().size
	_mover_nave_jupiter(delta)
	_inmunidad_impacto = maxf(0.0, _inmunidad_impacto - delta)

	# Progreso del cinturón (0% -> 50% del nivel)
	_progreso_jupiter = minf(0.50, _progreso_jupiter + 0.028 * delta)

	# Generar asteroides desde el borde derecho de la zona jugable
	_timer_spawn_asteroide -= delta
	if _timer_spawn_asteroide <= 0.0:
		_timer_spawn_asteroide = randf_range(0.42, 0.78)
		_asteroides.append({
			"pos": Vector2(vp.x * 0.72, randf_range(95.0, vp.y - 55.0)),
			"vel": Vector2(-randf_range(175.0, 290.0), randf_range(-38.0, 38.0)),
			"radio": randf_range(13.0, 25.0),
			"rot": randf_range(0.0, TAU),
		})

	for i in range(_asteroides.size() - 1, -1, -1):
		var ast: Dictionary = _asteroides[i]
		var pos_a: Vector2 = ast["pos"]
		var vel_a: Vector2 = ast["vel"]
		pos_a += vel_a * delta
		ast["pos"] = pos_a
		ast["rot"] = float(ast["rot"]) + 1.8 * delta

		if pos_a.distance_to(_nave_jup_pos) <= float(ast["radio"]) + 14.0 and _inmunidad_impacto <= 0.0:
			_integridad = maxf(0.0, _integridad - 34.0)
			_inmunidad_impacto = 0.85
			_asteroides.remove_at(i)
			if _integridad <= 0.0:
				_detonar_fallo("Destrucción en el cinturón de asteroides rumbo a Júpiter.", _nave_jup_pos)
				return
			continue

		if pos_a.x < -40.0:
			_asteroides.remove_at(i)
			_asteroides_evitados += 1

	if _progreso_jupiter >= 0.50:
		_asteroides.clear()
		_estado = EstadoNivel3.JUPITER_LUNAS
		_actualizar_guia_lunas()

	_hud.actualizar_progreso(_progreso_jupiter * 100.0)
	_hud.actualizar_telemetria([
		{"etiqueta": "Sub-misión A", "valor": "Cinturón Asteroides", "color": Color("#F59E0B")},
		{"etiqueta": "Integridad casco", "valor": "%.0f%%" % _integridad, "color": Color("#34D399") if _integridad > 45.0 else Color("#F87171")},
		{"etiqueta": "Asteroides sorteados", "valor": "%d" % _asteroides_evitados, "color": Color("#38BDF8")},
		{"etiqueta": "Tránsito a Júpiter", "valor": "%d%%" % roundi((_progreso_jupiter / 0.50) * 100.0), "color": Color("#E2E8F0")},
	])


func _procesar_jupiter_lunas(delta: float) -> void:
	_mover_nave_jupiter(delta)
	_escaneando_lunas = Input.is_action_pressed("p4_medir") or Input.is_action_pressed("p4_accion")

	var suma_datos := 0.0
	var lunas_completas := 0
	for luna in _lunas_jupiter:
		var l_pos: Vector2 = luna["pos"]
		var l_rad := float(luna["radio"])
		if _escaneando_lunas and _nave_jup_pos.distance_to(l_pos) <= l_rad + 42.0:
			luna["datos"] = minf(100.0, float(luna["datos"]) + 60.0 * delta)
		if float(luna["datos"]) >= 100.0:
			lunas_completas += 1
		suma_datos += float(luna["datos"])

	_datos_jupiter_pct = suma_datos / float(_lunas_jupiter.size())
	_progreso_jupiter = 0.50 + (_datos_jupiter_pct / 100.0) * 0.50
	_actualizar_guia_lunas()

	if _datos_jupiter_pct >= 99.5:
		_datos_jupiter_pct = 100.0
		_finalizar_exito_jupiter(lunas_completas)
		return

	_hud.actualizar_progreso(_progreso_jupiter * 100.0)
	_hud.actualizar_telemetria([
		{"etiqueta": "Sub-misión B", "valor": "Lunas de Júpiter", "color": Color("#38BDF8")},
		{"etiqueta": "Lunas escaneadas", "valor": "%d / %d" % [lunas_completas, _lunas_jupiter.size()], "color": Color("#34D399")},
		{"etiqueta": "Datos transmitidos", "valor": "%.0f%%" % _datos_jupiter_pct, "color": Color("#F59E0B")},
		{"etiqueta": "Integridad casco", "valor": "%.0f%%" % _integridad, "color": Color("#E2E8F0")},
		{"etiqueta": "Escáner orbital", "valor": "TRANSMITIENDO" if _escaneando_lunas else "MANTÉN F/ESPACIO", "color": Color("#38BDF8")},
	])


func _actualizar_guia_lunas() -> void:
	var pts := PackedVector2Array([_nave_jup_pos])
	var meta := _nave_jup_pos
	for luna in _lunas_jupiter:
		var lp: Vector2 = luna["pos"]
		if float(luna["datos"]) < 100.0:
			pts.append(lp)
			meta = lp
			break
	_guia.configurar_ruta(pts, meta, 44.0)


func _finalizar_exito_solar() -> void:
	_estado = EstadoNivel3.COMPLETADO
	var metricas := {
		"titulo_nivel": "Nivel 3: Sonda Solar (Corona Extrema)",
		"destino_operacion": "Sonda Solar",
		"tiempo_s": snappedf(_tiempo_transcurrido, 0.1),
		"integridad_pct": snappedf(_integridad, 0.1),
		"temperatura_max_c": roundi(_temp_maxima_c),
		"datos_cientificos_pct": snappedf(_datos_recopilados, 0.1),
	}
	await get_tree().create_timer(0.8).timeout
	if has_node("/root/Phase4Manager"):
		get_node("/root/Phase4Manager").completar_nivel(metricas)


func _finalizar_exito_jupiter(lunas_ok: int) -> void:
	_estado = EstadoNivel3.COMPLETADO
	var metricas := {
		"titulo_nivel": "Nivel 3: Júpiter (Asteroides + Lunas Galileanas)",
		"destino_operacion": "Júpiter",
		"tiempo_s": snappedf(_tiempo_transcurrido, 0.1),
		"integridad_pct": snappedf(_integridad, 0.1),
		"asteroides_evitados": _asteroides_evitados,
		"lunas_escaneadas": "%d / %d (Ío, Europa, Ganímedes)" % [lunas_ok, _lunas_jupiter.size()],
		"datos_cientificos_pct": snappedf(_datos_jupiter_pct, 0.1),
	}
	await get_tree().create_timer(0.8).timeout
	if has_node("/root/Phase4Manager"):
		get_node("/root/Phase4Manager").completar_nivel(metricas)


func _detonar_fallo(motivo: String, pos_explosion: Vector2) -> void:
	if _estado == EstadoNivel3.FALLIDO:
		return
	_estado = EstadoNivel3.FALLIDO
	_efectos.detonar_explosion(pos_explosion, self)
	var metricas := {
		"titulo_nivel": "Nivel 3: Sonda Solar" if _destino == "sonda_solar" else "Nivel 3: Júpiter",
		"destino_operacion": "Sonda Solar" if _destino == "sonda_solar" else "Júpiter",
		"tiempo_s": snappedf(_tiempo_transcurrido, 0.1),
		"integridad_pct": 0.0,
		"datos_cientificos_pct": snappedf(_datos_recopilados if _destino == "sonda_solar" else _datos_jupiter_pct, 0.1),
	}
	await get_tree().create_timer(1.3).timeout
	if has_node("/root/Phase4Manager"):
		get_node("/root/Phase4Manager").fallar_mision(motivo, metricas)


func _draw() -> void:
	if _estado == EstadoNivel3.FALLIDO:
		return

	if _destino == "sonda_solar":
		_dibujar_sonda_solar()
	else:
		_dibujar_mision_jupiter()


func _dibujar_sonda_solar() -> void:
	var dir_sol := (_sonda_pos - _sol_pos).normalized()
	for i in range(-1, 2):
		var offset := dir_sol.orthogonal() * float(i) * 18.0
		draw_line(_sonda_pos - dir_sol * 85.0 + offset, _sonda_pos - dir_sol * 28.0 + offset, Color(1.0, 0.65, 0.22, 0.35), 2.0)

	draw_set_transform(_sonda_pos, _sonda_ang, Vector2.ONE)
	if _midiendo_ahora:
		draw_arc(Vector2.ZERO, 34.0, -0.7, 0.7, 24, Color("#38BDF8"), 2.5, true)

	draw_colored_polygon(PackedVector2Array([
		Vector2(-24, -7), Vector2(4, -9), Vector2(4, 9), Vector2(-24, 7)
	]), Color("#CBD5E1"))
	draw_rect(Rect2(-18, -19, 8, 10), Color("#2563EB"))
	draw_rect(Rect2(-18, 9, 8, 10), Color("#2563EB"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, -22), Vector2(18, -18), Vector2(18, 18), Vector2(8, 22)
	]), Color("#1E293B"))
	draw_polyline(PackedVector2Array([Vector2(18, -18), Vector2(18, 18)]), Color("#F59E0B"), 3.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _dibujar_mision_jupiter() -> void:
	if _estado == EstadoNivel3.JUPITER_ASTEROIDES:
		for ast in _asteroides:
			var ap: Vector2 = ast["pos"]
			var r := float(ast["radio"])
			var rot := float(ast["rot"])
			draw_set_transform(ap, rot, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-r, -r * 0.3), Vector2(-r * 0.2, -r), Vector2(r * 0.8, -r * 0.6),
				Vector2(r, r * 0.4), Vector2(0, r * 0.9), Vector2(-r * 0.8, r * 0.5)
			]), Color("#78716C"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _estado == EstadoNivel3.JUPITER_LUNAS:
		for luna in _lunas_jupiter:
			var lp: Vector2 = luna["pos"]
			var lr := float(luna["radio"])
			var lc: Color = luna["color"]
			var datos := float(luna["datos"])
			draw_circle(lp, lr, lc)
			draw_arc(lp, lr + 14.0, 0.0, TAU, 32, Color(0.22, 0.74, 0.97, 0.35), 1.5)
			draw_arc(lp, lr + 14.0, -PI * 0.5, -PI * 0.5 + TAU * (datos / 100.0), 32, Color("#34D399"), 3.5)

	# Dibujar Nave Exploradora en Júpiter
	var parpadeo := _inmunidad_impacto > 0.0 and int(_tiempo_transcurrido * 16.0) % 2 == 0
	if not parpadeo:
		draw_set_transform(_nave_jup_pos, 0.0, Vector2.ONE)
		if _escaneando_lunas and _estado == EstadoNivel3.JUPITER_LUNAS:
			draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 28, Color("#38BDF8"), 2.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(22, 0), Vector2(-14, -12), Vector2(-8, 0), Vector2(-14, 12)
		]), Color("#E2E8F0"))
		draw_circle(Vector2(2, 0), 4.5, Color("#38BDF8"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
func _activar_fondo_orbital_3d() -> Node3D:
	if escena_fondo_3d == null:
		return null

	var contenedor := SubViewportContainer.new()
	contenedor.name = "FondoOrbital3DContainer"
	contenedor.size = get_viewport_rect().size
	contenedor.position = Vector2.ZERO
	contenedor.stretch = true
	contenedor.z_index = -1
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(contenedor)
	move_child(contenedor, 0)

	var viewport_3d := SubViewport.new()
	viewport_3d.own_world_3d = true
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	contenedor.add_child(viewport_3d)

	var instancia: Node = escena_fondo_3d.instantiate()
	viewport_3d.add_child(instancia)
	return instancia as Node3D


func _mostrar_astro_3d(destino: String, raiz_fondo_3d: Node3D) -> void:
	if raiz_fondo_3d == null:
		return
	for nombre in ["AstroTierra", "AstroLuna", "AstroMarte", "AstroJupiter", "AstroSol"]:
		var malla: MeshInstance3D = raiz_fondo_3d.find_child(nombre, true, false) as MeshInstance3D
		if malla != null:
			malla.visible = false
	var objetivo: String = "AstroJupiter" if destino == "jupiter" else "AstroSol"
	var malla_activa: MeshInstance3D = raiz_fondo_3d.find_child(objetivo, true, false) as MeshInstance3D
	if malla_activa != null:
		malla_activa.visible = true
