extends Control
class_name FondoOrbital

enum Entorno {
	ORBITA_TERRESTRE = 1,
	ATERRIZAJE_PLANETARIO = 2,
	SONDA_SOLAR = 3,
	ATERRIZAJE_LUNA = 4,
	JUPITER = 5,
}

@export var entorno: Entorno = Entorno.ORBITA_TERRESTRE:
	set(valor):
		entorno = valor
		queue_redraw()

@export var cantidad_estrellas: int = 160
@export var desplazamiento_parallax: Vector2 = Vector2.ZERO

var _estrellas: Array[Dictionary] = []
var _tiempo: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_generar_estrellas()


func _generar_estrellas() -> void:
	_estrellas.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040 + int(entorno) * 77
	for i in range(cantidad_estrellas):
		_estrellas.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"radio": rng.randf_range(0.7, 2.2),
			"brillo": rng.randf_range(0.35, 0.95),
			"velocidad_parpadeo": rng.randf_range(0.8, 2.8),
			"fase": rng.randf_range(0.0, TAU),
			"profundidad": rng.randf_range(0.15, 0.85),
			"tinte": Color(0.88, 0.92, 1.0) if rng.randf() > 0.25 else Color(1.0, 0.86, 0.68),
		})


func _process(delta: float) -> void:
	_tiempo += delta
	queue_redraw()


func _draw() -> void:
	var tam := size
	if tam.x <= 0.0 or tam.y <= 0.0:
		return

	_dibujar_cielo_base(tam)
	_dibujar_nebulosa(tam)

	for est in _estrellas:
		var par := desplazamiento_parallax * float(est["profundidad"]) * 0.03
		var px := fposmod(float(est["pos"].x) * tam.x - par.x, tam.x)
		var py := fposmod(float(est["pos"].y) * tam.y - par.y, tam.y)
		var pulso := 0.72 + 0.28 * sin(_tiempo * float(est["velocidad_parpadeo"]) + float(est["fase"]))
		var col: Color = est["tinte"]
		col.a = float(est["brillo"]) * pulso
		if entorno == Entorno.SONDA_SOLAR:
			col.a *= 0.45
		draw_circle(Vector2(px, py), float(est["radio"]), col)

	match entorno:
		Entorno.ORBITA_TERRESTRE:
			_dibujar_horizonte_terrestre(tam)
		Entorno.ATERRIZAJE_PLANETARIO:
			_dibujar_atmosfera_planetaria(tam)
		Entorno.ATERRIZAJE_LUNA:
			_dibujar_cielo_lunar(tam)
		Entorno.SONDA_SOLAR:
			_dibujar_corona_solar(tam)
		Entorno.JUPITER:
			_dibujar_jupiter(tam)


func _dibujar_cielo_base(tam: Vector2) -> void:
	var c_top := Color("#05040D")
	var c_bot := Color("#100D26")
	match entorno:
		Entorno.ATERRIZAJE_PLANETARIO:
			c_top = Color("#080714")
			c_bot = Color("#281316")
		Entorno.ATERRIZAJE_LUNA:
			c_top = Color("#030308")
			c_bot = Color("#0D101B")
		Entorno.SONDA_SOLAR:
			c_top = Color("#0B060D")
			c_bot = Color("#2B1108")
		Entorno.JUPITER:
			c_top = Color("#05040F")
			c_bot = Color("#1A1228")

	var pasos := 18
	for i in range(pasos):
		var t := float(i) / float(pasos)
		var y0 := t * tam.y
		var h := (tam.y / float(pasos)) + 1.0
		draw_rect(Rect2(0.0, y0, tam.x, h), c_top.lerp(c_bot, t))


func _dibujar_nebulosa(tam: Vector2) -> void:
	var col_neb := Color(0.32, 0.22, 0.62, 0.07)
	if entorno == Entorno.SONDA_SOLAR:
		col_neb = Color(0.85, 0.35, 0.10, 0.08)
	elif entorno == Entorno.ATERRIZAJE_PLANETARIO:
		col_neb = Color(0.58, 0.25, 0.20, 0.06)
	elif entorno == Entorno.JUPITER:
		col_neb = Color(0.55, 0.36, 0.24, 0.07)
	elif entorno == Entorno.ATERRIZAJE_LUNA:
		col_neb = Color(0.22, 0.28, 0.48, 0.04)

	draw_circle(Vector2(tam.x * 0.22, tam.y * 0.28), tam.x * 0.28, col_neb)
	draw_circle(Vector2(tam.x * 0.72, tam.y * 0.36), tam.x * 0.22, col_neb * Color(1, 1, 1, 0.7))


func _dibujar_horizonte_terrestre(tam: Vector2) -> void:
	var centro_tierra := Vector2(tam.x * 0.42, tam.y * 2.12)
	var radio_tierra := tam.y * 1.42
	for i in range(6):
		var extra := 48.0 - float(i) * 8.0
		var alpha := 0.04 + float(i) * 0.025
		draw_circle(centro_tierra, radio_tierra + extra, Color(0.22, 0.56, 0.98, alpha))
	draw_circle(centro_tierra, radio_tierra, Color("#0A1D3B"))
	draw_arc(centro_tierra, radio_tierra + 2.0, -PI * 0.78, -PI * 0.22, 96, Color(0.45, 0.80, 1.0, 0.55), 3.0, true)


func _dibujar_atmosfera_planetaria(tam: Vector2) -> void:
	var centro := Vector2(tam.x * 0.5, tam.y * 2.35)
	var radio := tam.y * 1.50
	for i in range(5):
		var extra := 50.0 - float(i) * 10.0
		draw_circle(centro, radio + extra, Color(0.86, 0.42, 0.22, 0.045))


func _dibujar_cielo_lunar(tam: Vector2) -> void:
	# Tierra distante en el cielo negro del vacío lunar
	var pos_tierra := Vector2(tam.x * 0.16, tam.y * 0.26)
	draw_circle(pos_tierra, 34.0, Color(0.24, 0.58, 0.96, 0.18))
	draw_circle(pos_tierra, 28.0, Color("#1E4E8C"))
	draw_arc(pos_tierra, 28.0, -0.5, 2.2, 24, Color("#60A5FA"), 3.0, true)


func _dibujar_corona_solar(tam: Vector2) -> void:
	var centro_sol := Vector2(-tam.x * 0.14, tam.y * 0.52)
	var radio_base := tam.y * 0.42
	var pulso := 1.0 + 0.018 * sin(_tiempo * 2.2)

	for i in range(8):
		var f := float(i) / 8.0
		var r := (radio_base * (2.35 - f * 1.25)) * pulso
		var col := Color(1.0, 0.42, 0.08, 0.055 + f * 0.045)
		draw_circle(centro_sol, r, col)

	draw_circle(centro_sol, radio_base * 0.98, Color("#FF7A1A"))
	draw_circle(centro_sol, radio_base * 0.86, Color("#FFBE42"))
	draw_circle(centro_sol, radio_base * 0.70, Color("#FFF3C4"))


func _dibujar_jupiter(tam: Vector2) -> void:
	# Júpiter gigante en el horizonte derecho-inferior con bandas atmosféricas y Gran Mancha Roja
	var centro := Vector2(tam.x * 0.88, tam.y * 0.78)
	var radio := tam.y * 0.46
	draw_circle(centro, radio + 24.0, Color(0.82, 0.58, 0.36, 0.08))
	draw_circle(centro, radio, Color("#C99E76"))
	# Bandas ecuatoriales estilizadas
	for i in range(-3, 4):
		var y_off := float(i) * (radio * 0.21)
		var half_w := sqrt(maxf(0.0, radio * radio - y_off * y_off)) * 0.96
		var col_banda := Color("#9A5B3A") if i % 2 == 0 else Color("#E3C7A4")
		col_banda.a = 0.65
		draw_line(
			Vector2(centro.x - half_w, centro.y + y_off),
			Vector2(centro.x + half_w, centro.y + y_off),
			col_banda,
			10.0
		)
	# Gran Mancha Roja
	draw_circle(centro + Vector2(-radio * 0.32, radio * 0.18), 20.0, Color("#B4432A"))
