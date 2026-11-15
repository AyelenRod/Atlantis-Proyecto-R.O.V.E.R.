extends PhaseBase
## Interfaz de la Fase 4 (Sala de operación) dentro del hub.

const TemaEspacial = preload("res://tema_espacial.gd")
const EscenaFondo3D = preload("res://phase4/fondo_orbital.tscn")   # fondo 3D del destino (modelos del equipo)
const Datos = preload("res://fase1_datos.gd")   # nombres de salas, imágenes y MODO_PRUEBA

const COLOR_ACENTO := Color("ff9a4d")
const VERDE := Color("7be495")
const ROJO := Color("ff6b6b")
const AMARILLO := Color("ffd166")

# Cómo se muestran las métricas que entregan los niveles
const METRICAS := {
	"tiempo_s": ["Tiempo de operación", "%.1f s"],
	"combustible_pct": ["Combustible restante", "%.0f %%"],
	"integridad_pct": ["Integridad de la nave", "%.0f %%"],
	"precision_angular_deg": ["Precisión angular", "%.1f°"],
	"satelite_desplegado": ["Satélite desplegado", "%s"],
	"velocidad_impacto_ms": ["Velocidad de impacto", "%.1f m/s"],
	"inclinacion_final_deg": ["Inclinación al posarse", "%.1f°"],
	"temperatura_max_c": ["Temperatura máxima", "%d °C"],
	"datos_cientificos_pct": ["Datos científicos", "%.0f %%"],
	"flujos_capturados": ["Flujos capturados", "%s"],
	"destino_operacion": ["Destino", "%s"],
	"rover_desplegado": ["Rover", "%s"],
	"asteroides_evitados": ["Asteroides evitados", "%d"],
	"lunas_escaneadas": ["Lunas escaneadas", "%s"],
	"nave": ["Nave", "%s"],
}

var _nivel_elegido: int = 1
var _nivel_nodo: Node2D = null
var _fondo: Control
var _margen: MarginContainer
var _contenido: VBoxContainer
var _pista: Control
var _progreso: ProgressBar
var _cohete: TextureRect
var _etiquetas_fase: Array = []
var _aviso: Label


func _sola() -> bool:
	return get_tree().current_scene == self


func _ready() -> void:
	theme = TemaEspacial.crear()

	_fondo = _crear_fondo_orbital_3d()
	add_child(_fondo)

	_margen = MarginContainer.new()
	add_child(_margen)
	_margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margen.add_theme_constant_override("margin_top", 28 if _sola() else 64)
	_margen.add_theme_constant_override("margin_bottom", 28)
	resized.connect(_ajustar_margenes)
	_ajustar_margenes()

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 14)
	_margen.add_child(raiz)
	raiz.add_child(_crear_barra())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	raiz.add_child(scroll)

	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 14)
	scroll.add_child(_contenido)

	# El manager es autoload: se sincroniza con la partida actual y avisa cuando el nivel termina.
	Phase4Manager._sincronizar_con_game_state()
	_nivel_elegido = Phase4Manager.nivel_actual
	Phase4Manager.nivel_completado.connect(_al_completar)
	Phase4Manager.mision_fallida.connect(_al_fallar)

	# Directo al nivel de la dificultad elegida: el recuadro de controles es la única pantalla previa.
	_iniciar_nivel()


func _exit_tree() -> void:
	# El autoload sigue vivo cuando se cierra la ventana: desconectar para no llamar a un nodo liberado.
	if Phase4Manager.nivel_completado.is_connected(_al_completar):
		Phase4Manager.nivel_completado.disconnect(_al_completar)
	if Phase4Manager.mision_fallida.is_connected(_al_fallar):
		Phase4Manager.mision_fallida.disconnect(_al_fallar)


func _ajustar_margenes() -> void:
	var m := int(maxf(24.0, (size.x - 900.0) * 0.5))
	_margen.add_theme_constant_override("margin_left", m)
	_margen.add_theme_constant_override("margin_right", m)


# ---------------------------------------------------------------- barra de salas con cohete (igual que Fase 1)

func _cargar(ruta: String) -> Texture2D:
	if ruta != "" and ResourceLoader.exists(ruta):
		return load(ruta)
	return null


func _crear_barra() -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	var fila := HBoxContainer.new()
	for i in Datos.FASES.size():
		var l := Label.new()
		l.text = "%d. %s" % [i + 1, Datos.FASES[i]]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 14)
		l.modulate = COLOR_ACENTO if i == 3 else Color(1, 1, 1, 0.55)
		fila.add_child(l)
		_etiquetas_fase.append(l)
	caja.add_child(fila)

	_pista = Control.new()
	_pista.custom_minimum_size = Vector2(0, 50)
	caja.add_child(_pista)

	_progreso = ProgressBar.new()
	_progreso.max_value = 100
	_progreso.value = 60
	_progreso.show_percentage = false
	_progreso.custom_minimum_size = Vector2(0, 14)
	_progreso.anchor_left = 0.0
	_progreso.anchor_right = 1.0
	_progreso.anchor_top = 0.5
	_progreso.anchor_bottom = 0.5
	_progreso.offset_top = -7.0
	_progreso.offset_bottom = 7.0
	_pista.add_child(_progreso)

	_cohete = TextureRect.new()
	_cohete.texture = _cargar(Datos.IMG.get("cohete_horizontal", ""))
	_cohete.visible = _cohete.texture != null
	_cohete.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cohete.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cohete.custom_minimum_size = Vector2(64, 64)
	_cohete.size = Vector2(64, 64)
	_cohete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pista.add_child(_cohete)
	_progreso.value_changed.connect(_colocar_cohete)
	_pista.resized.connect(_colocar_cohete)
	return caja


func _colocar_cohete(_valor: float = 0.0) -> void:
	if _cohete == null or _pista == null or _progreso == null:
		return
	var borde: float = _pista.size.x * _progreso.value / _progreso.max_value
	var x := clampf(borde - _cohete.size.x * 0.85, -8.0, _pista.size.x - _cohete.size.x)
	_cohete.position = Vector2(x, (_pista.size.y - _cohete.size.y) * 0.5)


# ---------------------------------------------------------------- ayudas de interfaz (mismas que Fase 1)

func _limpiar() -> void:
	for c in _contenido.get_children():
		_contenido.remove_child(c)
		c.queue_free()


func _titulo(t: String, tam: int = 34, padre: Node = null) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color(0.72, 0.58, 1.0, 0.45))
	l.add_theme_constant_override("outline_size", 8)
	var negrita := TemaEspacial.fuente(true)
	if negrita:
		l.add_theme_font_override("font", negrita)
	(padre if padre else _contenido).add_child(l)
	return l


func _texto(t: String, tam: int = 18, padre: Node = null) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", tam)
	(padre if padre else _contenido).add_child(l)
	return l


func _boton(t: String, alto: int, accion: Callable, padre: Node = null) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, alto)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if t.contains("\n") else HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(accion)
	(padre if padre else _contenido).add_child(b)
	return b


# ---------------------------------------------------------------- el minijuego

func _tabla_controles() -> Control:
	var rejilla := GridContainer.new()
	rejilla.columns = 2
	rejilla.add_theme_constant_override("h_separation", 24)
	rejilla.add_theme_constant_override("v_separation", 8)
	for fila in Phase4Manager.controles_nivel(_nivel_elegido):
		var k := Label.new()
		k.text = String(fila[0])
		k.custom_minimum_size = Vector2(230, 0)
		k.modulate = AMARILLO
		k.add_theme_font_size_override("font_size", 16)
		rejilla.add_child(k)
		var v := Label.new()
		v.text = String(fila[1])
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_font_size_override("font_size", 16)
		rejilla.add_child(v)
	return rejilla


func _iniciar_nivel() -> void:
	Phase4Manager.iniciar_nivel(_nivel_elegido)
	_margen.visible = false
	_fondo.visible = false
	_nivel_nodo = Phase4Manager.crear_nivel()
	# z_index 1: el nivel dibuja su nave encima de su propio fondo (z -1 relativo) y del fondo de la ventana.
	_nivel_nodo.z_index = 1
	add_child(_nivel_nodo)
	# El nivel espera en pausa hasta que el jugador lea los controles.
	_nivel_nodo.process_mode = Node.PROCESS_MODE_DISABLED
	_mostrar_aviso_controles()


func _mostrar_aviso_controles() -> void:
	var velo := ColorRect.new()
	velo.name = "AvisoControles"
	velo.color = Color(0.02, 0.02, 0.06, 0.55)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.z_index = 2   # por encima del nivel (z 1)
	add_child(velo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.add_child(centro)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	panel.add_theme_stylebox_override("panel", TemaEspacial.caja_color(COLOR_ACENTO))
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	panel.add_child(caja)
	var info: Dictionary = Phase4Manager.info_nivel(_nivel_elegido)
	var t := _texto(String(info["titulo"]), 20, caja)
	t.modulate = COLOR_ACENTO
	var negrita := TemaEspacial.fuente(true)
	if negrita:
		t.add_theme_font_override("font", negrita)
	_texto("Controles de esta operación", 16, caja).modulate = Color(1, 1, 1, 0.7)
	caja.add_child(_tabla_controles())
	_texto("Esc vuelve a la base sin completar la operación.", 13, caja).modulate = Color(1, 1, 1, 0.5)
	var b := _boton("¡Entendido, comenzar!  (Enter)", 52, _cerrar_aviso_controles.bind(velo), caja)
	b.grab_focus()


func _cerrar_aviso_controles(velo: Node) -> void:
	if is_instance_valid(velo):
		velo.queue_free()
	if _nivel_nodo != null and is_instance_valid(_nivel_nodo):
		_nivel_nodo.process_mode = Node.PROCESS_MODE_INHERIT


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		var velo := get_node_or_null("AvisoControles")
		if velo != null:
			_cerrar_aviso_controles(velo)
			get_viewport().set_input_as_handled()


func _quitar_nivel() -> void:
	if _nivel_nodo != null and is_instance_valid(_nivel_nodo):
		_nivel_nodo.queue_free()
	_nivel_nodo = null
	var velo := get_node_or_null("AvisoControles")
	if velo != null:
		velo.queue_free()


func _al_completar(_nivel: int, metricas: Dictionary) -> void:
	_quitar_nivel()
	_pantalla_resultado(metricas)


func _al_fallar(_nivel: int, _motivo: String, metricas: Dictionary) -> void:
	_quitar_nivel()
	_pantalla_resultado(metricas)


# ---------------------------------------------------------------- pantalla 3: resultado del nivel

func _pantalla_resultado(m: Dictionary) -> void:
	_limpiar()
	_margen.visible = true
	_fondo.visible = true
	var exito: bool = m.get("exito", false)
	var color := VERDE if exito else ROJO

	_titulo("Operación completada" if exito else "Operación fallida")
	_texto(String(m.get("titulo_nivel", "")), 17).modulate = Color(1, 1, 1, 0.7)

	var tarjeta := PanelContainer.new()
	tarjeta.add_theme_stylebox_override("panel", TemaEspacial.caja_color(color))
	_contenido.add_child(tarjeta)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	tarjeta.add_child(caja)

	if not exito:
		var motivo := _texto("✗ " + String(m.get("motivo", "La nave no completó la operación.")), 19, caja)
		motivo.modulate = ROJO
	else:
		_texto("✓ La nave ejecutó la operación con éxito.", 19, caja).modulate = VERDE

	var rejilla := GridContainer.new()
	rejilla.columns = 2
	rejilla.add_theme_constant_override("h_separation", 28)
	rejilla.add_theme_constant_override("v_separation", 8)
	caja.add_child(rejilla)
	for clave in METRICAS.keys():
		if not m.has(clave):
			continue
		var k := Label.new()
		k.text = METRICAS[clave][0]
		k.modulate = COLOR_ACENTO
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rejilla.add_child(k)
		var v := Label.new()
		v.text = (METRICAS[clave][1] % m[clave]) if METRICAS[clave][1] != "%s" else str(m[clave])
		rejilla.add_child(v)

	_aviso = _texto("", 15)
	_aviso.modulate = AMARILLO
	if not exito:
		_boton("Reintentar la operación", 50, _iniciar_nivel)
		_texto("También puedes continuar: la Sala de resultados registrará la operación como fallida.", 14).modulate = Color(1, 1, 1, 0.6)
	_boton("Continuar a la Sala de resultados →", 60, _confirmar.bind(m))


func _confirmar(m: Dictionary) -> void:
	GameState.operacion = m.duplicate(true)
	terminar()


# ---------------------------------------------------------------- fondo 3D (planeta del destino)

func _crear_fondo_orbital_3d() -> Control:
	var contenedor := SubViewportContainer.new()
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contenedor.stretch = true
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	contenedor.add_child(vp)

	var escena_3d: Node3D = EscenaFondo3D.instantiate() as Node3D
	vp.add_child(escena_3d)
	_aplicar_astro_en_3d(escena_3d)
	return contenedor


func _aplicar_astro_en_3d(escena_3d: Node3D) -> void:
	if escena_3d == null:
		return
	var raw: String = String(GameState.destino).to_lower()
	var nombre_astro: String = "AstroTierra"
	if "luna" in raw:
		nombre_astro = "AstroLuna"
	elif "marte" in raw:
		nombre_astro = "AstroMarte"
	elif "júpiter" in raw or "jupiter" in raw:
		nombre_astro = "AstroJupiter"
	elif "sol" in raw or "solar" in raw:
		nombre_astro = "AstroSol"

	for nombre in ["AstroTierra", "AstroLuna", "AstroMarte", "AstroJupiter", "AstroSol"]:
		var malla: MeshInstance3D = escena_3d.find_child(nombre, true, false) as MeshInstance3D
		if malla != null:
			malla.visible = (nombre == nombre_astro)
