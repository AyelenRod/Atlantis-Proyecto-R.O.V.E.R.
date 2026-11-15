extends Node
## Partida: estación orbital (hub) + HUD de misión (progreso, botón ENTRAR, mapa, salir al menú) + ventana de fase.

const FondoEspacial = preload("res://fondo_espacial.gd")

var hub
var capa_fase: CanvasLayer
var ventana: Control
var contenedor_fase: Control
var escena_fase: Node
var fase_abierta := -1
var barra: ProgressBar
var etiquetas: Array[Label] = []
var aviso: Label
var boton_salir: Button
var _salir_armado := false
var boton_usar: Button
var mapa: Minimapa
var banner: PanelContainer
var banner_titulo: Label
var banner_sub: Label
var _tween_banner: Tween
var _tween_barra: Tween
var _hud_listo := false
var _t := 0.0
# Multijugador (relevos)
var etiqueta_turno: Label
var capa_relevo: CanvasLayer
var _relevo_titulo: Label
var _relevo_texto: Label
var _relevo_boton: Button
var _relevo_estilo: StyleBoxFlat
var _relevo_lista: VBoxContainer
var _relevo_astro: Astronauta
var _relevo_abierto := false
# Multijugador en red
var _turno_previo := -1
var _fin_red := false


func _ready() -> void:
	_construir_fondo()
	hub = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	hub.entrar_fase.connect(abrir_fase)
	_construir_hud()
	_construir_capa_fase()
	_construir_relevo()
	GameState.progreso_cambio.connect(_actualizar_hud)
	GameState.turno_cambio.connect(_actualizar_hud)
	_actualizar_hud()
	_hud_listo = true
	# Multijugador: al empezar, muestra quién juega cada fase.
	if GameState.es_multijugador() and GameState.fases_hechas() == 0:
		_mostrar_reparto()
	if GameState.es_red():
		_turno_previo = GameState.jugador_en_turno()
		GameState.turno_cambio.connect(_turno_red)
		Red.estado_actualizado.connect(_revisar_fin_red)
		Red.desconectado.connect(_host_perdido)
		Red.jugador_se_fue.connect(_jugador_se_fue)


## Fondo de galaxia con estrellas que titilan, detrás de la base (no se mueve con la cámara).
func _construir_fondo() -> void:
	var capa := CanvasLayer.new()
	capa.layer = -1
	add_child(capa)
	var fondo := FondoEspacial.new()
	capa.add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	var puede := fase_abierta == -1 and not _relevo_abierto and hub.zona_cercana() != null
	boton_usar.disabled = not puede
	# El botón USAR pulsa cuando se puede usar
	boton_usar.pivot_offset = boton_usar.size / 2.0
	boton_usar.scale = Vector2.ONE * (1.0 + 0.05 * sin(_t * 6.0)) if puede else Vector2.ONE


func _estilo(fondo: Color, borde: Color, ancho: int, radio: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(ancho)
	s.set_corner_radius_all(radio)
	return s


func _construir_hud() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 5
	add_child(capa)

	# Panel de tareas (arriba a la izquierda)
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 12)
	var fondo := _estilo(Color(0.04, 0.06, 0.10, 0.75), Color("#9aa5bd"), 2, 6)
	fondo.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", fondo)
	capa.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = "PROGRESO DE LA MISIÓN"
	Estilo.texto(titulo, 16)
	caja.add_child(titulo)

	# Multijugador: de quién es el turno (vacío en modo solo)
	etiqueta_turno = Label.new()
	etiqueta_turno.visible = false
	Estilo.texto(etiqueta_turno, 17, Color("#ff9a4d"))
	caja.add_child(etiqueta_turno)

	barra = ProgressBar.new()
	barra.max_value = GameState.FASES.size()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(400, 18)
	barra.add_theme_stylebox_override("background", _estilo(Color("#1f2937"), Color("#9aa5bd"), 2, 4))
	barra.add_theme_stylebox_override("fill", _estilo(Color("#22c55e"), Color("#22c55e"), 0, 4))
	caja.add_child(barra)

	for f in GameState.FASES:
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(400, 0)
		Estilo.texto(l, 15)
		caja.add_child(l)
		etiquetas.append(l)

	# Minimapa (arriba a la derecha).
	mapa = Minimapa.new()
	mapa.hub = hub
	capa.add_child(mapa)

	# Botón USAR (abajo a la derecha)
	boton_usar = Button.new()
	boton_usar.text = "ENTRAR\n(E)"
	boton_usar.focus_mode = Control.FOCUS_NONE
	boton_usar.disabled = true
	boton_usar.position = Vector2(1280 - 150, 720 - 150)
	boton_usar.size = Vector2(130, 130)
	boton_usar.add_theme_font_size_override("font_size", 26)
	boton_usar.add_theme_stylebox_override("normal", _estilo(Color("#3a4a6b"), Color("#f5d742"), 5, 65))
	boton_usar.add_theme_stylebox_override("hover", _estilo(Color("#4b5f88"), Color("#f5d742"), 5, 65))
	boton_usar.add_theme_stylebox_override("pressed", _estilo(Color("#2c3956"), Color("#f5d742"), 5, 65))
	boton_usar.add_theme_stylebox_override("disabled", _estilo(Color(0.12, 0.14, 0.2, 0.7), Color("#4b5563"), 4, 65))
	boton_usar.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	boton_usar.pressed.connect(_usar)
	capa.add_child(boton_usar)

	# Ayuda (abajo a la izquierda)
	aviso = Label.new()
	aviso.position = Vector2(14, 684)
	Estilo.texto(aviso, 15)
	capa.add_child(aviso)

	boton_salir = Button.new()
	boton_salir.text = "Salir al menú"
	boton_salir.focus_mode = Control.FOCUS_NONE
	boton_salir.position = Vector2(14, 640)
	boton_salir.size = Vector2(190, 36)
	boton_salir.add_theme_font_size_override("font_size", 15)
	boton_salir.add_theme_stylebox_override("normal", _estilo(Color(0.04, 0.06, 0.10, 0.75), Color("#9aa5bd"), 2, 8))
	boton_salir.add_theme_stylebox_override("hover", _estilo(Color(0.10, 0.12, 0.20, 0.9), Color("#f5d742"), 2, 8))
	boton_salir.add_theme_stylebox_override("pressed", _estilo(Color(0.02, 0.03, 0.06, 0.9), Color("#f5d742"), 2, 8))
	boton_salir.pressed.connect(_salir_al_menu)
	capa.add_child(boton_salir)

	# Aviso que baja desde arriba ("TAREA COMPLETADA")
	banner = PanelContainer.new()
	banner.visible = false
	banner.custom_minimum_size = Vector2(460, 0)
	banner.position = Vector2(410, -140)
	var est := _estilo(Color(0.04, 0.10, 0.07, 0.92), Color("#4ade80"), 3, 10)
	est.set_content_margin_all(14)
	banner.add_theme_stylebox_override("panel", est)
	var cb := VBoxContainer.new()
	banner.add_child(cb)
	banner_titulo = Label.new()
	banner_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Estilo.texto(banner_titulo, 28, Color("#4ade80"))
	cb.add_child(banner_titulo)
	banner_sub = Label.new()
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Estilo.texto(banner_sub, 17)
	cb.add_child(banner_sub)
	capa.add_child(banner)


func _construir_capa_fase() -> void:
	capa_fase = CanvasLayer.new()
	capa_fase.layer = 10
	capa_fase.visible = false
	add_child(capa_fase)

	ventana = Control.new()
	ventana.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa_fase.add_child(ventana)

	var fondo := ColorRect.new()
	fondo.color = Color("#0b0a1e")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	ventana.add_child(fondo)

	contenedor_fase = Control.new()
	contenedor_fase.set_anchors_preset(Control.PRESET_FULL_RECT)
	ventana.add_child(contenedor_fase)

	# Botón para salir de la fase sin completarla (esquina superior derecha).
	var volver := Button.new()
	volver.text = "Volver a la base (Esc)"
	volver.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	volver.offset_left = -240.0
	volver.offset_right = -16.0
	volver.offset_top = 12.0
	volver.offset_bottom = 52.0
	volver.pressed.connect(cerrar_fase)
	ventana.add_child(volver)


func _usar() -> void:
	var z: Zona = hub.zona_cercana()
	if z != null:
		abrir_fase(z.indice)


func abrir_fase(i: int) -> void:
	if fase_abierta != -1 or _relevo_abierto:
		return
	if not GameState.fase_disponible(i):
		return
	if mapa.ampliado:
		mapa.alternar()
	fase_abierta = i
	hub.process_mode = Node.PROCESS_MODE_DISABLED
	escena_fase = load(GameState.FASES[i]["escena"]).instantiate()
	contenedor_fase.add_child(escena_fase)
	escena_fase.fase_terminada.connect(_fase_completada)
	capa_fase.visible = true
	# Animación: la ventana aparece con un pequeño zoom
	ventana.pivot_offset = Vector2(640, 360)
	ventana.modulate.a = 0.0
	ventana.scale = Vector2(0.94, 0.94)
	var t := create_tween().set_parallel(true)
	t.tween_property(ventana, "modulate:a", 1.0, 0.22)
	t.tween_property(ventana, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func cerrar_fase() -> void:
	if fase_abierta == -1:
		return
	if escena_fase:
		escena_fase.queue_free()
		escena_fase = null
	capa_fase.visible = false
	hub.process_mode = Node.PROCESS_MODE_INHERIT
	fase_abierta = -1
	Transicion.destello()


func _fase_completada() -> void:
	var i := fase_abierta
	var jugador_antes := GameState.jugador_en_turno()
	GameState.completar_fase(i)
	cerrar_fase()
	if GameState.es_red():
		# En red: se manda el avance al anfitrión, que lo reparte a todos.
		# partida lo detecta _revisar_fin_red (cuando llega el estado con las 5 fases hechas).
		Red.fase_completada(i)
		if not GameState.todas_completas():
			var sig := GameState.fase_en_turno()
			_mostrar_aviso("¡TAREA COMPLETADA!", "Sigue: %s (%s)" % [GameState.FASES[sig]["nombre"], GameState.dueno_de(sig)])
		return
	if GameState.todas_completas():
		_mostrar_aviso("¡MISIÓN COMPLETADA!", "Regresando al menú...")
		await get_tree().create_timer(2.4).timeout
		GameState.reiniciar()
		Transicion.ir_a("res://menu.tscn")
		return
	if i + 1 < GameState.FASES.size():
		_mostrar_aviso("¡TAREA COMPLETADA!", "Puerta abierta: " + String(GameState.FASES[i + 1]["nombre"]))
	else:
		_mostrar_aviso("¡TAREA COMPLETADA!", "Aún quedan tareas pendientes")
	# Multijugador: si el turno pasa a otra persona, pantalla de relevo.
	if GameState.es_multijugador() and not GameState.es_red() and GameState.jugador_en_turno() != jugador_antes:
		await get_tree().create_timer(1.8).timeout
		if is_instance_valid(self) and fase_abierta == -1 and not _relevo_abierto:
			_mostrar_relevo_turno()


func _mostrar_aviso(titulo: String, sub: String) -> void:
	banner_titulo.text = titulo
	banner_sub.text = sub
	banner.visible = true
	banner.modulate.a = 1.0
	banner.position.y = -140.0
	if _tween_banner:
		_tween_banner.kill()
	_tween_banner = create_tween()
	_tween_banner.tween_property(banner, "position:y", 110.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_banner.tween_interval(1.8)
	_tween_banner.tween_property(banner, "modulate:a", 0.0, 0.4)
	_tween_banner.tween_callback(func(): banner.visible = false)


func _actualizar_hud() -> void:
	for i in etiquetas.size():
		var f: Dictionary = GameState.FASES[i]
		var hecha: bool = GameState.fases_completadas[i]
		var texto := "%s: %s (%d/1)" % [f["nombre"], f["tarea"], 1 if hecha else 0]
		if GameState.dueno_de(i) != "":
			texto += "  [%s]" % GameState.dueno_de(i)
		var color := Color("#f5d742")          # amarillo = tarea disponible
		if hecha:
			color = Color("#4ade80")           # verde = completada
		elif not GameState.fase_desbloqueada(i):
			color = Color(1, 1, 1, 0.6)        # blanco tenue = puerta cerrada
			texto += "  - puerta cerrada"
		etiquetas[i].text = texto
		etiquetas[i].add_theme_color_override("font_color", color)
	_actualizar_turno()
	var hechas := float(GameState.fases_hechas())
	if _hud_listo:
		if _tween_barra:
			_tween_barra.kill()
		_tween_barra = create_tween()
		_tween_barra.tween_property(barra, "value", hechas, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		barra.value = hechas
	if GameState.desbloqueo_libre:
		aviso.text = "MODO PRUEBA: todas las puertas abiertas (F1 para desactivar)"
	else:
		aviso.text = "WASD / flechas: mover     E: entrar     M: mapa"


## Primer clic: pide confirmación (3 s).
func _salir_al_menu() -> void:
	if fase_abierta != -1:
		return
	if not _salir_armado:
		_salir_armado = true
		boton_salir.text = "¿Seguro? Clic otra vez"
		boton_salir.add_theme_color_override("font_color", Color("#f5d742"))
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(boton_salir) and _salir_armado:
			_salir_armado = false
			boton_salir.text = "Salir al menú"
			boton_salir.remove_theme_color_override("font_color")
		return
	_salir_armado = false
	if GameState.es_red():
		Red.cerrar()
	GameState.reiniciar()
	Transicion.ir_a("res://menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _relevo_abierto:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			if GameState.es_red():
				return   # el modo prueba no existe en red (rompería la sincronización)
			GameState.desbloqueo_libre = not GameState.desbloqueo_libre
			GameState.progreso_cambio.emit()
		elif event.keycode == KEY_M and fase_abierta == -1:
			mapa.alternar()
	if event.is_action_pressed("ui_cancel"):
		if fase_abierta != -1:
			cerrar_fase()
		elif mapa.ampliado:
			mapa.alternar()


# ---------------------------------------------------------------- multijugador (relevos)

## Texto "TURNO DE: Ana (2 Laboratorio)" arriba a la izquierda.
func _actualizar_turno() -> void:
	if etiqueta_turno == null:
		return
	var f := GameState.fase_en_turno()
	etiqueta_turno.visible = GameState.es_multijugador() and f != -1 and f < GameState.asignaciones.size()
	if etiqueta_turno.visible:
		etiqueta_turno.text = "TURNO DE: %s  (%s)" % [GameState.dueno_de(f), GameState.FASES[f]["nombre"]]
		etiqueta_turno.add_theme_color_override("font_color", GameState.color_jugador(GameState.asignaciones[f]))
		if GameState.es_red() and GameState.asignaciones[f] == GameState.mi_indice:
			etiqueta_turno.text = "¡ES TU TURNO!  (%s)" % GameState.FASES[f]["nombre"]


## Pantalla completa con un mensaje y un botón.
func _construir_relevo() -> void:
	capa_relevo = CanvasLayer.new()
	capa_relevo.layer = 20
	capa_relevo.visible = false
	add_child(capa_relevo)

	var velo := ColorRect.new()
	velo.color = Color(0.02, 0.03, 0.08, 0.90)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	capa_relevo.add_child(velo)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	capa_relevo.add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var est := _estilo(Color(0.04, 0.06, 0.10, 0.97), Color("#f5d742"), 3, 12)
	est.set_content_margin_all(28)
	_relevo_estilo = est
	panel.add_theme_stylebox_override("panel", est)
	centro.add_child(panel)

	# Astronauta con el color del jugador que recibe el control (arriba de la pantalla)
	_relevo_astro = Astronauta.new()
	_relevo_astro.flotar = true
	_relevo_astro.polvo_activo = false
	_relevo_astro.scale = Vector2(2.2, 2.2)
	_relevo_astro.visible = false
	capa_relevo.add_child(_relevo_astro)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 16)
	panel.add_child(caja)

	_relevo_titulo = Label.new()
	_relevo_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Estilo.texto(_relevo_titulo, 32, Color("#f5d742"))
	caja.add_child(_relevo_titulo)

	_relevo_lista = VBoxContainer.new()
	_relevo_lista.add_theme_constant_override("separation", 4)
	caja.add_child(_relevo_lista)

	_relevo_texto = Label.new()
	_relevo_texto.custom_minimum_size = Vector2(620, 0)
	_relevo_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_relevo_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Estilo.texto(_relevo_texto, 20)
	caja.add_child(_relevo_texto)

	_relevo_boton = Button.new()
	_relevo_boton.custom_minimum_size = Vector2(0, 54)
	_relevo_boton.add_theme_font_size_override("font_size", 22)
	_relevo_boton.pressed.connect(_cerrar_relevo)
	caja.add_child(_relevo_boton)


## lineas: [[texto, color], ...] filas de colores (para el reparto). traje: si tiene alfa > 0,
## muestra un astronauta con ese color de traje.
func _mostrar_relevo(titulo: String, texto: String, boton: String, color: Color = Color("#f5d742"),
		lineas: Array = [], traje: Color = Color(0, 0, 0, 0)) -> void:
	_relevo_abierto = true
	hub.process_mode = Node.PROCESS_MODE_DISABLED
	_relevo_estilo.border_color = color
	_relevo_titulo.add_theme_color_override("font_color", color)
	_relevo_titulo.text = titulo
	for c in _relevo_lista.get_children():
		_relevo_lista.remove_child(c)
		c.queue_free()
	for l in lineas:
		var lb := Label.new()
		lb.text = String(l[0])
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Estilo.texto(lb, 22, l[1])
		_relevo_lista.add_child(lb)
	_relevo_texto.text = texto
	_relevo_texto.visible = texto != ""
	_relevo_astro.visible = traje.a > 0.0
	if _relevo_astro.visible:
		_relevo_astro.color_traje = traje
		_relevo_astro.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5, 96.0)
	_relevo_boton.text = boton
	capa_relevo.visible = true
	_relevo_boton.grab_focus()


func _cerrar_relevo() -> void:
	_relevo_abierto = false
	capa_relevo.visible = false
	if fase_abierta == -1:
		hub.process_mode = Node.PROCESS_MODE_INHERIT


## Al empezar la partida: quién juega cada fase, cada jugador con su color.
func _mostrar_reparto() -> void:
	var lineas: Array = []
	for i in GameState.FASES.size():
		var j: int = GameState.asignaciones[i]
		var marca := "   ← TÚ" if GameState.es_red() and j == GameState.mi_indice else ""
		lineas.append(["%s   →   %s (%s)%s" % [GameState.FASES[i]["nombre"], GameState.dueno_de(i), GameState.nombre_color(j), marca], GameState.color_jugador(j)])
	var texto := "Cada fase necesita la anterior, así que se juega por relevos.\nEl astronauta cambia de color según a quién le toque.\nEmpieza %s." % GameState.dueno_de(0)
	if GameState.es_red():
		texto = "Cada quien juega SU fase en su dispositivo cuando le toque.\nEmpieza %s." % GameState.dueno_de(0)
	_mostrar_relevo("REPARTO DE FASES", texto, "¡Comenzar!", Color("#f5d742"), lineas)


## Cuando el turno pasa a otra persona: se le avisa, con su color, y el astronauta vuelve al mando.
func _mostrar_relevo_turno() -> void:
	var f := GameState.fase_en_turno()
	if f == -1:
		return
	var j := GameState.jugador_en_turno()
	var nombre := GameState.dueno_de(f)
	hub.jugador.position = hub.centro_area(0) + Vector2(0, 48)
	var texto := "Pasa el control a\n%s\n\nSu astronauta es de color %s.\nLe toca la fase %s:\n%s" % [
		nombre, GameState.nombre_color(j).to_upper(), GameState.FASES[f]["nombre"], GameState.FASES[f]["tarea"]]
	_mostrar_relevo("RELEVO", texto, "Soy %s, ¡listo!" % nombre, GameState.color_jugador(j), [], GameState.traje_de(j))


# ---------------------------------------------------------------- multijugador en red

## Cambió quién tiene el turno: si ahora es mío, aviso.
func _turno_red() -> void:
	var j := GameState.jugador_en_turno()
	if j == _turno_previo:
		return
	_turno_previo = j
	if j == GameState.mi_indice and not GameState.todas_completas():
		var f := GameState.fase_en_turno()
		_mostrar_aviso("¡ES TU TURNO!", "Ve a: " + String(GameState.FASES[f]["nombre"]))


## Llegó el estado compartido: si ya están las 5 fases, termina la partida en todos los dispositivos.
func _revisar_fin_red() -> void:
	if _fin_red or not GameState.todas_completas():
		return
	_fin_red = true
	if fase_abierta != -1:
		cerrar_fase()
	_mostrar_aviso("¡MISIÓN COMPLETADA!", "Regresando al menú...")
	await get_tree().create_timer(2.8).timeout
	Red.cerrar()
	GameState.reiniciar()
	Transicion.ir_a("res://menu.tscn")


func _jugador_se_fue(nombre: String) -> void:
	_mostrar_aviso("%s SE DESCONECTÓ" % nombre.to_upper(), "Sus fases pendientes pasaron a otros jugadores")


## Se perdió al anfitrión: no se puede seguir.
func _host_perdido(motivo: String) -> void:
	if _fin_red:
		return
	_fin_red = true
	if fase_abierta != -1:
		cerrar_fase()
	_mostrar_aviso("CONEXIÓN PERDIDA", motivo)
	await get_tree().create_timer(2.5).timeout
	GameState.reiniciar()
	Transicion.ir_a("res://menu.tscn")
