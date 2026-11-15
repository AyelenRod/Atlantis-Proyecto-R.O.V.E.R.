class_name MesaMando
extends Node2D
## Mesa redonda de la sala de mando con el botón rojo que pulsa.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for k in 6:
		var a := TAU * float(k) / 6.0
		var banco := Vector2(cos(a), sin(a)) * 108.0
		draw_circle(banco, 15.0, Color("#3a4357"))
		draw_arc(banco, 15.0, 0.0, TAU, 20, Color("#161b29"), 3.0)
	draw_circle(Vector2(0, 6), 72.0, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, 72.0, Color("#5b6579"))
	draw_arc(Vector2.ZERO, 72.0, 0.0, TAU, 48, Color("#2b3345"), 5.0)
	draw_circle(Vector2.ZERO, 36.0, Color("#3f485c"))
	var pulso := 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(Vector2.ZERO, 30.0 + pulso * 8.0, Color(1, 0.1, 0.1, 0.10 + 0.15 * pulso))
	draw_circle(Vector2(0, 3), 24.0, Color("#7a1414"))
	draw_circle(Vector2.ZERO, 20.0, Color("#e11d1d"))
	draw_circle(Vector2(-7, -7), 6.0, Color(1, 0.6, 0.6, 0.7))
	draw_string(ThemeDB.fallback_font, Vector2(-110, -150), "SALA DE MANDO",
		HORIZONTAL_ALIGNMENT_CENTER, 220, 20, Color(1, 1, 1, 0.35))
