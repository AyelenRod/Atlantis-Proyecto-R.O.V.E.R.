class_name Puerta
extends StaticBody2D
## Puerta corrediza.

var indice := 0
var tam := Vector2(32, 96)
var forma: CollisionShape2D
var tiempo := 0.0
var apertura := 0.0:      # 0 = cerrada, 1 = abierta
	set(v):
		apertura = v
		queue_redraw()
var _inicializada := false
var _tween: Tween


func configurar(i: int, t: Vector2) -> void:
	indice = i
	tam = t


func _ready() -> void:
	forma = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = tam
	forma.shape = rect
	add_child(forma)
	GameState.progreso_cambio.connect(_actualizar)
	_actualizar()


func esta_abierta() -> bool:
	return GameState.fase_desbloqueada(indice)


func _actualizar() -> void:
	var abierta := esta_abierta()
	forma.set_deferred("disabled", abierta)
	var objetivo := 1.0 if abierta else 0.0
	if not _inicializada:
		_inicializada = true
		apertura = objetivo
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "apertura", objetivo, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	tiempo += delta
	if apertura < 0.99:
		queue_redraw()


func _panel(r: Rect2) -> void:
	if r.size.x <= 0.5 or r.size.y <= 0.5:
		return
	draw_rect(r, Color("#4a5366"))
	draw_rect(r, Color("#1f2433"), false, 3.0)


# Dibujo temporal: reemplázalo por sprites de puerta corrediza.
func _draw() -> void:
	var r := Rect2(-tam / 2.0, tam)
	var horizontal := tam.x > tam.y
	var cierre := 1.0 - apertura
	var parpadeo := 0.55 + 0.45 * sin(tiempo * 6.0)
	var rojo := Color(0.94, 0.27, 0.27, parpadeo)

	if horizontal:
		var w := tam.x / 2.0 * cierre
		_panel(Rect2(r.position.x, r.position.y, w, tam.y))
		_panel(Rect2(r.end.x - w, r.position.y, w, tam.y))
		if cierre > 0.05:
			draw_rect(Rect2(-2, r.position.y + 5, 4, tam.y - 10), rojo)
		var luz := rojo if apertura < 0.5 else Color("#4ade80")
		draw_circle(Vector2(r.position.x + 4, 0), 3.0, luz)
		draw_circle(Vector2(r.end.x - 4, 0), 3.0, luz)
	else:
		var h := tam.y / 2.0 * cierre
		_panel(Rect2(r.position.x, r.position.y, tam.x, h))
		_panel(Rect2(r.position.x, r.end.y - h, tam.x, h))
		if cierre > 0.05:
			draw_rect(Rect2(r.position.x + 5, -2, tam.x - 10, 4), rojo)
		var luz2 := rojo if apertura < 0.5 else Color("#4ade80")
		draw_circle(Vector2(0, r.position.y + 4), 3.0, luz2)
		draw_circle(Vector2(0, r.end.y - 4), 3.0, luz2)
