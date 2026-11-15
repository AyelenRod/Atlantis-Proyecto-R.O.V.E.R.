extends Node2D

@export var escena_fondo_3d: PackedScene = preload("fondo_orbital.tscn")
const GuiaTrayectoriaScript = preload("res://phase4/guia_trayectoria.gd")
const HudOperacionScript = preload("res://phase4/hud_operacion.gd")
const EfectosFalloScript = preload("res://phase4/efectos_fallo.gd")

enum EtapaNivel2 {
	ENTRADA,
	PARACAIDAS_O_FRENADO,
	RETROCOHETES_SKYCRANE,
	SUBMISION_LUNA_CIENCIA,
	SUBMISION_MARTE_LANZAR_ROVER,
	SUBMISION_MARTE_ROVER_RUTA,
	COMPLETADO,
	FALLIDO,
}

var _destino: String = "luna" # "luna" | "marte"
var _etapa: EtapaNivel2 = EtapaNivel2.ENTRADA
var _fondo_3d: Node3D = null
var _guia: GuiaTrayectoria
var _hud: HudOperacion
var _efectos: EfectosFallo

# Estado del aterrizaje base
var _nave_pos: Vector2 = Vector2(360, 110)
var _nave_vel: Vector2 = Vector2(15, 68)
var _nave_ang: float = 0.0
var _plataforma_pos: Vector2 = Vector2(460, 620)
var _suelo_y: float = 620.0
var _combustible: float = 100.0
var _gravedad: float = 52.0
var _tiempo_transcurrido: float = 0.0
var _apertura_paracaidas: float = 0.0
var _empuje_retro: bool = false
var _altura_inicial: float = 500.0
var _vel_contacto_ms: float = 0.0
var _perfil_nave: Dictionary = {}

var _escaner_x: float = 460.0
var _nodos_ciencia_luna: Array[Dictionary] = []
var _ciencia_luna_pct: float = 0.0
var _escaneando_luna: bool = false

var _rampa_despliegue: float = 0.0
var _rover_pos: Vector2 = Vector2.ZERO
var _rover_vel_y: float = 0.0
var _rocas_marte: Array[Dictionary] = []
var _baliza_marte_x: float = 820.0
var _transmision_rover_pct: float = 0.0
var _rover_danado_cooldown: float = 0.0
var _integridad_rover: float = 100.0


func _ready() -> void:
	_cargar_configuracion()
	_configurar_escena()


func _cargar_configuracion() -> void:
	if has_node("/root/Phase4Manager"):
		var mgr := get_node("/root/Phase4Manager")
		_perfil_nave = mgr.obtener_perfil_nave()
		_destino = str(mgr.get("destino_nivel2"))
	else:
		_perfil_nave = {"empuje": 280.0, "rotacion_vel": 2.9, "combustible_max": 100.0, "tolerancia_aterrizaje": 4.6}
		_destino = "luna"

	_combustible = float(_perfil_nave.get("combustible_max", 100.0))
	_gravedad = 36.0 if _destino == "luna" else 52.0


func _configurar_escena() -> void:
	var vp := get_viewport_rect().size
	_suelo_y = vp.y - 72.0
	_nave_pos = Vector2(vp.x * 0.22, 110.0)
	_plataforma_pos = Vector2(vp.x * 0.34 if _destino == "marte" else vp.x * 0.40, _suelo_y)
	_altura_inicial = maxf(1.0, _suelo_y - _nave_pos.y)

	# Configurar puntos científicos para Luna
	_nodos_ciencia_luna = [
		{"nombre": "Basalto Lunar", "x": vp.x * 0.16, "progreso": 0.0},
		{"nombre": "Hielo en Cráter", "x": vp.x * 0.38, "progreso": 0.0},
		{"nombre": "Regolito He-3", "x": vp.x * 0.58, "progreso": 0.0},
	]

	# Configurar ruta y rocas para Marte
	_baliza_marte_x = vp.x * 0.65
	_rocas_marte = [
		{"x": vp.x * 0.46, "r": 14.0},
		{"x": vp.x * 0.56, "r": 16.0},
	]

	_fondo_3d = _activar_fondo_orbital_3d()
	_mostrar_astro_3d(_destino, _fondo_3d)

	_guia = GuiaTrayectoriaScript.new()
	add_child(_guia)
	_actualizar_ruta_guia()

	_efectos = EfectosFalloScript.new()
	add_child(_efectos)

	_hud = HudOperacionScript.new()
	add_child(_hud)
	if _destino == "luna":
		_hud.configurar_titulo(
			"NIVEL 2 · LUNA (ATERRIZAJE + RECOLECCIÓN CIENTÍFICA)",
			"Fase 1: ESPACIO (frenado) + Flechas (posar) · Fase 2: Flechas + F/ESPACIO para recoger muestras"
		)
	else:
		_hud.configurar_titulo(
			"NIVEL 2 · MARTE (ATERRIZAJE + LANZAMIENTO DE ROVER)",
			"Fase 1: ESPACIO (paracaídas) + Flechas (posar) · Fase 2: ESPACIO (lanzar rover) + Flechas + F en baliza"
		)


func _physics_process(delta: float) -> void:
	if _etapa == EtapaNivel2.COMPLETADO or _etapa == EtapaNivel2.FALLIDO:
		return

	_tiempo_transcurrido += delta

	match _etapa:
		EtapaNivel2.ENTRADA, EtapaNivel2.PARACAIDAS_O_FRENADO, EtapaNivel2.RETROCOHETES_SKYCRANE:
			_procesar_aterrizaje_base(delta)
		EtapaNivel2.SUBMISION_LUNA_CIENCIA:
			_procesar_submision_luna(delta)
		EtapaNivel2.SUBMISION_MARTE_LANZAR_ROVER:
			_procesar_submision_marte_rampa(delta)
		EtapaNivel2.SUBMISION_MARTE_ROVER_RUTA:
			_procesar_submision_marte_rover(delta)

	_actualizar_ruta_guia()
	_actualizar_hud()
	queue_redraw()


func _procesar_aterrizaje_base(delta: float) -> void:
	var altitud := maxf(0.0, _suelo_y - _nave_pos.y)

	if _etapa == EtapaNivel2.ENTRADA:
		if Input.is_action_just_pressed("p4_accion") and altitud > 130.0:
			_etapa = EtapaNivel2.PARACAIDAS_O_FRENADO
	elif _etapa == EtapaNivel2.PARACAIDAS_O_FRENADO:
		_apertura_paracaidas = minf(1.0, _apertura_paracaidas + delta * 2.2)
		if altitud < 220.0 or Input.is_action_just_pressed("p4_accion"):
			_etapa = EtapaNivel2.RETROCOHETES_SKYCRANE
			_apertura_paracaidas = 0.0

	var rot_vel := float(_perfil_nave.get("rotacion_vel", 2.9))
	if Input.is_action_pressed("p4_izquierda"):
		_nave_ang -= rot_vel * 0.7 * delta
	if Input.is_action_pressed("p4_derecha"):
		_nave_ang += rot_vel * 0.7 * delta
	_nave_ang = clampf(_nave_ang, -0.85, 0.85)

	_nave_vel.y += _gravedad * delta

	if _etapa == EtapaNivel2.PARACAIDAS_O_FRENADO:
		var vel_objetivo := 36.0 if _destino == "luna" else 44.0
		_nave_vel.y = lerpf(_nave_vel.y, vel_objetivo, 2.8 * delta)
		_nave_vel.x = lerpf(_nave_vel.x, (_plataforma_pos.x - _nave_pos.x) * 0.35, 1.2 * delta)
	elif _etapa == EtapaNivel2.RETROCOHETES_SKYCRANE:
		_empuje_retro = false
		if Input.is_action_pressed("p4_arriba") and _combustible > 0.0:
			var empuje := float(_perfil_nave.get("empuje", 280.0)) * 0.42
			var dir := Vector2.UP.rotated(_nave_ang)
			_nave_vel += dir * empuje * delta
			_combustible = maxf(0.0, _combustible - 9.0 * delta)
			_empuje_retro = true
		_nave_vel.x = lerpf(_nave_vel.x, 0.0, 0.6 * delta)

	_nave_pos += _nave_vel * delta
	
	if _nave_pos.y >= _suelo_y - 18.0:
		_evaluar_contacto_suelo()


func _evaluar_contacto_suelo() -> void:
	_nave_pos.y = _suelo_y - 18.0
	_vel_contacto_ms = _nave_vel.y / 14.0
	var vel_max_segura := float(_perfil_nave.get("tolerancia_aterrizaje", 4.6))
	var en_plataforma := absf(_nave_pos.x - _plataforma_pos.x) <= 74.0
	var ang_deg := absf(rad_to_deg(_nave_ang))

	if _etapa == EtapaNivel2.ENTRADA:
		_detonar_fallo("Impacto sin activar etapa de frenado.")
	elif _vel_contacto_ms > vel_max_segura:
		_detonar_fallo("Velocidad de impacto excesiva (%.1f m/s > %.1f m/s)." % [_vel_contacto_ms, vel_max_segura])
	elif ang_deg > 12.0:
		_detonar_fallo("Inclinación crítica al tocar superficie (%.1f°)." % ang_deg)
	elif not en_plataforma:
		_detonar_fallo("Aterrizaje fuera de la plataforma segura.")
	else:
		# Aterrizaje exitoso -> iniciar segunda misión según destino (Luna vs Marte)
		_nave_vel = Vector2.ZERO
		_nave_ang = 0.0
		_empuje_retro = false
		if _destino == "luna":
			_escaner_x = _nave_pos.x
			_etapa = EtapaNivel2.SUBMISION_LUNA_CIENCIA
		else:
			_rover_pos = Vector2(_nave_pos.x + 26.0, _suelo_y - 8.0)
			_etapa = EtapaNivel2.SUBMISION_MARTE_LANZAR_ROVER


func _procesar_submision_luna(delta: float) -> void:
	var vp := get_viewport_rect().size
	if Input.is_action_pressed("p4_izquierda"):
		_escaner_x -= 185.0 * delta
	if Input.is_action_pressed("p4_derecha"):
		_escaner_x += 185.0 * delta
	_escaner_x = clampf(_escaner_x, vp.x * 0.08, vp.x * 0.68)

	_escaneando_luna = Input.is_action_pressed("p4_medir") or Input.is_action_pressed("p4_accion")
	var suma_prog := 0.0
	for nodo in _nodos_ciencia_luna:
		var dist := absf(_escaner_x - float(nodo["x"]))
		if _escaneando_luna and dist <= 32.0:
			nodo["progreso"] = minf(100.0, float(nodo["progreso"]) + 55.0 * delta)
		suma_prog += float(nodo["progreso"])

	_ciencia_luna_pct = suma_prog / float(_nodos_ciencia_luna.size())
	if _ciencia_luna_pct >= 99.5:
		_ciencia_luna_pct = 100.0
		_finalizar_exito()


func _procesar_submision_marte_rampa(delta: float) -> void:
	if Input.is_action_pressed("p4_accion") or Input.is_action_just_pressed("p4_accion"):
		_rampa_despliegue = minf(1.0, _rampa_despliegue + delta * 1.4)
	else:
		_rampa_despliegue = minf(1.0, _rampa_despliegue + delta * 0.4) if _rampa_despliegue > 0.1 else _rampa_despliegue

	if _rampa_despliegue >= 1.0:
		_rover_pos = Vector2(_nave_pos.x + 36.0, _suelo_y - 8.0)
		_etapa = EtapaNivel2.SUBMISION_MARTE_ROVER_RUTA


func _procesar_submision_marte_rover(delta: float) -> void:
	var vp := get_viewport_rect().size
	_rover_danado_cooldown = maxf(0.0, _rover_danado_cooldown - delta)

	if Input.is_action_pressed("p4_derecha"):
		_rover_pos.x += 135.0 * delta
	if Input.is_action_pressed("p4_izquierda"):
		_rover_pos.x -= 110.0 * delta
	_rover_pos.x = clampf(_rover_pos.x, _nave_pos.x + 20.0, vp.x * 0.69)

	if Input.is_action_just_pressed("p4_arriba") and _rover_pos.y >= _suelo_y - 9.0:
		_rover_vel_y = -175.0
	_rover_vel_y += 420.0 * delta
	_rover_pos.y = minf(_suelo_y - 8.0, _rover_pos.y + _rover_vel_y * delta)
	if _rover_pos.y >= _suelo_y - 8.0:
		_rover_vel_y = 0.0

	# Colisión con rocas marcianas
	for roca in _rocas_marte:
		var pos_roca := Vector2(float(roca["x"]), _suelo_y - float(roca["r"]) * 0.5)
		if _rover_pos.distance_to(pos_roca) <= float(roca["r"]) + 10.0 and _rover_danado_cooldown <= 0.0:
			_integridad_rover = maxf(0.0, _integridad_rover - 35.0)
			_rover_danado_cooldown = 0.9
			if _integridad_rover <= 0.0:
				_detonar_fallo("El Rover sufrió daños críticos contra rocas marcianas.")
				return

	# Transmisión al alcanzar la baliza geológica
	var en_baliza := absf(_rover_pos.x - _baliza_marte_x) <= 28.0
	if en_baliza and (Input.is_action_pressed("p4_medir") or Input.is_action_pressed("p4_accion")):
		_transmision_rover_pct = minf(100.0, _transmision_rover_pct + 55.0 * delta)
		if _transmision_rover_pct >= 100.0:
			_finalizar_exito()


func _actualizar_ruta_guia() -> void:
	if _etapa <= EtapaNivel2.RETROCOHETES_SKYCRANE:
		var p0 := _nave_pos
		var p2 := _plataforma_pos - Vector2(0, 18)
		var p1 := Vector2(lerpf(p0.x, p2.x, 0.5), lerpf(p0.y, p2.y, 0.45))
		_guia.configurar_ruta(PackedVector2Array([p0, p1, p2]), p2, 50.0)
	elif _etapa == EtapaNivel2.SUBMISION_LUNA_CIENCIA:
		var siguiente_x := _escaner_x
		for nodo in _nodos_ciencia_luna:
			if float(nodo["progreso"]) < 100.0:
				siguiente_x = float(nodo["x"])
				break
		var meta := Vector2(siguiente_x, _suelo_y - 12.0)
		_guia.configurar_ruta(PackedVector2Array([Vector2(_escaner_x, _suelo_y - 12.0), meta]), meta, 30.0)
	else:
		var meta_m := Vector2(_baliza_marte_x, _suelo_y - 12.0)
		var inicio_m := Vector2(_rover_pos.x, _suelo_y - 12.0)
		_guia.configurar_ruta(PackedVector2Array([inicio_m, meta_m]), meta_m, 34.0)


func _actualizar_hud() -> void:
	var prog_total := 0.0
	var nombre_etapa := ""

	if _etapa <= EtapaNivel2.RETROCOHETES_SKYCRANE:
		var prog_desc := clampf((_nave_pos.y - 110.0) / _altura_inicial, 0.0, 1.0)
		prog_total = prog_desc * 60.0
		if _etapa == EtapaNivel2.ENTRADA:
			nombre_etapa = "1. Entrada (Pulsa ESPACIO)"
		elif _etapa == EtapaNivel2.PARACAIDAS_O_FRENADO:
			nombre_etapa = "2. Frenado lunar" if _destino == "luna" else "2. Paracaídas activo"
		else:
			nombre_etapa = "3. Retrocohetes finales"
	elif _etapa == EtapaNivel2.SUBMISION_LUNA_CIENCIA:
		prog_total = 60.0 + _ciencia_luna_pct * 0.40
		nombre_etapa = "4. Muestreo lunar (%d%%)" % roundi(_ciencia_luna_pct)
	elif _etapa == EtapaNivel2.SUBMISION_MARTE_LANZAR_ROVER:
		prog_total = 60.0 + _rampa_despliegue * 12.0
		nombre_etapa = "4. Bajar rampa (ESPACIO)"
	elif _etapa == EtapaNivel2.SUBMISION_MARTE_ROVER_RUTA:
		var dist_norm := clampf(1.0 - absf(_baliza_marte_x - _rover_pos.x) / 360.0, 0.0, 1.0)
		prog_total = 72.0 + dist_norm * 18.0 + _transmision_rover_pct * 0.10
		nombre_etapa = "5. Rover hacia baliza (%d%%)" % roundi(_transmision_rover_pct)

	_hud.actualizar_progreso(prog_total)

	var altitud_m := maxf(0.0, (_suelo_y - 18.0 - _nave_pos.y) * 4.5)
	var vel_ms := _nave_vel.y / 14.0
	var col_vel := Color("#34D399") if vel_ms <= float(_perfil_nave.get("tolerancia_aterrizaje", 4.6)) else Color("#F87171")

	var filas: Array[Dictionary] = [
		{"etiqueta": "Destino Nivel 2", "valor": "LUNA" if _destino == "luna" else "MARTE", "color": Color("#38BDF8")},
		{"etiqueta": "Etapa activa", "valor": nombre_etapa, "color": Color("#F59E0B")},
		{"etiqueta": "Altitud superficie", "valor": "%.0f m" % altitud_m, "color": Color("#F8FAFC")},
		{"etiqueta": "Velocidad vertical", "valor": "%.1f m/s" % vel_ms, "color": col_vel},
		{"etiqueta": "Combustible retro", "valor": "%.0f%%" % _combustible, "color": Color("#38BDF8")},
	]

	if _destino == "luna" and _etapa == EtapaNivel2.SUBMISION_LUNA_CIENCIA:
		filas.append({"etiqueta": "Ciencia lunar", "valor": "%.0f%% (F/ESPACIO)" % _ciencia_luna_pct, "color": Color("#34D399")})
	elif _destino == "marte" and _etapa >= EtapaNivel2.SUBMISION_MARTE_LANZAR_ROVER:
		filas.append({"etiqueta": "Integridad Rover", "valor": "%.0f%%" % _integridad_rover, "color": Color("#34D399") if _integridad_rover > 40.0 else Color("#F87171")})

	_hud.actualizar_telemetria(filas)


func _finalizar_exito() -> void:
	_etapa = EtapaNivel2.COMPLETADO
	var metricas := {
		"titulo_nivel": "Nivel 2: Luna (Aterrizaje + Ciencia)" if _destino == "luna" else "Nivel 2: Marte (Aterrizaje + Rover)",
		"destino_operacion": "Luna" if _destino == "luna" else "Marte",
		"tiempo_s": snappedf(_tiempo_transcurrido, 0.1),
		"combustible_pct": snappedf(_combustible, 0.1),
		"integridad_pct": 100.0 if _destino == "luna" else snappedf(_integridad_rover, 0.1),
		"velocidad_impacto_ms": snappedf(_vel_contacto_ms, 0.2),
	}
	if _destino == "luna":
		metricas["datos_cientificos_pct"] = snappedf(_ciencia_luna_pct, 0.1)
	else:
		metricas["rover_desplegado"] = "Perseverance-Mini (Enlace activo)"

	await get_tree().create_timer(0.8).timeout
	if has_node("/root/Phase4Manager"):
		get_node("/root/Phase4Manager").completar_nivel(metricas)


func _detonar_fallo(motivo: String) -> void:
	if _etapa == EtapaNivel2.FALLIDO:
		return
	_etapa = EtapaNivel2.FALLIDO
	var foco := _rover_pos if _etapa == EtapaNivel2.SUBMISION_MARTE_ROVER_RUTA else _nave_pos
	_efectos.detonar_explosion(foco, self)
	var metricas := {
		"titulo_nivel": "Nivel 2: Luna" if _destino == "luna" else "Nivel 2: Marte",
		"destino_operacion": "Luna" if _destino == "luna" else "Marte",
		"tiempo_s": snappedf(_tiempo_transcurrido, 0.1),
		"combustible_pct": snappedf(_combustible, 0.1),
		"integridad_pct": 0.0,
	}
	await get_tree().create_timer(1.3).timeout
	if has_node("/root/Phase4Manager"):
		get_node("/root/Phase4Manager").fallar_mision(motivo, metricas)


func _draw() -> void:
	var vp := get_viewport_rect().size
	var col_suelo := Color("#333847") if _destino == "luna" else Color("#3A1D18")
	var col_borde := Color("#94A3B8") if _destino == "luna" else Color("#A8553A")

	# Superficie lunar o marciana
	draw_rect(Rect2(0, _suelo_y, vp.x, vp.y - _suelo_y), col_suelo)
	draw_line(Vector2(0, _suelo_y), Vector2(vp.x, _suelo_y), col_borde, 3.0)
	draw_rect(Rect2(_plataforma_pos.x - 68, _suelo_y - 6, 136, 8), Color("#F59E0B"))

	# Elementos de superficie según destino
	if _destino == "luna":
		for nodo in _nodos_ciencia_luna:
			var nx := float(nodo["x"])
			var prog := float(nodo["progreso"])
			var col_n := Color("#34D399") if prog >= 100.0 else Color("#38BDF8")
			draw_circle(Vector2(nx, _suelo_y - 8), 8.0, col_n)
			draw_arc(Vector2(nx, _suelo_y - 8), 16.0, -PI * 0.5, -PI * 0.5 + TAU * (prog / 100.0), 20, Color("#F59E0B"), 2.5)
	else:
		# Rocas y baliza marciana
		for roca in _rocas_marte:
			var rx := float(roca["x"])
			var rr := float(roca["r"])
			draw_colored_polygon(PackedVector2Array([
				Vector2(rx - rr, _suelo_y),
				Vector2(rx - rr * 0.4, _suelo_y - rr),
				Vector2(rx + rr * 0.6, _suelo_y - rr * 0.75),
				Vector2(rx + rr, _suelo_y),
			]), Color("#6B3728"))
		# Baliza objetivo
		draw_line(Vector2(_baliza_marte_x, _suelo_y), Vector2(_baliza_marte_x, _suelo_y - 36), Color("#38BDF8"), 3.0)
		draw_circle(Vector2(_baliza_marte_x, _suelo_y - 38), 6.0, Color("#34D399") if _transmision_rover_pct >= 100.0 else Color("#F59E0B"))

	if _etapa == EtapaNivel2.FALLIDO:
		return

	# Dibujar Nave / Módulo de aterrizaje
	draw_set_transform(_nave_pos, _nave_ang, Vector2.ONE)
	if _etapa == EtapaNivel2.PARACAIDAS_O_FRENADO and _apertura_paracaidas > 0.05:
		if _destino == "marte":
			var ancho := 54.0 * _apertura_paracaidas
			draw_line(Vector2(-12, -16), Vector2(-ancho, -68), Color("#CBD5E1"), 1.5)
			draw_line(Vector2(12, -16), Vector2(ancho, -68), Color("#CBD5E1"), 1.5)
			draw_arc(Vector2(0, -68), ancho, PI, TAU, 24, Color("#FB923C"), 8.0, true)
		else:
			# Pluma azul de frenado al vacío en Luna
			draw_colored_polygon(PackedVector2Array([
				Vector2(-10, 14), Vector2(0, 42 * _apertura_paracaidas), Vector2(10, 14)
			]), Color(0.35, 0.78, 1.0, 0.7))

	if _etapa == EtapaNivel2.RETROCOHETES_SKYCRANE and _empuje_retro:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-14, 14), Vector2(-18, 36 + randf() * 14.0), Vector2(-8, 14)
		]), Color(1.0, 0.58, 0.18, 0.9))
		draw_colored_polygon(PackedVector2Array([
			Vector2(8, 14), Vector2(18, 36 + randf() * 14.0), Vector2(14, 14)
		]), Color(1.0, 0.58, 0.18, 0.9))

	draw_line(Vector2(-14, 10), Vector2(-22, 20), Color("#94A3B8"), 2.5)
	draw_line(Vector2(14, 10), Vector2(22, 20), Color("#94A3B8"), 2.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, 10), Vector2(-12, -14), Vector2(12, -14), Vector2(18, 10)
	]), Color("#E2E8F0"))
	draw_circle(Vector2(0, -3), 5.0, Color("#38BDF8"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _etapa == EtapaNivel2.SUBMISION_LUNA_CIENCIA:
		draw_line(_nave_pos + Vector2(0, -6), Vector2(_escaner_x, _suelo_y - 26), Color("#38BDF8"), 2.0)
		draw_circle(Vector2(_escaner_x, _suelo_y - 22), 7.0, Color("#F59E0B"))
		if _escaneando_luna:
			draw_line(Vector2(_escaner_x, _suelo_y - 16), Vector2(_escaner_x, _suelo_y), Color("#34D399"), 3.0)
	elif _etapa >= EtapaNivel2.SUBMISION_MARTE_LANZAR_ROVER and _destino == "marte":
		# Rampa desplegada
		draw_line(_nave_pos + Vector2(16, 12), _nave_pos + Vector2(16 + 26 * _rampa_despliegue, 18), Color("#F59E0B"), 3.5)
		if _etapa >= EtapaNivel2.SUBMISION_MARTE_ROVER_RUTA:
			# Mars Rover con ruedas y mástil
			draw_rect(Rect2(_rover_pos - Vector2(14, 10), Vector2(28, 12)), Color("#E2E8F0"))
			draw_line(_rover_pos + Vector2(8, -10), _rover_pos + Vector2(8, -22), Color("#94A3B8"), 2.5)
			draw_circle(_rover_pos + Vector2(8, -23), 3.5, Color("#38BDF8"))
			draw_circle(_rover_pos + Vector2(-9, 4), 5.0, Color("#1E293B"))
			draw_circle(_rover_pos + Vector2(0, 4), 5.0, Color("#1E293B"))
			draw_circle(_rover_pos + Vector2(9, 4), 5.0, Color("#1E293B"))
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
	var objetivo: String = "AstroMarte" if destino == "marte" else "AstroLuna"
	var malla_activa: MeshInstance3D = raiz_fondo_3d.find_child(objetivo, true, false) as MeshInstance3D
	if malla_activa != null:
		malla_activa.visible = true
