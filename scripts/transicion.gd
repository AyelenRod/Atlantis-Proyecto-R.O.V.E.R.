extends CanvasLayer
## Autoload "Transicion": fundido a negro entre escenas y destello al cerrar una fase.

var cortina: ColorRect
var destello_rect: ColorRect
var ocupado := false


func _ready() -> void:
	layer = 100
	cortina = _rect(Color("#05060d"))
	destello_rect = _rect(Color("#cfe9ff"))


func _rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate.a = 0.0
	add_child(r)
	return r


## Cambia de escena con fundido a negro.
func ir_a(ruta: String) -> void:
	if ocupado:
		return
	ocupado = true
	cortina.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(cortina, "modulate:a", 1.0, 0.3)
	await t.finished
	get_tree().change_scene_to_file(ruta)
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(cortina, "modulate:a", 0.0, 0.35)
	await t2.finished
	cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ocupado = false


## Destello rápido (al volver de una fase a la base).
func destello(duracion: float = 0.3) -> void:
	destello_rect.modulate.a = 0.55
	var t := create_tween()
	t.tween_property(destello_rect, "modulate:a", 0.0, duracion)
