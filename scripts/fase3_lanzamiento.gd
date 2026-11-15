extends PhaseBase
## Interfaz de la Fase 3 (Sala de lanzamiento y tránsito): solo dibuja y llama a la lógica.

const TemaEspacial = preload("res://tema_espacial.gd")
const FondoEspacial = preload("res://fondo_espacial.gd")
const Datos1 = preload("res://fase1_datos.gd")           # nombres de salas e imágenes
const Datos = preload("res://scripts/fase3/fase3_datos.gd")
const Logica = preload("res://scripts/fase3/fase3_logica.gd")

const COLOR_ACENTO := Color("ff9a4d")
const VERDE := Color("7be495")
const ROJO := Color("ff6b6b")
const AMARILLO := Color("ffd166")

## Color del planeta de destino (dibujado por código, como el Marte del original).
const PLANETAS := {
	"Órbita terrestre": [Color("2f6fd6"), Color("7fd1ff")],
	"Luna": [Color("9a9a9a"), Color("e0e0e0")],
	"Marte": [Color("c1440e"), Color("ff9a6a")],
	"Órbita solar": [Color("ff8c1a"), Color("fff0a0")],
	"Júpiter": [Color("c8a070"), Color("f2dcc0")],
}

var logica = Logica.new()
var _tiempo := 0.0

var _margen: MarginContainer
var _contenido: VBoxContainer
var _pista: Control
var _progreso_salas: ProgressBar
var _cohete_barra: TextureRect

var _viaje: Control            # zona del viaje (dibuja ruta y planeta)
var _cohete: TextureRect       # cohete que recorre la ruta
var _barra_progreso: ProgressBar
var _barra_combustible: ProgressBar
var _barra_integridad: ProgressBar
var _lbl_estado: Label
var _boton_lanzar: Button
var _panel_evento: PanelContainer
var _panel_resultado: PanelContainer


func _sola() -> bool:
	return get_tree().current_scene == self


func _ready() -> void:
	theme = TemaEspacial.crear()
	var fondo := FondoEspacial.new()
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
	raiz.add_child(_crear_barra_salas())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	raiz.add_child(scroll)
	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 12)
	scroll.add_child(_contenido)

	# Datos de prueba si se abre la escena sola sin partida
	if _sola() and GameState.destino == "":
		GameState.nivel = Datos.PRUEBA["nivel"]
		GameState.destino = Datos.PRUEBA["destino"]
		GameState.ruta = Datos.PRUEBA["ruta"]

	logica.preparar()
	_construir()


func _ajustar_margenes() -> void:
	var m := int(maxf(24.0, (size.x - 900.0) * 0.5))
	_margen.add_theme_constant_override("margin_left", m)
	_margen.add_theme_constant_override("margin_right", m)


func _process(delta: float) -> void:
	_tiempo += delta
	var antes: String = logica.estado
	var ahora: String = logica.avanzar(delta)
	_actualizar_barras()
	_mover_cohete()
	_viaje.queue_redraw()
	if ahora != antes:
		match ahora:
			Logica.ESTADO_EVENTO: _mostrar_evento()
			Logica.ESTADO_EXITO, Logica.ESTADO_FALLO: _mostrar_resultado()


# ---------------------------------------------------------------- barra de salas (igual que Fase 1)

func _cargar(ruta: String) -> Texture2D:
	if ruta != "" and ResourceLoader.exists(ruta):
		return load(ruta)
	return null


func _crear_barra_salas() -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	var fila := HBoxContainer.new()
	for i in Datos1.FASES.size():
		var l := Label.new()
		l.text = "%d. %s" % [i + 1, Datos1.FASES[i]]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 14)
		l.modulate = COLOR_ACENTO if i == 2 else Color(1, 1, 1, 0.55)
		fila.add_child(l)
	caja.add_child(fila)
	_pista = Control.new()
	_pista.custom_minimum_size = Vector2(0, 50)
	caja.add_child(_pista)
	_progreso_salas = ProgressBar.new()
	_progreso_salas.max_value = 100
	_progreso_salas.value = 40
	_progreso_salas.show_percentage = false
	_progreso_salas.custom_minimum_size = Vector2(0, 14)
	_progreso_salas.anchor_left = 0.0
	_progreso_salas.anchor_right = 1.0
	_progreso_salas.anchor_top = 0.5
	_progreso_salas.anchor_bottom = 0.5
	_progreso_salas.offset_top = -7.0
	_progreso_salas.offset_bottom = 7.0
	_pista.add_child(_progreso_salas)
	_cohete_barra = TextureRect.new()
	_cohete_barra.texture = _cargar(Datos1.IMG.get("cohete_horizontal", ""))
	_cohete_barra.visible = _cohete_barra.texture != null
	_cohete_barra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cohete_barra.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cohete_barra.size = Vector2(64, 64)
	_cohete_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pista.add_child(_cohete_barra)
	_progreso_salas.value_changed.connect(_colocar_cohete_barra)
	_pista.resized.connect(_colocar_cohete_barra)
	return caja


func _colocar_cohete_barra(_v: float = 0.0) -> void:
	var borde: float = _pista.size.x * _progreso_salas.value / _progreso_salas.max_value
	var x := clampf(borde - _cohete_barra.size.x * 0.85, -8.0, _pista.size.x - _cohete_barra.size.x)
	_cohete_barra.position = Vector2(x, (_pista.size.y - _cohete_barra.size.y) * 0.5)


# ---------------------------------------------------------------- ayudas de interfaz (mismas que Fase 1)

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
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(accion)
	(padre if padre else _contenido).add_child(b)
	return b


# ---------------------------------------------------------------- pantalla

func _construir() -> void:
	_titulo("Sala de lanzamiento")
	_texto("Proyecto R.O.V.E.R. — misión a %s" % GameState.destino, 17).modulate = Color(1, 1, 1, 0.7)
	var ctx := "Nivel: %s" % GameState.NIVELES[GameState.nivel_actual()]["nombre"]
	if GameState.ruta != "":
		ctx += "  ·  Ruta: %s" % GameState.ruta
	ctx += "  ·  Eventos en tránsito: %d" % logica.eventos.size()
	_texto(ctx, 16).modulate = COLOR_ACENTO

	# --- Zona del viaje: ruta punteada, planeta de destino y cohete
	var tarjeta_viaje := PanelContainer.new()
	_contenido.add_child(tarjeta_viaje)
	_viaje = Control.new()
	_viaje.custom_minimum_size = Vector2(0, 200)
	_viaje.draw.connect(_dibujar_viaje)
	tarjeta_viaje.add_child(_viaje)
	_cohete = TextureRect.new()
	_cohete.texture = _cargar(Datos1.IMG.get("cohete_horizontal", ""))
	_cohete.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cohete.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cohete.size = Vector2(96, 96)
	_cohete.pivot_offset = Vector2(48, 48)
	_cohete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viaje.add_child(_cohete)

	# --- Telemetría: las tres barras del original
	var tarjeta_hud := PanelContainer.new()
	_contenido.add_child(tarjeta_hud)
	var rejilla := GridContainer.new()
	rejilla.columns = 3
	rejilla.add_theme_constant_override("h_separation", 20)
	rejilla.add_theme_constant_override("v_separation", 10)
	tarjeta_hud.add_child(rejilla)
	_barra_progreso = _fila_barra(rejilla, "Progreso del viaje", 0.0, COLOR_ACENTO)
	_barra_combustible = _fila_barra(rejilla, "Combustible", 100.0, Color("4fc3f7"))
	_barra_integridad = _fila_barra(rejilla, "Integridad de la nave", 100.0, VERDE)

	# --- Revisión previa (informativa)
	var tarjeta_rev := PanelContainer.new()
	_contenido.add_child(tarjeta_rev)
	var rev := GridContainer.new()
	rev.columns = 3
	rev.add_theme_constant_override("h_separation", 24)
	rev.add_theme_constant_override("v_separation", 6)
	tarjeta_rev.add_child(rev)
	for f in logica.revision_previa():
		var a := Label.new(); a.text = f["nombre"]; a.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rev.add_child(a)
		var b := Label.new(); b.text = f["valor"]; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rev.add_child(b)
		var c := Label.new(); c.text = "✓" if f["ok"] else "⚠"; c.modulate = VERDE if f["ok"] else AMARILLO; rev.add_child(c)

	_lbl_estado = _texto("Revisa la nave y presiona Iniciar lanzamiento.", 16)
	_lbl_estado.modulate = AMARILLO
	_boton_lanzar = _boton("INICIAR LANZAMIENTO →", 60, _lanzar)

	# --- Panel de evento (oculto): mensaje + dos opciones, como el original
	_panel_evento = PanelContainer.new()
	_panel_evento.visible = false
	_panel_evento.add_theme_stylebox_override("panel", TemaEspacial.caja_color(AMARILLO))
	_contenido.add_child(_panel_evento)
	_contenido.move_child(_panel_evento, _contenido.get_children().find(tarjeta_hud))

	_panel_resultado = PanelContainer.new()
	_panel_resultado.visible = false
	_contenido.add_child(_panel_resultado)

	_mover_cohete()


func _fila_barra(rejilla: GridContainer, nombre: String, valor: float, color: Color) -> ProgressBar:
	var l := Label.new()
	l.text = nombre
	l.custom_minimum_size = Vector2(190, 0)
	rejilla.add_child(l)
	var b := ProgressBar.new()
	b.max_value = 100
	b.value = valor
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 16)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(8)
	b.add_theme_stylebox_override("fill", fill)
	rejilla.add_child(b)
	var v := Label.new()
	v.name = "Valor"
	v.text = "%d %%" % int(valor)
	v.custom_minimum_size = Vector2(56, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rejilla.add_child(v)
	b.set_meta("etiqueta", v)
	return b


func _poner(barra: ProgressBar, valor: float) -> void:
	barra.value = valor
	(barra.get_meta("etiqueta") as Label).text = "%d %%" % int(round(valor))


func _actualizar_barras() -> void:
	_poner(_barra_progreso, logica.progreso)
	_poner(_barra_combustible, logica.combustible)
	_poner(_barra_integridad, logica.integridad)
	var ci: Color = VERDE if logica.integridad > 50.0 else (AMARILLO if logica.integridad > 25.0 else ROJO)
	(_barra_integridad.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = ci
	(_barra_combustible.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color("4fc3f7") if logica.combustible > 25.0 else ROJO


## El cohete recorre la ruta y flota como en el original (vaivén vertical y giro suave).
func _mover_cohete() -> void:
	if _viaje == null:
		return
	var s := _viaje.size
	var x0 := 20.0
	var x1 := s.x - 190.0
	var t: float = logica.progreso / 100.0
	var y := s.y * 0.55 - 40.0 * sin(t * PI)      # arco suave hacia arriba
	if logica.estado != Logica.ESTADO_LISTO:
		y += sin(_tiempo * 2.5) * 5.0
		_cohete.rotation_degrees = sin(_tiempo * 1.8) * 1.5 - 12.0 * sin(t * PI)
	_cohete.position = Vector2(lerpf(x0, x1, t), y - 48.0)
	var brillo := 0.95 + sin(_tiempo * 3.0) * 0.05
	_cohete.modulate = Color(1.0, brillo, 1.0, 1.0)
	if _cohete.texture == null:
		_cohete.visible = false


func _dibujar_viaje() -> void:
	var s := _viaje.size
	# Ruta punteada
	var x0 := 68.0
	var x1 := s.x - 140.0
	var pasos := 40
	for i in pasos:
		if i % 2 == 1:
			continue
		var ta := float(i) / pasos
		var tb := float(i + 1) / pasos
		var pa := Vector2(lerpf(x0, x1, ta), s.y * 0.55 - 40.0 * sin(ta * PI))
		var pb := Vector2(lerpf(x0, x1, tb), s.y * 0.55 - 40.0 * sin(tb * PI))
		var avanzado: bool = ta * 100.0 <= logica.progreso
		_viaje.draw_line(pa, pb, COLOR_ACENTO if avanzado else Color(1, 1, 1, 0.25), 2.0, true)
	# Marcas de eventos sobre la ruta
	for i in logica.eventos.size():
		var te: float = float(logica.eventos[i]["porcentaje"]) / 100.0
		var pe := Vector2(lerpf(x0, x1, te), s.y * 0.55 - 40.0 * sin(te * PI))
		var hecho: bool = i < logica.indice_evento
		_viaje.draw_circle(pe, 7.0, VERDE if hecho else AMARILLO)
		_viaje.draw_circle(pe, 4.0, Color("150d33"))
	# Planeta de destino: pulsa y "gira" (brillo que recorre), como el Marte original
	var colores: Array = PLANETAS.get(GameState.destino, [Color("8a7cff"), Color("d9c2ff")])
	var centro := Vector2(s.x - 70.0, s.y * 0.5)
	var r := 52.0 * (1.0 + sin(_tiempo * 1.5) * 0.012)
	var brillo := 0.94 + sin(_tiempo * 1.5) * 0.04
	_viaje.draw_circle(centro, r * 1.25, Color(colores[1].r, colores[1].g, colores[1].b, 0.12))
	_viaje.draw_circle(centro, r, colores[0] * Color(1, brillo, brillo, 1))
	var luz := Vector2(cos(_tiempo * 0.25), sin(_tiempo * 0.25) * 0.4) * r * 0.3
	_viaje.draw_circle(centro + luz - Vector2(r * 0.2, r * 0.2), r * 0.6, Color(colores[1].r, colores[1].g, colores[1].b, 0.35))
	if GameState.destino == "Órbita terrestre" or GameState.destino == "Órbita solar":
		_viaje.draw_arc(centro, r * 1.45, 0.0, TAU, 64, Color(1, 1, 1, 0.35), 2.0, true)
	# Tierra de salida (pequeña, a la izquierda)
	_viaje.draw_circle(Vector2(40.0, s.y * 0.6), 22.0, Color("2f6fd6"))
	_viaje.draw_circle(Vector2(34.0, s.y * 0.6 - 6.0), 9.0, Color("5fbf6a"))


# ---------------------------------------------------------------- acciones

func _lanzar() -> void:
	logica.lanzar()
	_boton_lanzar.disabled = true
	_lbl_estado.text = "¡LANZAMIENTO INICIADO! Rumbo a %s..." % GameState.destino


func _mostrar_evento() -> void:
	var e: Dictionary = logica.evento_actual()
	for c in _panel_evento.get_children():
		c.queue_free()
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	_panel_evento.add_child(caja)
	var t := _texto(e["mensaje"], 19, caja)
	t.modulate = AMARILLO
	var negrita := TemaEspacial.fuente(true)
	if negrita:
		t.add_theme_font_override("font", negrita)
	_boton(_texto_opcion(e["opcion_a"]), 52, _resolver.bind("a"), caja)
	_boton(_texto_opcion(e["opcion_b"]), 52, _resolver.bind("b"), caja)
	_panel_evento.visible = true
	_lbl_estado.text = "Evento en tránsito: decide qué hacer."


func _texto_opcion(o: Dictionary) -> String:
	var efectos: Array[String] = []
	if int(o["combustible"]) != 0:
		efectos.append("%+d combustible" % int(o["combustible"]))
	if int(o["integridad"]) != 0:
		efectos.append("%+d integridad" % int(o["integridad"]))
	if efectos.is_empty():
		efectos.append("sin costo")
	return "%s\n(%s)" % [o["texto"], ", ".join(efectos)]


func _resolver(opcion: String) -> void:
	logica.resolver(opcion)
	_panel_evento.visible = false
	if logica.estado == Logica.ESTADO_VIAJANDO:
		_lbl_estado.text = "Decisión tomada. El viaje continúa."
	else:
		_mostrar_resultado()


func _mostrar_resultado() -> void:
	var exito: bool = logica.estado == Logica.ESTADO_EXITO
	_panel_resultado.add_theme_stylebox_override("panel", TemaEspacial.caja_color(VERDE if exito else ROJO))
	for c in _panel_resultado.get_children():
		c.queue_free()
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	_panel_resultado.add_child(caja)
	var t := _titulo("¡LLEGASTE A %s!" % GameState.destino.to_upper() if exito else "MISIÓN FALLIDA", 26, caja)
	t.modulate = VERDE if exito else ROJO
	if exito:
		_texto("Tránsito completado con %d %% de combustible y %d %% de integridad. Eventos resueltos: %d." % [
			int(logica.combustible), int(logica.integridad), logica.decisiones.size()], 16, caja)
		_boton("Continuar a la Sala de operación →", 56, terminar, caja)
	else:
		_texto(logica.motivo_fallo, 16, caja).modulate = ROJO
		_boton("Volver a intentar el lanzamiento", 48, _reintentar, caja)
		_texto("O continúa: la Sala de resultados registrará el tránsito como fallido.", 14, caja).modulate = Color(1, 1, 1, 0.6)
		_boton("Continuar de todos modos →", 48, terminar, caja)
	_panel_resultado.visible = true
	_lbl_estado.text = ""


func _reintentar() -> void:
	logica.preparar()
	_panel_resultado.visible = false
	_panel_evento.visible = false
	_boton_lanzar.disabled = false
	_lbl_estado.text = "Nave reabastecida. Presiona Iniciar lanzamiento."
	_cohete.rotation_degrees = 0.0
