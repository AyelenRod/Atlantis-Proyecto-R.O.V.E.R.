extends RefCounted
## Datos de la Fase 3 (Sala de lanzamiento): ritmo del viaje y catálogo de eventos de tránsito.

const RITMO := {
	"facil":   {"progreso": 7.0, "combustible": 3.0},
	"medio":   {"progreso": 7.0, "combustible": 4.5},
	"dificil": {"progreso": 7.0, "combustible": 6.0},
}

## Cuántos eventos ocurren en el tránsito según el nivel (si la ficha no trae "eventos_transito").
const EVENTOS_POR_NIVEL := {"facil": 1, "medio": 3, "dificil": 5}

## Catálogo de eventos.
## Los dos primeros son los del juego original; el resto amplía el catálogo para los niveles altos.
const EVENTOS := [
	{
		"nombre": "Desviación de trayectoria",
		"mensaje": "¡ALERTA! Desviación de trayectoria. Los sensores detectan un error de rumbo de 0.4°.",
		"opcion_a": {"texto": "Corregir el rumbo con los propulsores", "combustible": -10, "integridad": 10},
		"opcion_b": {"texto": "Continuar el viaje y corregir después", "combustible": 0, "integridad": -15},
	},
	{
		"nombre": "Falla en el sistema de energía",
		"mensaje": "¡ALERTA! Falla en el sistema de energía. Un panel solar dejó de responder.",
		"opcion_a": {"texto": "Usar energía de reserva", "combustible": -10, "integridad": 10},
		"opcion_b": {"texto": "Asumir el riesgo", "combustible": 0, "integridad": -15},
	},
	{
		"nombre": "Tormenta solar",
		"mensaje": "¡ALERTA! Tormenta solar en curso. La radiación puede dañar la electrónica.",
		"opcion_a": {"texto": "Girar la nave y proteger los instrumentos", "combustible": -8, "integridad": 5},
		"opcion_b": {"texto": "Mantener el rumbo", "combustible": 0, "integridad": -20},
	},
	{
		"nombre": "Micrometeoritos",
		"mensaje": "¡ALERTA! Nube de micrometeoritos adelante. Impactos menores en el casco.",
		"opcion_a": {"texto": "Maniobra evasiva", "combustible": -12, "integridad": 0},
		"opcion_b": {"texto": "Atravesar la nube", "combustible": 0, "integridad": -12},
	},
	{
		"nombre": "Fuga de combustible",
		"mensaje": "¡ALERTA! Caída de presión en el tanque principal: hay una fuga.",
		"opcion_a": {"texto": "Sellar la fuga (gasta reserva)", "combustible": -6, "integridad": 5},
		"opcion_b": {"texto": "Ignorarla", "combustible": -18, "integridad": 0},
	},
	{
		"nombre": "Pérdida de comunicación",
		"mensaje": "¡ALERTA! Se perdió el enlace con el control de misión durante 40 segundos.",
		"opcion_a": {"texto": "Reorientar la antena", "combustible": -5, "integridad": 0},
		"opcion_b": {"texto": "Seguir en piloto automático", "combustible": 0, "integridad": -10},
	},
]

## Datos de prueba (solo si se abre la escena sola y no hay partida).
const PRUEBA := {"nivel": "medio", "destino": "Marte", "ruta": "Transferencia de Hohmann"}
