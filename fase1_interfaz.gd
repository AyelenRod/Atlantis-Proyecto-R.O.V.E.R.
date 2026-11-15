extends PhaseBase
## Interfaz de la Fase 1 (Sala de planificación): solo dibuja pantallas y llama a la lógica.

const TemaEspacial = preload("res://tema_espacial.gd")
const FondoEspacial = preload("res://fondo_espacial.gd")
const Datos = preload("res://fase1_datos.gd")
const Logica = preload("res://fase1_logica.gd")

const COLOR_ACENTO := Color("ff9a4d")

var logica = Logica.new()

var _campos: Array = []
var _contenido: VBoxContainer
var _margen: MarginContainer
var _deco: Control
var _pista: Control
var _progreso: ProgressBar
var _cohete: TextureRect
var _etiquetas_fase: Array = []
var _flotantes: Array = []
var _tiempo: float = 0.0
var _aviso: Label
var _contexto: Label


func _ready() -> void:
	theme = TemaEspacial.crear()

	var fondo := FondoEspacial.new()
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Capa de dibujos flotantes (astronautas, satélite, ovni...), detrás del contenido.
	_deco = Control.new()
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_deco)
	_deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_margen = MarginContainer.new()
	add_child(_margen)
	_margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margen.add_theme_constant_override("margin_top", 28)
	_margen.add_theme_constant_override("margin_bottom", 28)
	resized.connect(_ajustar_margenes)
	_ajustar_margenes()

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 14)
	_margen.add_child(raiz)

	raiz.add_child(_crear_barra())

	# Datos de la partida que ya se eligieron antes (nivel y jugadores): solo se muestran.
	_contexto = Label.new()
	_contexto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contexto.add_theme_font_size_override("font_size", 16)
	_contexto.modulate = COLOR_ACENTO
	raiz.add_child(_contexto)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	raiz.add_child(scroll)

	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 14)
	scroll.add_child(_contenido)

	if Datos.MODO_PRUEBA:
		var errores: Array = Logica.new().autoprueba()
		for e in errores:
			push_warning("[Fase1] " + str(e))
		if errores.is_empty():
			print("[Fase1] Autoprueba de datos: OK")

	# Lo normal: el menú anterior ya llamó a GameState.configurar_partida().
	# Si abres esta escena sola (F6), en modo prueba se simula esa configuración.
	if not logica.cargar_config():
		if Datos.MODO_PRUEBA and logica.usar_prueba():
			print("[Fase1] Sin configuración previa: usando la prueba '%s'." % Datos.PRUEBA_ACTIVA)
		else:
			_contexto.text = ""
			_titulo("Falta la configuración de la partida")
			_texto("Antes de entrar a la sala de planificación llama a GameState.configurar_partida(modo, nivel, nombres).")
			return

	_contexto.text = logica.texto_contexto()
	_mostrar_paso(Logica.PASO_OBJETIVO)


## Centra una columna de ancho máximo 900 con un padding lateral mínimo de 24.
func _ajustar_margenes() -> void:
	var m := int(maxf(24.0, (size.x - 900.0) * 0.5))
	_margen.add_theme_constant_override("margin_left", m)
	_margen.add_theme_constant_override("margin_right", m)


func _process(delta: float) -> void:
	_tiempo += delta
	var s := _deco.size
	for f in _flotantes:
		var spr: Sprite2D = f["spr"]
		spr.position = Vector2(f["rx"] * s.x, f["ry"] * s.y + sin(_tiempo * 0.9 + f["fase"]) * f["amp"])
		spr.rotation = sin(_tiempo * 0.6 + f["fase"]) * 0.06 + f["rot"]


# ---------------------------------------------------------------- imágenes y dibujos flotantes

func _cargar(ruta: String) -> Texture2D:
	if ruta != "" and ResourceLoader.exists(ruta):
		return load(ruta)
	return null


## Agrega un dibujo que flota suavemente. rx y ry son la posición como fracción de la pantalla (0 a 1).
func _agregar_flotante(clave: String, rx: float, ry: float, tam: float, amp: float = 10.0, rot: float = 0.0) -> void:
	var tex := _cargar(Datos.IMG.get(clave, ""))
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	var lado: float = maxf(tex.get_width(), tex.get_height())
	spr.scale = Vector2.ONE * (tam / lado)
	spr.modulate.a = 0.0
	_deco.add_child(spr)
	create_tween().tween_property(spr, "modulate:a", 1.0, 0.5)
	_flotantes.append({"spr": spr, "rx": rx, "ry": ry, "amp": amp, "rot": rot, "fase": randf() * TAU})


func _decorar(p: int) -> void:
	for f in _flotantes:
		(f["spr"] as Sprite2D).queue_free()
	_flotantes.clear()
	match p:
		0:
			_agregar_flotante("astronauta_bandera", 0.93, 0.50, 150.0)
			_agregar_flotante("satelite", 0.07, 0.40, 120.0, 8.0, -0.3)
		1:
			_agregar_flotante("cohete", 0.93, 0.50, 130.0, 12.0, 0.3)
			_agregar_flotante("ovni", 0.07, 0.60, 120.0, 10.0)
		2:
			_agregar_flotante("astronauta_amarillo", 0.93, 0.50, 150.0)
			_agregar_flotante("satelite", 0.07, 0.45, 120.0, 8.0, -0.3)


# ---------------------------------------------------------------- barra de progreso con cohete

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
		fila.add_child(l)
		_etiquetas_fase.append(l)
	caja.add_child(fila)

	_pista = Control.new()
	_pista.custom_minimum_size = Vector2(0, 50)
	caja.add_child(_pista)

	_progreso = ProgressBar.new()
	_progreso.max_value = 100
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


func _actualizar_barra(animar: bool = true) -> void:
	var fase: int = GameState.fase_actual
	for i in _etiquetas_fase.size():
		var l: Label = _etiquetas_fase[i]
		l.modulate = COLOR_ACENTO if i == fase - 1 else Color(1, 1, 1, 0.55)
	var objetivo: float = logica.avance_total() * 100.0
	if animar:
		create_tween().tween_property(_progreso, "value", objetivo, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_progreso.value = objetivo


# ---------------------------------------------------------------- ayudas de interfaz

func _limpiar() -> void:
	for c in _contenido.get_children():
		_contenido.remove_child(c)
		c.queue_free()
	_campos.clear()


func _titulo(t: String, tam: int = 34, padre: Node = null) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	# Efecto "neón": contorno morado semitransparente
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


func _boton_atras(a_paso: int) -> void:
	_boton("← Atrás", 44, _mostrar_paso.bind(a_paso))


func _mostrar_paso(p: int) -> void:
	logica.ir_a(p)
	_limpiar()
	match p:
		0: _paso_objetivo()
		1: _paso_ruta()
		2: _paso_requisitos()
	_decorar(p)
	_actualizar_barra()
	_contenido.modulate.a = 0.0
	create_tween().tween_property(_contenido, "modulate:a", 1.0, 0.25)


# ---------------------------------------------------------------- paso 0: objetivo

func _paso_objetivo() -> void:
	_titulo("Sala de planificación")
	_texto("Paso 1 de 3: elige el objetivo de tu misión.").modulate = Color(1, 1, 1, 0.7)
	var destinos: Dictionary = logica.destinos_del_nivel()
	for d in destinos.keys():
		var info: Dictionary = destinos[d]
		var marca := "✓  " if d == logica.destino else ""
		_boton("%s%s\nObjetivo: %s\n%s" % [marca, d, info["objetivo"], info["nota"]], 96, _elegir_destino.bind(d))


func _elegir_destino(d: String) -> void:
	logica.elegir_destino(d)
	_mostrar_paso(logica.paso)


# ---------------------------------------------------------------- paso 1: ruta

func _paso_ruta() -> void:
	_titulo("Elige la ruta hacia %s" % logica.destino)
	_texto("Paso 2 de 3: cada ruta cambia el costo y los días de preparación. Fíjate en los límites de tu nivel.").modulate = Color(1, 1, 1, 0.7)
	var rutas: Dictionary = logica.rutas_del_destino()
	for nombre in rutas.keys():
		var r: Dictionary = rutas[nombre]
		var marca := "✓  " if nombre == logica.ruta else ""
		var t := "%s%s\n%s\nCosto: %d millones  ·  Preparación: %d días" % [marca, nombre, r["desc"], r["costo"], r["dias"]]
		var excede: String = logica.motivo_excede(r)
		if excede != "":
			t += "\n⚠ Se pasa del límite de %s de este nivel" % excede
		_boton(t, 110 if excede != "" else 96, _elegir_ruta.bind(nombre))
	_boton_atras(Logica.PASO_OBJETIVO)


func _elegir_ruta(nombre: String) -> void:
	logica.elegir_ruta(nombre)
	_mostrar_paso(logica.paso)


# ---------------------------------------------------------------- paso 2: requisitos del nivel

func _paso_requisitos() -> void:
	_titulo("Requisitos del nivel")
	_texto("Paso 3 de 3: tu plan (%s → %s) debe cumplir los límites del nivel %s." % [
		logica.destino, logica.ruta, logica.nivel()["nombre"]]).modulate = Color(1, 1, 1, 0.7)
	_texto("El presupuesto que no gastes en la ruta queda como saldo para la Sala de laboratorio (el taller), donde construirás y comprarás lo que necesites.", 17).modulate = COLOR_ACENTO

	var tarjeta := PanelContainer.new()
	_contenido.add_child(tarjeta)
	var rejilla := GridContainer.new()
	rejilla.columns = 4
	rejilla.add_theme_constant_override("h_separation", 28)
	rejilla.add_theme_constant_override("v_separation", 12)
	tarjeta.add_child(rejilla)
	for encabezado in ["Requisito", "Límite del nivel", "Tu plan", ""]:
		var h := Label.new()
		h.text = encabezado
		h.modulate = COLOR_ACENTO
		rejilla.add_child(h)
	for f in logica.requisitos():
		_fila_requisito(rejilla, f)

	var saldo_caja := PanelContainer.new()
	_contenido.add_child(saldo_caja)
	var saldo_lbl := Label.new()
	saldo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	saldo_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	saldo_lbl.add_theme_font_size_override("font_size", 20)
	saldo_lbl.modulate = COLOR_ACENTO
	var negrita := TemaEspacial.fuente(true)
	if negrita:
		saldo_lbl.add_theme_font_override("font", negrita)
	if logica.presupuesto_libre():
		saldo_lbl.text = "Presupuesto libre (sin límite): no hay saldo que calcular."
	else:
		var pres: int = logica.nivel()["presupuesto"]
		var costo: int = logica.rutas_del_destino()[logica.ruta]["costo"]
		saldo_lbl.text = "Presupuesto %d M − Plan %d M = %d M de saldo para la Sala de laboratorio" % [pres, costo, logica.saldo_restante()]
	saldo_caja.add_child(saldo_lbl)

	_aviso = _texto("", 16)
	_aviso.modulate = Color("ffd166")
	_boton("Confirmar plan →", 60, _confirmar)
	_boton_atras(Logica.PASO_RUTA)


func _fila_requisito(rejilla: GridContainer, f: Dictionary) -> void:
	var estados := {Logica.OK: "✓", Logica.FALLA: "✗", Logica.INFO: "•"}
	var colores := {Logica.OK: Color("7be495"), Logica.FALLA: Color("ff6b6b"), Logica.INFO: Color(1, 1, 1, 0.6)}
	for i in 4:
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL if i < 3 else Control.SIZE_SHRINK_BEGIN
		match i:
			0: l.text = f["nombre"]
			1: l.text = f["limite"]
			2: l.text = f["plan"]
			3:
				l.text = estados[f["estado"]]
				l.modulate = colores[f["estado"]]
		if i == 2 and f["estado"] == Logica.FALLA:
			l.modulate = colores[Logica.FALLA]
		rejilla.add_child(l)


func _confirmar() -> void:
	if not logica.cumple_requisitos():
		_aviso.text = "Tu ruta no cumple los requisitos del nivel (marcados con ✗). Vuelve atrás y elige otra ruta."
		return
	logica.crear_ficha()   # guarda la ficha y vuelca destino/ruta/saldo a GameState
	terminar()             # la Fase 1 queda completa: se abre la puerta del Laboratorio
