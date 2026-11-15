# Controla partículas de explosión, chispas de fallo crítico, onda expansiva y sacudida
extends Node2D
class_name EfectosFallo

var _particulas_fuego: CPUParticles2D
var _particulas_escombros: CPUParticles2D
var _radio_onda: float = 0.0
var _alpha_onda: float = 0.0
var _centro_explosion: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Capa 1: Fuego y plasma de explosión
	_particulas_fuego = CPUParticles2D.new()
	_particulas_fuego.emitting = false
	_particulas_fuego.one_shot = true
	_particulas_fuego.explosiveness = 0.92
	_particulas_fuego.amount = 56
	_particulas_fuego.lifetime = 0.95
	_particulas_fuego.spread = 180.0
	_particulas_fuego.gravity = Vector2.ZERO
	_particulas_fuego.initial_velocity_min = 60.0
	_particulas_fuego.initial_velocity_max = 260.0
	_particulas_fuego.scale_amount_min = 4.0
	_particulas_fuego.scale_amount_max = 11.0
	_particulas_fuego.color = Color(1.0, 0.45, 0.12, 1.0)
	add_child(_particulas_fuego)

	# Capa 2: Chispas metálicas y fragmentos críticos
	_particulas_escombros = CPUParticles2D.new()
	_particulas_escombros.emitting = false
	_particulas_escombros.one_shot = true
	_particulas_escombros.explosiveness = 0.96
	_particulas_escombros.amount = 36
	_particulas_escombros.lifetime = 1.25
	_particulas_escombros.spread = 180.0
	_particulas_escombros.gravity = Vector2(0, 40)
	_particulas_escombros.initial_velocity_min = 120.0
	_particulas_escombros.initial_velocity_max = 380.0
	_particulas_escombros.scale_amount_min = 2.0
	_particulas_escombros.scale_amount_max = 5.0
	_particulas_escombros.color = Color(1.0, 0.86, 0.40, 1.0)
	add_child(_particulas_escombros)


func detonar_explosion(pos_global: Vector2, nodo_sacudir: Node2D = null) -> void:
	_centro_explosion = pos_global
	_particulas_fuego.global_position = pos_global
	_particulas_escombros.global_position = pos_global
	_particulas_fuego.restart()
	_particulas_escombros.restart()
	_particulas_fuego.emitting = true
	_particulas_escombros.emitting = true

	# Onda expansiva radial
	_radio_onda = 8.0
	_alpha_onda = 0.95
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "_radio_onda", 160.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_alpha_onda", 0.0, 0.65)

	# Sacudida breve del escenario si se proporciona nodo raíz de juego
	if nodo_sacudir != null:
		var orig := nodo_sacudir.position
		var tw_shake := create_tween()
		for i in range(6):
			var offset := Vector2(randf_range(-10, 10), randf_range(-10, 10)) * (1.0 - float(i) / 6.0)
			tw_shake.tween_property(nodo_sacudir, "position", orig + offset, 0.05)
		tw_shake.tween_property(nodo_sacudir, "position", orig, 0.05)


func _process(_delta: float) -> void:
	if _alpha_onda > 0.01:
		queue_redraw()


func _draw() -> void:
	if _alpha_onda > 0.01:
		draw_arc(_centro_explosion, _radio_onda, 0.0, TAU, 48, Color(1.0, 0.55, 0.18, _alpha_onda), 4.0, true)
