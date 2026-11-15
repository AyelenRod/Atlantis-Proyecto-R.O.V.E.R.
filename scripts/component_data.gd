class_name ComponentData
extends Resource
## Una pieza de la nave.

@export var id: String
@export var nombre: String
@export var categoria: String   # energia, comunicacion, instrumento, estructura, computadora, propulsion
@export var icono: Texture2D
@export var masa_kg: float
@export var energia_w: float    # positivo = genera, negativo = consume
@export var costo: float
@export var datos_mbps: float   # datos que produce (instrumentos)
@export var riesgo_falla: float # de 0.0 a 1.0
@export_multiline var descripcion: String
