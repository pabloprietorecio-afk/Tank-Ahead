class_name TankStats
extends Resource
## Estadísticas de un tanque (jugador o enemigo). Las mejoras serán modificadores sobre estos valores.

@export_group("Identidad")
@export var display_name: String = "TANK"
@export var color: Color = Color(0.2, 1.0, 0.33)
@export var body_scale: float = 1.0
@export var score_value: int = 0
## Nivel de amenaza (1-3). Las oleadas lo usan para introducir enemigos poco a poco.
@export var tier: int = 1
@export_multiline var description: String = ""

@export_group("Modelo")
@export var hull_proportions: Vector3 = Vector3.ONE
@export var turret_scale: float = 1.0
@export var barrel_count: int = 1
@export var barrel_length: float = 1.0
@export var barrel_thickness: float = 1.0
@export var has_tracks: bool = true
@export var has_antenna: bool = false
@export var has_dome: bool = false

@export_group("Movimiento")
@export var max_speed: float = 14.0
@export var acceleration: float = 18.0
@export var hull_turn_speed: float = 1.3
@export var turret_turn_speed: float = 3.0

@export_group("Combate")
@export var max_armor: float = 100.0
@export var reload_time: float = 1.2
@export var damage: float = 25.0
@export var projectile_speed: float = 150.0

@export_group("IA")
@export var detect_range: float = 100.0
@export var attack_range: float = 65.0
@export var fire_cone_deg: float = 4.0
@export var aim_error_deg: float = 4.0
@export var lead_factor: float = 0.6
## Por debajo de esta fracción de blindaje el enemigo se retira (0 = nunca).
@export var retreat_fraction: float = 0.25
## Distancia a la que prefiere combatir (0 = la que tenga).
@export var preferred_range: float = 0.0
