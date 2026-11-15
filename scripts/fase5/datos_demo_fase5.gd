class_name DatosDemoFase5
extends RefCounted

static func pieza(id: String, nombre: String, cat: String, masa: float, energia: float, costo: float, datos := 0.0, riesgo := 0.05) -> ComponentData:
	var c := ComponentData.new()
	c.id = id
	c.nombre = nombre
	c.categoria = cat
	c.masa_kg = masa
	c.energia_w = energia
	c.costo = costo
	c.datos_mbps = datos
	c.riesgo_falla = riesgo
	return c


static func cargar() -> void:
	# No usamos iniciar_nivel() ni configurar_partida(): reiniciarían el progreso de la partida.
	if GameState.destino == "":
		# Sin Fase 1 confirmada: primer destino del nivel (NIVELES viene de fase1_datos.gd).
		var destinos: Dictionary = GameState.NIVELES[GameState.nivel_actual()]["destinos"]
		GameState.destino = destinos.keys()[0]
	# Costos en millones (M): la nave de demo cuesta 95 M, cabe en el saldo de cualquier nivel.
	var piezas := [
		pieza("panel_solar_basico", "Panel solar básico", "energia", 5.0, 40.0, 8.0),
		pieza("panel_solar_basico", "Panel solar básico", "energia", 5.0, 40.0, 8.0),
		pieza("antena_alta_ganancia", "Antena de alta ganancia", "comunicacion", 8.0, -15.0, 12.0, 0.0, 0.08),
		pieza("computadora_vuelo", "Computadora de vuelo", "computadora", 4.0, -20.0, 18.0, 0.0, 0.03),
		pieza("motor_ionico", "Motor iónico", "propulsion", 30.0, -30.0, 30.0, 0.0, 0.10),
		pieza("camara_multiespectral", "Cámara multiespectral", "instrumento", 6.0, -10.0, 14.0, 3.0, 0.06),
		pieza("estructura_ligera", "Estructura ligera", "estructura", 40.0, 0.0, 5.0),
	]
	# Se agregan directo (sin pasar por agregar()) para que la demo siempre tenga la nave completa;
	# si se pasa del presupuesto, la Fase 5 lo marcará como falla, que es lo correcto.
	for p in piezas:
		GameState.componentes.append(p)
	GameState.recursos_cambiaron.emit()
	if GameState.ruta == "":
		GameState.ruta = "Transferencia de Hohmann"
	if GameState.eventos_resueltos.is_empty():
		GameState.eventos_resueltos = ["Tormenta solar", "Micrometeoritos"]
