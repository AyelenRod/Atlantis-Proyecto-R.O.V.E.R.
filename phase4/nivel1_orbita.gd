# Mover y alinear la nave con las flechas del teclado hasta entrar en la ventana orbital
extends Node2D

@export var escena_fondo_3d: PackedScene = preload("fondo_orbital.tscn")
const GuiaTrayectoriaScript = preload("res://phase4/guia_trayectoria.gd")
const HudOperacionScript = preload("res://phase4/hud_operacion.gd")
const EfectosFalloScript = preload("res://phase4/efectos_fallo.gd")

enum EstadoMision { ALINEANDO, ABRIENDO_COFIA, LIBERANDO_SATELITE, COMPLETADO, FALLIDO }

var _estado: EstadoMision = EstadoMision.ALINEANDO
var _fondo_3d: Node3D = null
var _guia: GuiaTrayectoria
var _hud: HudOperacion
var _efectos: EfectosFallo

# Estado físico de la nave (inicia siempre a la izquierda, despejada del panel lateral)
var _nave_pos: Vector2 = Vector2(180, 460)
var _nave_vel: Vector2 = Vector2.ZERO
var _nave_ang: float = -0.35
var _objetivo_pos: Vector2 = Vector2(680, 270)
var _objetivo_ang: float = 0.0

# Parámetros de misión
var _combustible: float = 100.0
var _integridad: float = 100.0
var _tiempo_transcurrido: float = 0.0
var _apertura_cofia: float = 0.0 # 0.0 a 1.0
var _despliegue_satelite: float = 0.0 # 0.0 a 1.0
var _satelite_pos_local: Vector2 = Vector2.ZERO
var _empuje_activo: bool = false
var _perfil_nave: Dictionary = {}
var _distancia_inicial: float = 1.0


func _ready() -> void:
	_cargar_perfil()
	_configurar_escena()


func _cargar_perfil() -> void:
	if has_node("/root/Phase4Manager"):
		_perfil_nave = get_node("/root/Phase4Manager").obtener_perfil_nave()
	else:
		_perfil_nave = {"empuje": 280.0, "rotacion_vel": 2.9, "combustible_max": 100.0}
	_combustible = float(_perfil_nave.get("combustible_max", 100.0))


func _configurar_escena() -> void:
	var vp := get_viewport_rect().size
	# Posición de inicio despejada del panel lateral derecho (que empieza en x = 73%)
	_nave_pos = Vector2(vp.x * 0.16, vp.y * 0.68)
	_objetivo_pos = Vector2(vp.x * 0.52, vp.y * 0.36)
	_distancia_inicial = maxf(1.0, _nave_pos.distance_to(_objetivo_pos))

	_fondo_3d = _activar_fondo_orbital_3d()
	_configurar_planeta_tarea1(_obtener_destino_seleccionado(), _fondo_3d)
	

	# Guía de trayectoria punteada hacia la ventana orbital
	_guia = GuiaTrayectoriaScript.new()
	_guia.mostrar_vector_angulo = true
	_guia.angulo_objetivo_rad = _objetivo_ang
	add_child(_guia)
	_actualizar_ruta_guia()

	# Efectos de explosión en fallo crítico
	_efectos = EfectosFalloScript.new()
	add_child(_efectos)

	# HUD lateral translúcido y barra naranja superior
	_hud = HudOperacionScript.new()
	add_child(_hud)
	_hud.configurar_titulo(
		"NIVEL 1 · ÓRBITA TERRESTRE (DESPLIEGUE SATELITAL)",
		"Controles: Flechas (Alinear posición y ángulo) · Mantén ESPACIO/E en la zona verde para abrir cofia"
	)


func _physics_process(delta: float) -> void:
	if _estado == EstadoMision.COMPLETADO or _estado == EstadoMision.FALLIDO:
		return

	_tiempo_transcurrido += delta
	_procesar_controles(delta)
	_actualizar_logica_protocolo(delta)
	_actualizar_ruta_guia()
	_actualizar_hud()
	queue_redraw()


func _procesar_controles(delta: float) -> void:
	var rot_vel := float(_perfil_nave.get("rotacion_vel", 2.9))
	var empuje := float(_perfil_nave.get("empuje", 280.0))

	if Input.is_action_pressed("p4_izquierda"):
		_nave_ang -= rot_vel * delta
	if Input.is_action_pressed("p4_derecha"):
		_nave_ang += rot_vel * delta
	_nave_ang = wrapf(_nave_ang, -PI, PI)

	_empuje_activo = false
	var dir_empuje := Vector2.ZERO
	if Input.is_action_pressed("p4_arriba") and _combustible > 0.0:
		dir_empuje += Vector2.RIGHT.rotated(_nave_ang)
		_empuje_activo = true
	if Input.is_action_pressed("p4_abajo") and _combustible > 0.0:
		dir_empuje -= Vector2.RIGHT.rotated(_nave_ang) * 0.65
		_empuje_activo = true

	if _empuje_activo:
		_nave_vel += dir_empuje * empuje * delta
		_combustible = maxf(0.0, _combustible - 6.5 * delta)

	_nave_vel = _nave_vel.lerp(Vector2.ZERO, 1.35 * delta)
	_nave_pos += _nave_vel * delta
	if _fondo_3d != null:
		for hijo in _fondo_3d.get_children():
			if hijo is MeshInstance3D and (hijo as MeshInstance3D).visible:
				(hijo as MeshInstance3D).rotate_y(0.08 * delta)

	# Límites seguros de cámara (si sale de órbita o choca con atmósfera baja -> fallo)
	var vp := get_viewport_rect().size
	if _nave_pos.x < 24.0 or _nave_pos.x > vp.x * 0.72 or _nave_pos.y < 70.0 or _nave_pos.y > vp.y - 30.0:
		_detonar_fallo("La nave abandonó el corredor orbital seguro.")
	elif _combustible <= 0.0 and _nave_vel.length() < 4.0 and not _esta_en_ventana():
		_detonar_fallo("Combustible RCS agotado antes de alcanzar la ventana orbital.")


func _esta_en_ventana() -> bool:
	var dist := _nave_pos.distance_to(_objetivo_pos)
	var diff_ang := absf(angle_difference(_nave_ang, _objetivo_ang))
	return dist <= 46.0 and diff_ang <= deg_to_rad(8.0) and _nave_vel.length() <= 45.0


func _actualizar_logica_protocolo(delta: float) -> void:
	var en_ventana := _esta_en_ventana()

	match _estado:
		EstadoMision.ALINEANDO:
			if en_ventana and Input.is_action_pressed("p4_accion"):
				_estado = EstadoMision.ABRIENDO_COFIA
		EstadoMision.ABRIENDO_COFIA:
			if not en_ventana:
				_estado = EstadoMision.ALINEANDO
				_apertura_cofia = maxf(0.0, _apertura_cofia - delta * 0.5)
			elif Input.is_action_pressed("p4_accion"):
				_apertura_cofia = minf(1.0, _apertura_cofia + delta * 0.75)
				if _apertura_cofia >= 1.0:
					_estado = EstadoMision.LIBERANDO_SATELITE
		EstadoMision.LIBERANDO_SATELITE:
			_despliegue_satelite = minf(1.0, _despliegue_satelite + delta * 0.65)
			_satelite_pos_local = Vector2(56.0 * _despliegue_satelite, -22.0 * _despliegue_satelite)
			if _despliegue_satelite >= 1.0:
				_finalizar_exito()


func _actualizar_ruta_guia() -> void:
	var p0 := _nave_pos
	var p2 := _objetivo_pos
	var p1 := (p0 + p2) * 0.5 + Vector2(0.0, -55.0)
	var puntos := PackedVector2Array([p0, p1, p2])
	_guia.configurar_ruta(puntos, _objetivo_pos, 46.0)


func _actualizar_hud() -> void:
	var dist := _nave_pos.distance_to(_objetivo_pos)
	var diff_deg := rad_to_deg(absf(angle_difference(_nave_ang, _objetivo_ang)))
	var prog_acercamiento := clampf(1.0 - (dist / _distancia_inicial), 0.0, 1.0) * 60.0
	var prog_protocolo := (_apertura_cofia * 20.0) + (_despliegue_satelite * 20.0)
	_hud.actualizar_progreso(prog_acercamiento + prog_protocolo)

	var col_dist := Color("#34D399") if dist <= 46.0 else Color("#F8FAFC")
	var col_ang := Color("#34D399") if diff_deg <= 8.0 else Color("#F59E0B")
	var txt_paso := "1. Alinear en ventana"
	if _estado == EstadoMision.ABRIENDO_COFIA:
		txt_paso = "2. Abriendo cofia (%d%%)" % roundi(_apertura_cofia * 100.0)
	elif _estado == EstadoMision.LIBERANDO_SATELITE:
		txt_paso = "3. Desplegando satélite"

	_hud.actualizar_telemetria([
		{"etiqueta": "Protocolo NASA", "valor": txt_paso, "color": Color("#F59E0B")},
		{"etiqueta": "Distancia ventana", "valor": "%.1f m" % dist, "color": col_dist},
		{"etiqueta": "Desviación angular", "valor": "%.1f°" % diff_deg, "color": col_ang},
		{"etiqueta": "Velocidad rel.", "valor": "%.1f m/s" % _nave_vel.length(), "color": Color("#E2E8F0")},
		{"etiqueta": "Combustible RCS", "valor": "%.0f%%" % _combustible, "color": Color("#38BDF8")},
		{"etiqueta": "Cofia abierta", "valor": "%d%%" % roundi(_apertura_cofia * 100.0), "color": Color("#C4B5FD")},
	])


func _finalizar_exito() -> void:
	_estado = EstadoMision.COMPLETADO
	var diff_deg := rad_to_deg(absf(angle_difference(_nave_ang, _objetivo_ang)))
	var metricas := {
		"titulo_nivel": "Nivel 1: Despliegue de Satélite en Órbita Terrestre",
		"tiempo_s": snappedf(_tiempo_transcurrido, 0.1),
		"combustible_pct": snappedf(_combustible, 0.1),
		"integridad_pct": snappedf(_integridad, 0.1),
		"precision_angular_deg": snappedf(diff_deg, 0.1),
		"satelite_desplegado": "Orbital-Sat IV (Estable)",
	}
	await get_tree().create_timer(0.8).timeout
	if has_node("/root/Phase4Manager"):
		get_node("/root/Phase4Manager").completar_nivel(metricas)


func _detonar_fallo(motivo: String) -> void:
	if _estado == EstadoMision.FALLIDO:
		return
	_estado = EstadoMision.FALLIDO
	_integridad = 0.0
	_efectos.detonar_explosion(_nave_pos, self)
	var metricas := {
		"titulo_nivel": "Nivel 1: Despliegue de Satélite en Órbita Terrestre",
		"tiempo_s": snappedf(_tiempo_transcurrido, 0.1),
		"combustible_pct": snappedf(_combustible, 0.1),
		"integridad_pct": 0.0,
	}
	await get_tree().create_timer(1.3).timeout
	if has_node("/root/Phase4Manager"):
		get_node("/root/Phase4Manager").fallar_mision(motivo, metricas)


func _draw() -> void:
	if _estado == EstadoMision.FALLIDO:
		return

	# Dibujar satélite desplegado y nave con cofia animada
	draw_set_transform(_nave_pos, _nave_ang, Vector2.ONE)

	# Chorro RCS cuando hay empuje activo
	if _empuje_activo:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-24, -5), Vector2(-42 - randf() * 12.0, 0), Vector2(-24, 5)
		]), Color(0.35, 0.80, 1.0, 0.85))

	# Satélite interior (visible al abrirse la cofia y al salir)
	if _apertura_cofia > 0.05:
		var sat_c := _satelite_pos_local + Vector2(10, 0)
		draw_rect(Rect2(sat_c - Vector2(7, 7), Vector2(14, 14)), Color("#F59E0B"))
		# Paneles solares del satélite
		var despliegue_paneles := clampf((_despliegue_satelite - 0.3) * 1.4, 0.15, 1.0)
		draw_rect(Rect2(sat_c + Vector2(-4, -7 - 16 * despliegue_paneles), Vector2(8, 16 * despliegue_paneles)), Color("#2563EB"))
		draw_rect(Rect2(sat_c + Vector2(-4, 7), Vector2(8, 16 * despliegue_paneles)), Color("#2563EB"))

	# Cuerpo principal de la nave
	var casco := PackedVector2Array([
		Vector2(-24, -12), Vector2(10, -12), Vector2(14, 0), Vector2(10, 12), Vector2(-24, 12)
	])
	draw_colored_polygon(casco, Color("#E2E8F0"))
	draw_polyline(casco + PackedVector2Array([casco[0]]), Color("#64748B"), 1.5, true)

	# Compuertas de la cofia (se abren visualmente según _apertura_cofia)
	var ang_puerta := _apertura_cofia * 1.15
	var p_sup := PackedVector2Array([
		Vector2(10, -12),
		Vector2(10, -12) + Vector2(22, 12).rotated(-ang_puerta),
		Vector2(10, -12) + Vector2(18, 0).rotated(-ang_puerta),
	])
	var p_inf := PackedVector2Array([
		Vector2(10, 12),
		Vector2(10, 12) + Vector2(22, -12).rotated(ang_puerta),
		Vector2(10, 12) + Vector2(18, 0).rotated(ang_puerta),
	])
	draw_colored_polygon(p_sup, Color("#CBD5E1"))
	draw_colored_polygon(p_inf, Color("#CBD5E1"))
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
func _obtener_destino_seleccionado() -> String:
	var raw: String = ""

	if has_node("/root/Phase4Manager"):
		var pm: Node = get_node("/root/Phase4Manager")
		var d_actual: Variant = pm.get("destino_actual")
		if d_actual != null and not str(d_actual).is_empty():
			raw = str(d_actual)
		else:
			var nivel_val: Variant = pm.get("nivel_actual")
			if nivel_val != null and int(nivel_val) == 2:
				raw = str(pm.get("destino_nivel2"))
			elif nivel_val != null and int(nivel_val) == 3:
				raw = str(pm.get("destino_nivel3"))

	if raw.is_empty() and has_node("/root/GameState"):
		var gs: Node = get_node("/root/GameState")
		var ficha: Variant = gs.get("ficha")
		if typeof(ficha) == TYPE_DICTIONARY:
			raw = str((ficha as Dictionary).get("destino", ""))

	raw = raw.to_lower()
	if "luna" in raw:
		return "luna"
	if "marte" in raw:
		return "marte"
	if "júpiter" in raw or "jupiter" in raw:
		return "jupiter"
	if "sol" in raw or "solar" in raw:
		return "sol"
	return "tierra"


func _configurar_planeta_tarea1(destino: String, raiz_fondo_3d: Node3D) -> void:
	if raiz_fondo_3d == null:
		return

	var astros: Dictionary = {
		"tierra": raiz_fondo_3d.find_child("AstroTierra", true, false) as MeshInstance3D,
		"luna": raiz_fondo_3d.find_child("AstroLuna", true, false) as MeshInstance3D,
		"marte": raiz_fondo_3d.find_child("AstroMarte", true, false) as MeshInstance3D,
		"jupiter": raiz_fondo_3d.find_child("AstroJupiter", true, false) as MeshInstance3D,
		"sol": raiz_fondo_3d.find_child("AstroSol", true, false) as MeshInstance3D,
	}

	for clave in astros.keys():
		var malla: MeshInstance3D = astros[clave] as MeshInstance3D
		if malla != null:
			malla.visible = false

	var clave_final: String = destino if astros.has(destino) and astros[destino] != null else "tierra"
	var malla_activa: MeshInstance3D = astros[clave_final] as MeshInstance3D
	if malla_activa != null:
		malla_activa.visible = true
