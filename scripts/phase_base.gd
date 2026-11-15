class_name PhaseBase
extends Control
## Clase base de TODAS las fases.

signal fase_terminada


func terminar() -> void:
	fase_terminada.emit()


## Pantalla temporal para fases que aún no se desarrollan.
## Cuando hagas la fase real, borra la llamada a esta función.
func crear_placeholder(titulo: String, descripcion: String) -> void:
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 20)
	centro.add_child(caja)

	var t := Label.new()
	t.text = titulo
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 40)
	caja.add_child(t)

	var d := Label.new()
	d.text = descripcion
	d.custom_minimum_size = Vector2(700, 0)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_theme_font_size_override("font_size", 22)
	caja.add_child(d)

	var b := Button.new()
	b.text = "Continuar (placeholder)"
	b.custom_minimum_size = Vector2(260, 50)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(terminar)
	caja.add_child(b)
