extends Control
## PANTALLA DE INICIO: elige si juegas solo o en equipo y la dificultad, y entra a la base espacial.

const TemaEspacial = preload("res://tema_espacial.gd")
const FondoEspacial = preload("res://fondo_espacial.gd")
const Datos = preload("res://fase1_datos.gd")

const COLOR_ACENTO := Color("ff9a4d")
const ANCHO_COLUMNA := 1100.0

var _modo: String = "solo"     # "solo" | "equipo"
var _num: int = 2              # jugadores en equipo (2 a 4)
var _nivel: String = ""        # "" hasta que se elija una dificultad
var _nombres: Array = []       # nombre de cada jugador (editable)
var _contenido: VBoxContainer
var _margen: MarginContainer
var _deco: Control
var _astronauta: TextureRect
var _tiempo: float = 0.0


func _ready() -> void:
	theme = TemaEspacial.crear()

	var fondo := FondoEspacial.new()
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Capa decorativa (detrás del contenido): no captura el ratón.
	_deco = Control.new()
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_deco)
	_deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var ruta_img: String = Datos.IMG.get("astronauta_bandera", "")
	if ResourceLoader.exists(ruta_img):
		_astronauta = TextureRect.new()
		_astronauta.texture = load(ruta_img)
		_astronauta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_astronauta.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_astronauta.custom_minimum_size = Vector2.ZERO
		_astronauta.size = Vector2(150, 150)
		_astronauta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_deco.add_child(_astronauta)

	_margen = MarginContainer.new()
	add_child(_margen)
	_margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margen.add_theme_constant_override("margin_top", 16)
	_margen.add_theme_constant_override("margin_bottom", 16)
	resized.connect(_ajustar_margenes)
	_ajustar_margenes()

	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 8)
	_margen.add_child(_contenido)

	# Al volver al menú (o reiniciar la partida), deja marcada la dificultad de la partida anterior.
	var nivel_anterior := String(GameState.config.get("nivel", ""))
	if Datos.NIVELES.has(nivel_anterior):
		_nivel = nivel_anterior

	_mostrar()


## Centra una columna de ancho máximo 1100 con un padding lateral mínimo de 24.
func _ajustar_margenes() -> void:
	var m := int(maxf(24.0, (size.x - ANCHO_COLUMNA) * 0.5))
	_margen.add_theme_constant_override("margin_left", m)
	_margen.add_theme_constant_override("margin_right", m)


func _process(delta: float) -> void:
	_tiempo += delta
	if _astronauta:
		var lado := clampf((size.x - ANCHO_COLUMNA) * 0.5 - 20.0, 0.0, 170.0)
		_astronauta.visible = lado >= 64.0
		_astronauta.size = Vector2(lado, lado)
		_astronauta.position = Vector2(size.x - lado - 16.0, size.y - lado - 16.0 + sin(_tiempo * 0.9) * 6.0)


# ---------------------------------------------------------------- ayudas de interfaz

func _titulo(t: String, tam: int, padre: Node = null) -> Label:
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


# ---------------------------------------------------------------- pantalla

func _mostrar() -> void:
	for c in _contenido.get_children():
		_contenido.remove_child(c)
		c.queue_free()

	_titulo("MISIÓN ESPACIAL", 36)
	_texto("Elige cómo juegas y la dificultad. Al entrar, recorrerás la base y planificarás tu misión en la sala de Planificación.", 16).modulate = Color(1, 1, 1, 0.75)

	# --- solo o en equipo
	_texto("¿Cómo juegas?", 20).modulate = COLOR_ACENTO
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	_contenido.add_child(fila)
	var b_solo := _boton(("✓  " if _modo == "solo" else "") + "Jugar solo", 48, _elegir_modo.bind("solo"), fila)
	b_solo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b_eq := _boton(("✓  " if _modo == "equipo" else "") + "Multijugador", 48, _elegir_modo.bind("equipo"), fila)
	b_eq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# El multijugador solo existe en Medio y Difícil (en Fácil se aprende solo).
	var mp_permitido := _nivel == "" or Datos.NIVELES_EQUIPO.has(_nivel)
	if not mp_permitido:
		if _modo == "equipo":
			_modo = "solo"
			b_solo.text = "✓  Jugar solo"
			b_eq.text = "Multijugador"
		b_eq.disabled = true
		b_eq.modulate.a = 0.45
		_texto("El multijugador está disponible en Medio y Difícil.", 14).modulate = Color("ffd166")

	# Selector de jugadores: siempre presente para reservar el espacio (evita saltos de layout).
	var fila_n := HBoxContainer.new()
	fila_n.alignment = BoxContainer.ALIGNMENT_CENTER
	_contenido.add_child(fila_n)
	var et := Label.new()
	et.text = "Número de jugadores:  "
	fila_n.add_child(et)
	var opt := OptionButton.new()
	for n in [2, 3, 4]:
		opt.add_item(str(n), n)
	opt.select(_num - 2)
	opt.item_selected.connect(_cambiar_num.bind(opt))
	fila_n.add_child(opt)
	var equipo := _modo == "equipo" and mp_permitido
	et.modulate.a = 1.0 if equipo else 0.35
	opt.disabled = not equipo
	opt.modulate.a = 1.0 if equipo else 0.35
	if equipo:
		var aviso_mp := _texto("Cada jugador recibe fases al azar y un color de astronauta; se pasan el control por relevos en la misma computadora.", 15)
		aviso_mp.modulate = Color(1, 1, 1, 0.7)

	# --- nombres de los jugadores (editables)
	var total_nombres: int = 1 if _modo == "solo" else _num
	while _nombres.size() < total_nombres:
		_nombres.append("Jugador %d" % (_nombres.size() + 1))
	while _nombres.size() > total_nombres:
		_nombres.resize(total_nombres)

	_texto("Nombres", 20).modulate = COLOR_ACENTO
	var fila_nombres := HBoxContainer.new()
	fila_nombres.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_nombres.add_theme_constant_override("separation", 8)
	_contenido.add_child(fila_nombres)
	for i in total_nombres:
		var col := GameState.color_jugador(i)
		var caja_j := VBoxContainer.new()
		caja_j.add_theme_constant_override("separation", 2)
		fila_nombres.add_child(caja_j)
		var campo := LineEdit.new()
		campo.text = String(_nombres[i])
		campo.placeholder_text = "Jugador %d" % (i + 1)
		campo.max_length = 20
		campo.custom_minimum_size = Vector2(160, 38)
		campo.text_changed.connect(_cambiar_nombre.bind(i))
		if total_nombres > 1:
			var borde := StyleBoxFlat.new()
			borde.bg_color = Color(0.05, 0.04, 0.14, 0.9)
			borde.border_color = col
			borde.set_border_width_all(2)
			borde.set_corner_radius_all(10)
			borde.set_content_margin_all(10)
			campo.add_theme_stylebox_override("normal", borde)
			campo.add_theme_stylebox_override("focus", borde)
		caja_j.add_child(campo)
		if total_nombres > 1:
			var etiqueta_col := Label.new()
			etiqueta_col.text = "●  astronauta " + GameState.nombre_color(i)
			etiqueta_col.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			etiqueta_col.add_theme_font_size_override("font_size", 13)
			etiqueta_col.modulate = col
			caja_j.add_child(etiqueta_col)

	# --- dificultad (en un ScrollContainer que ocupa el espacio libre; las tarjetas se adaptan)
	_texto("Dificultad", 20).modulate = COLOR_ACENTO
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_contenido.add_child(scroll)
	var tarjetas := VBoxContainer.new()
	tarjetas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tarjetas.add_theme_constant_override("separation", 8)
	scroll.add_child(tarjetas)
	for id in Datos.ORDEN_NIVELES:
		var n: Dictionary = Datos.NIVELES[id]
		var pres: String = n["txt_presupuesto"]
		if n["presupuesto"] >= 0:
			pres += " (%d millones)" % n["presupuesto"]
		var dias: String = n["txt_tiempo"]
		if n["dias"] >= 0:
			dias += " (%d días)" % n["dias"]
		var t := "%s%s  —  %s\n%s\nPresupuesto: %s  ·  Información: %s  ·  Eventos: %s  ·  Preparación: %s" % [
			"✓  " if id == _nivel else "", n["nombre"], ", ".join(n["destinos"].keys()), n["resumen"],
			pres, n["txt_info"], n["txt_eventos"], dias]
		var b := _boton(t, 80, _elegir_nivel.bind(id), tarjetas)
		b.add_theme_font_size_override("font_size", 15)

	var entrar := _boton("Entrar a la base espacial →", 52, _entrar)
	entrar.disabled = _nivel == ""
	if _nivel == "":
		_texto("Elige una dificultad para continuar.", 14).modulate = Color("ffd166")


func _ir_lobby() -> void:
	Transicion.ir_a("res://lobby.tscn")


func _elegir_modo(m: String) -> void:
	_modo = m
	_mostrar()


func _cambiar_num(indice: int, opt: OptionButton) -> void:
	_num = opt.get_item_id(indice)
	_mostrar()


func _cambiar_nombre(texto: String, i: int) -> void:
	if i < _nombres.size():
		_nombres[i] = texto


func _elegir_nivel(id: String) -> void:
	_nivel = id
	_mostrar()


func _entrar() -> void:
	if _nivel == "":
		return
	var nombres: Array = []
	var total: int = 1 if _modo == "solo" else _num
	for i in total:
		var nom: String = String(_nombres[i]).strip_edges() if i < _nombres.size() else ""
		if nom == "":
			nom = "Jugador %d" % (i + 1)
		nombres.append(nom)
	GameState.configurar_partida(_modo, _nivel, nombres)
	Transicion.ir_a("res://scenes/main.tscn")
