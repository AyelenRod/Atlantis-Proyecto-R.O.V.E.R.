class_name Minimapa
extends Control
## Minimapa arriba a la derecha.

const POS_PEQUENO := Vector2(1062, 12)
const TAM_PEQUENO := Vector2(210, 132)
const POS_GRANDE := Vector2(170, 70)
const TAM_GRANDE := Vector2(940, 600)
const T := 32
const MARGEN := Vector2(6, 4)

var hub   # nodo de la base (hub.gd)
var ampliado := false
var tiempo := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aplicar()


func alternar() -> void:
	ampliado = not ampliado
	_aplicar()


func _aplicar() -> void:
	position = POS_GRANDE if ampliado else POS_PEQUENO
	size = TAM_GRANDE if ampliado else TAM_PEQUENO


func _process(delta: float) -> void:
	tiempo += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.16, 0.30, 0.82), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#6fd3ff"), false, 3.0 if ampliado else 2.0)
	if hub == null or hub.jugador == null:
		return
	var ancho_mundo: float = float(hub.MUNDO.x * T)
	var escala: float = (size.x - 12.0) / ancho_mundo
	var fuente := ThemeDB.fallback_font

	for a in hub.AREAS:
		var r: Rect2i = a["rect"]
		var f: int = a["fase"]
		var color := Color("#5c6b82")      # pasillos
		var alfa := 0.85
		if f >= 0:
			if GameState.fases_completadas[f]:
				color = Color("#4ade80")
			elif GameState.fase_desbloqueada(f):
				color = Color("#f5d742")
				alfa = 0.6 + 0.3 * sin(tiempo * 4.0)   # la tarea disponible parpadea
			else:
				color = Color("#6b7280")
		elif r.size.x >= 14 and r.size.y >= 10:
			color = Color("#9fb4c9")        # sala de mando
		var pos: Vector2 = Vector2(r.position) * T * escala + MARGEN
		var tam: Vector2 = Vector2(r.size) * T * escala
		draw_rect(Rect2(pos, tam), Color(color, alfa), true)
		draw_rect(Rect2(pos, tam), Color("#dff3ff"), false, 1.5)
		if ampliado and (f >= 0 or (r.size.x >= 14 and r.size.y >= 10)):
			var nombre := "Sala de mando"
			if f >= 0:
				nombre = GameState.FASES[f]["nombre"]
				if GameState.dueno_de(f) != "":
					nombre += " (" + GameState.dueno_de(f) + ")"
			draw_string(fuente, pos + Vector2(0, tam.y / 2.0 + 6.0), nombre,
				HORIZONTAL_ALIGNMENT_CENTER, tam.x, 18, Color("#0b1320"))

	var yo: Vector2 = hub.jugador.position * escala + MARGEN
	var radio := 6.0 if ampliado else 3.5
	var onda := fposmod(tiempo * 1.5, 1.0)
	draw_circle(yo, radio + 2.0 + onda * 8.0, Color(1, 1, 1, 0.35 * (1.0 - onda)))
	draw_circle(yo, radio + 1.5, Color.WHITE)
	draw_circle(yo, radio, Color("#ff9f1c"))
