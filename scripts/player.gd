class_name Player
extends CharacterBody2D
## Astronauta que se mueve por la base (WASD o flechas).

const VELOCIDAD := 320.0

var astronauta: Astronauta


static func registrar_controles() -> void:
	_accion("mover_izq", [KEY_A, KEY_LEFT])
	_accion("mover_der", [KEY_D, KEY_RIGHT])
	_accion("mover_arriba", [KEY_W, KEY_UP])
	_accion("mover_abajo", [KEY_S, KEY_DOWN])
	_accion("interactuar", [KEY_E, KEY_ENTER])


static func _accion(nombre: String, teclas: Array) -> void:
	if InputMap.has_action(nombre):
		return
	InputMap.add_action(nombre)
	for k in teclas:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(nombre, ev)


func _ready() -> void:
	registrar_controles()
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 15.0
	forma.shape = circulo
	add_child(forma)
	astronauta = Astronauta.new()
	add_child(astronauta)
	# Multijugador: el astronauta toma el color del jugador que tiene el turno.
	GameState.turno_cambio.connect(_actualizar_color)
	GameState.progreso_cambio.connect(_actualizar_color)
	_actualizar_color()


func _actualizar_color() -> void:
	astronauta.color_traje = GameState.traje_en_turno()


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("mover_izq", "mover_der", "mover_arriba", "mover_abajo")
	velocity = dir * VELOCIDAD
	move_and_slide()
	astronauta.caminando = dir != Vector2.ZERO
	if dir.x != 0.0:
		astronauta.cara = signf(dir.x)
