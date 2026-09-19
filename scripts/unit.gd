class_name Unit
extends Node3D

signal selected(unit: Unit)
signal defeated(unit: Unit)
signal state_changed

enum Team {
	PLAYER,
	ENEMY,
}

enum Archetype {
	SCOUT,
	GUARD,
	BERSERKER,
}

const COLOR_PLAYER := Color(0.42, 0.54, 0.68)
const COLOR_ENEMY := Color(0.68, 0.42, 0.40)
const COLOR_PLAYER_EXHAUSTED := Color(0.24, 0.30, 0.38)
const COLOR_ENEMY_EXHAUSTED := Color(0.38, 0.22, 0.22)

@export var grid_position: Vector2i
@export var team: Team = Team.PLAYER
@export var archetype: Archetype = Archetype.SCOUT

var footprint: Vector2i = Vector2i(1, 1)
var move_range: int = 2
var attacks: int = 2
var hit_target: int = 4
var wound_target: int = 4
var save_target: int = 4
var damage: int = 1
var max_hp: int = 4
var max_ap: int = 2
var current_hp: int
var current_ap: int
var is_selected := false


func _ready() -> void:
	add_to_group("units")
	var click_area := $ClickArea as StaticBody3D
	click_area.collision_layer = 2
	click_area.collision_mask = 0
	click_area.set_meta("unit", self)
	_apply_archetype()
	current_hp = max_hp
	current_ap = max_ap
	_apply_footprint_visual()
	update_visual_state()


func select() -> void:
	is_selected = true
	print(
		"Unit selected: %s [%s] at (%d, %d)"
		% [name, Team.keys()[team], grid_position.x, grid_position.y]
	)
	selected.emit(self)


func get_occupied_tiles(anchor: Variant = null) -> Array[Vector2i]:
	var origin: Vector2i = grid_position if anchor == null else (anchor as Vector2i)
	var width := maxi(footprint.x, 1)
	var height := maxi(footprint.y, 1)
	var tiles: Array[Vector2i] = []
	for y in height:
		for x in width:
			tiles.append(origin + Vector2i(x, y))
	return tiles


func move_to(new_grid_position: Vector2i, world_position: Vector3) -> void:
	print(
		"Moving %s: (%d, %d) -> (%d, %d)"
		% [name, grid_position.x, grid_position.y, new_grid_position.x, new_grid_position.y]
	)
	grid_position = new_grid_position
	global_position = world_position
	print("Move complete: %s at (%d, %d)" % [name, grid_position.x, grid_position.y])


func can_spend_ap(cost: int) -> bool:
	return current_ap >= cost


func spend_ap(cost: int) -> void:
	current_ap = maxi(current_ap - cost, 0)
	print("%s spent %d AP. AP: %d/%d" % [name, cost, current_ap, max_ap])
	update_visual_state()
	state_changed.emit()


func reset_ap() -> void:
	current_ap = max_ap
	print("%s AP reset: %d/%d" % [name, current_ap, max_ap])
	update_visual_state()
	state_changed.emit()


func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	current_hp = maxi(current_hp - amount, 0)
	print("%s took %d damage. HP: %d/%d" % [name, amount, current_hp, max_hp])
	state_changed.emit()
	if current_hp <= 0:
		_die()


func _die() -> void:
	print("%s defeated." % name)
	defeated.emit(self)
	remove_from_group("units")
	queue_free()


func update_visual_state() -> void:
	var color: Color
	if current_ap > 0:
		color = COLOR_PLAYER if team == Team.PLAYER else COLOR_ENEMY
	else:
		color = COLOR_PLAYER_EXHAUSTED if team == Team.PLAYER else COLOR_ENEMY_EXHAUSTED
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	$Body.material_override = material


func _apply_archetype() -> void:
	match archetype:
		Archetype.SCOUT:
			footprint = Vector2i(1, 1)
			max_hp = 4
			max_ap = 3
			move_range = 3
			attacks = 2
			hit_target = 4
			wound_target = 4
			save_target = 5
			damage = 1
		Archetype.GUARD:
			footprint = Vector2i(1, 1)
			max_hp = 7
			max_ap = 2
			move_range = 1
			attacks = 2
			hit_target = 4
			wound_target = 4
			save_target = 3
			damage = 1
		Archetype.BERSERKER:
			footprint = Vector2i(2, 1)
			max_hp = 6
			max_ap = 2
			move_range = 2
			attacks = 3
			hit_target = 4
			wound_target = 3
			save_target = 4
			damage = 1
			# TODO: Berserker Momentum ability in a later step.


func _apply_footprint_visual() -> void:
	var size_x := float(maxi(footprint.x, 1))
	var size_z := float(maxi(footprint.y, 1))
	$Body.scale = Vector3(size_x, 1.0, size_z)
	$Base.scale = Vector3(size_x, 1.0, size_z)
	var box := BoxShape3D.new()
	box.size = Vector3(size_x * 0.9, 0.6, size_z * 0.9)
	$ClickArea/CollisionShape3D.shape = box
