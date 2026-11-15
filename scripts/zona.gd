class_name Zona
extends Area2D
## Consola de tarea de una fase.

signal entrar_solicitado(indice: int)

const COLOR_LISTA := Color("#4ade80")
const COLOR_BLOQUEADA := Color("#6b7280")
const COLOR_DISPONIBLE := Color("#f5d742")   # amarillo de tarea

var indice := 0
var nombre := ""
var tam := Vector2(240, 150)
var jugador_dentro := false
var etiqueta_nombre: Label
var etiqueta_estado: Label
var tiempo := 0.0
var particulas: CPUParticles2D
var _lista_previa := false
var _listo := false


func configurar(i: int, n: String, pos: Vector2) -> void:
	indice = i
	nombre = n
	position = pos


func _ready() -> void:
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = tam
	forma.shape = rect
	add_child(forma)

	etiqueta_nombre = _crear_etiqueta(Vector2(-tam.x / 2.0, -tam.y / 2.0 - 8.0), Vector2(tam.x, 30.0), 20)
	etiqueta_estado = _crear_etiqueta(Vector2(-tam.x / 2.0, 34.0), Vector2(tam.x, 44.0), 15)
	etiqueta_nombre.text = nombre

	# Explosión de partículas al completar la tarea
	particulas = CPUParticles2D.new()
	particulas.position = Vector2(0, -10)
	particulas.one_shot = true
	particulas.emitting = false
	particulas.amount = 28
	particulas.lifetime = 1.0
	particulas.explosiveness = 0.95
	particulas.local_coords = false
	particulas.direction = Vector2(0, -1)
	particulas.spread = 180.0
	particulas.gravity = Vector2(0, 260)
	particulas.initial_velocity_min = 90.0
	particulas.initial_velocity_max = 190.0
	particulas.scale_amount_min = 3.0
	particulas.scale_amount_max = 5.0
	var g := Gradient.new()
	g.set_color(0, Color("#4ade80"))
	g.set_color(1, Color(0.96, 0.84, 0.26, 0.0))
	particulas.color_ramp = g
	particulas.z_index = 5
	add_child(particulas)

	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)
	GameState.progreso_cambio.connect(_actualizar)
	GameState.turno_cambio.connect(_actualizar)
	_actualizar()
	_listo = true


func _crear_etiqueta(pos: Vector2, tamano: Vector2, fuente: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = tamano
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Estilo.texto(l, fuente)
	add_child(l)
	return l


func _al_entrar(cuerpo: Node) -> void:
	if cuerpo is Player:
		jugador_dentro = true
		_actualizar()


func _al_salir(cuerpo: Node) -> void:
	if cuerpo is Player:
		jugador_dentro = false
		_actualizar()


func _unhandled_input(event: InputEvent) -> void:
	if jugador_dentro and event.is_action_pressed("interactuar") and GameState.fase_disponible(indice):
		entrar_solicitado.emit(indice)
		get_viewport().set_input_as_handled()


func _hay_marcador() -> bool:
	return GameState.fase_disponible(indice) and not GameState.fases_completadas[indice]


func _process(delta: float) -> void:
	tiempo += delta
	queue_redraw()


func celebrar() -> void:
	particulas.restart()


func _color_estado() -> Color:
	if GameState.fases_completadas[indice]:
		return COLOR_LISTA
	if not GameState.fase_disponible(indice):
		return COLOR_BLOQUEADA
	return COLOR_DISPONIBLE


func _actualizar() -> void:
	if etiqueta_estado == null:
		return
	var dueno := GameState.dueno_de(indice)
	var sufijo := ("\nFase de " + dueno) if dueno != "" else ""
	if not GameState.fase_desbloqueada(indice):
		etiqueta_estado.text = "Puerta cerrada: completa la fase anterior" + sufijo
	elif GameState.fases_completadas[indice] and not GameState.fase_disponible(indice):
		etiqueta_estado.text = "Completada" + sufijo
	elif not GameState.es_fase_del_turno(indice):
		etiqueta_estado.text = "Esta fase es de " + dueno
	elif jugador_dentro:
		etiqueta_estado.text = "Presiona E para usar" + sufijo
	elif GameState.fases_completadas[indice]:
		etiqueta_estado.text = "Completada" + sufijo
	else:
		etiqueta_estado.text = "Disponible" + sufijo
	var lista: bool = GameState.fases_completadas[indice]
	if lista and not _lista_previa and _listo:
		celebrar()
	_lista_previa = lista
	var c := _color_estado()
	etiqueta_nombre.add_theme_color_override("font_color", c.lightened(0.3))
	etiqueta_estado.add_theme_color_override("font_color", c.lightened(0.3))
	queue_redraw()


# Dibujo temporal de la consola: reemplázalo por un sprite.
func _draw() -> void:
	var c := _color_estado()
	var lista: bool = GameState.fases_completadas[indice]
	var activa := _hay_marcador()
	var pulso := 0.5 + 0.5 * sin(tiempo * 3.0)

	# Área de uso (pulsa si hay una tarea disponible)
	var area := Rect2(-tam / 2.0, tam)
	var relleno := 0.08
	var borde := 0.3
	if jugador_dentro:
		relleno = 0.22
		borde = 0.9
	elif activa:
		relleno = 0.06 + 0.06 * pulso
		borde = 0.25 + 0.3 * pulso
	draw_rect(area, Color(c, relleno), true)
	draw_rect(area, Color(c, borde), false, 4.0 if jugador_dentro else 2.0)

	# Consola
	var consola := Rect2(-48, -26, 96, 52)
	draw_rect(Rect2(consola.position + Vector2(0, 6), consola.size), Color(0, 0, 0, 0.35))
	draw_rect(consola, Color("#2b3347"))
	draw_rect(consola, Color("#0d1117"), false, 3.0)
	var pantalla := Rect2(consola.position + Vector2(8, 8), Vector2(80, 24))
	var brillo := 0.25 if c == COLOR_BLOQUEADA else 0.9
	draw_rect(pantalla, Color(c, brillo))
	if c != COLOR_BLOQUEADA:
		# Línea de escaneo que recorre la pantalla
		var y := pantalla.position.y + fposmod(tiempo * 22.0, pantalla.size.y)
		draw_line(Vector2(pantalla.position.x, y), Vector2(pantalla.end.x, y), Color(1, 1, 1, 0.35), 2.0)
	if lista:
		draw_polyline(PackedVector2Array([
			pantalla.position + Vector2(24, 13), pantalla.position + Vector2(34, 20),
			pantalla.position + Vector2(56, 6)]), Color("#0d1117"), 4.0)
	draw_rect(pantalla, Color("#0d1117"), false, 2.0)
	for k in 3:
		var parpadeo := 0.9 if c != COLOR_BLOQUEADA else 0.3
		draw_circle(Vector2(-28 + k * 28, 20), 4.0, Color(c, parpadeo))

	# Marcador "!" amarillo flotando, como las tareas de Among Us
	if activa:
		var bob := sin(tiempo * 4.0) * 5.0
		var fuente := ThemeDB.fallback_font
		var pos := Vector2(-10, -96 + bob)
		draw_string_outline(fuente, pos, "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 40, 8, Color.BLACK)
		draw_string(fuente, pos, "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 40, COLOR_DISPONIBLE)
