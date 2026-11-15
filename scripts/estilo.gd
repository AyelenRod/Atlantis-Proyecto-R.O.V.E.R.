class_name Estilo
extends RefCounted
## Utilidades de estilo compartidas.


static func texto(l: Label, tam: int = 18, color: Color = Color.WHITE) -> void:
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", maxi(2, int(tam * 0.2)))
