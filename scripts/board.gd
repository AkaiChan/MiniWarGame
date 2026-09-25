extends Node3D

signal active_unit_changed(unit: Unit)
signal hovered_unit_changed(unit: Unit)
signal combat_resolved(result: Dictionary)

const BOARD_SIZE := 8
const TILE_SIZE := 1.0
const TILE_HEIGHT := 0.05
const TILE_Y := 0.1
const RAY_LENGTH := 1000.0
const LAYER_TILES := 1
const LAYER_UNITS := 2

const COLOR_LIGHT := Color(0.78, 0.74, 0.66)
const COLOR_DARK := Color(0.28, 0.26, 0.24)
const COLOR_HIGHLIGHT := Color(0.90, 0.78, 0.40)
const COLOR_SELECTED := Color(0.78, 0.64, 0.34)
const COLOR_MOVE_RANGE := Color(0.46, 0.72, 0.50)
const COLOR_MOVE_FOOTPRINT := Color(0.42, 0.54, 0.44)

var _highlight_material: StandardMaterial3D
var _selected_material: StandardMaterial3D
var _move_range_material: StandardMaterial3D
var _move_footprint_material: StandardMaterial3D
var _hovered_tile: MeshInstance3D
var _hovered_unit: Unit
var _active_unit: Unit
var _game: Node
var _tiles: Dictionary = {}
var _selected_tiles: Array[MeshInstance3D] = []
var _move_anchor_tiles: Array[MeshInstance3D] = []
var _move_footprint_tiles: Array[MeshInstance3D] = []
var _reachable_anchors: Array[Vector2i] = []


func _ready() -> void:
	_highlight_material = _make_material(COLOR_HIGHLIGHT)
	_selected_material = _make_material(COLOR_SELECTED)
	_move_range_material = _make_material(COLOR_MOVE_RANGE)
	_move_footprint_material = _make_material(COLOR_MOVE_FOOTPRINT)
	_create_tiles()
	print("Board created: %d tiles" % get_child_count())
	call_deferred("_connect_units")


func _physics_process(_delta: float) -> void:
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var tile := _raycast_tile()
		if tile != null:
			var target: Vector2i = tile.get_meta("grid_position")
			if target in _reachable_anchors:
				_try_move_active_unit(tile)
				return
		var unit := _raycast_unit()
		if unit:
			_on_unit_clicked(unit)
			return
		if not _is_player_turn():
			return
		_try_move_active_unit(tile)


func setup(game: Node) -> void:
	_game = game


func clear_turn_state() -> void:
	_set_active_unit(null)
	_clear_movement_range()


func _set_active_unit(unit: Unit) -> void:
	_active_unit = unit
	active_unit_changed.emit(unit)
	if unit == null or not is_instance_valid(unit):
		_clear_selected_footprint()
	else:
		_show_selected_footprint(unit)


func _is_player_turn() -> bool:
	return _game != null and _game.has_method("is_player_turn") and _game.is_player_turn()


func _connect_units() -> void:
	for unit in _get_units():
		if not unit.selected.is_connected(_on_unit_selected):
			unit.selected.connect(_on_unit_selected)
		if not unit.defeated.is_connected(_on_unit_defeated):
			unit.defeated.connect(_on_unit_defeated)
		unit.global_position = grid_to_world_for_footprint(unit.grid_position, unit.footprint)


func _on_unit_clicked(unit: Unit) -> void:
	if not _is_player_turn():
		return
	if unit.team == Unit.Team.PLAYER:
		if unit.current_ap == 0:
			print("Unit exhausted: %s" % unit.name)
			return
		unit.select()
		return
	_on_enemy_clicked(unit)


func _on_enemy_clicked(enemy: Unit) -> void:
	if _active_unit == null:
		print("No active unit. Enemy clicked: %s" % enemy.name)
		return
	if not can_attack(_active_unit, enemy):
		print("Target out of attack range: %s" % enemy.name)
		return
	try_attack(_active_unit, enemy)


func can_attack(attacker: Unit, target: Unit) -> bool:
	if attacker == null or target == null:
		return false
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	if attacker.team == target.team:
		return false
	return are_units_adjacent(attacker, target)


func are_units_adjacent(a: Unit, b: Unit) -> bool:
	for tile_a in a.get_occupied_tiles():
		for tile_b in b.get_occupied_tiles():
			var distance := absi(tile_a.x - tile_b.x) + absi(tile_a.y - tile_b.y)
			if distance == 1:
				return true
	return false


func try_attack(attacker: Unit, target: Unit) -> bool:
	if not can_attack(attacker, target):
		return false
	if not attacker.can_spend_ap(1):
		print("Not enough AP to attack: %s" % attacker.name)
		return false
	attacker.spend_ap(1)
	resolve_attack(attacker, target)
	_clear_active_if_exhausted(attacker)
	return true


func resolve_attack(attacker: Unit, target: Unit) -> void:
	var attacker_name := attacker.name
	var target_name := target.name
	print("Attack: %s -> %s" % [attacker_name, target_name])

	var hit_rolls := _roll_dice(attacker.attacks)
	var hits := _count_successes(hit_rolls, attacker.hit_target)
	print("Hit Rolls: %s" % str(hit_rolls))
	print("Hits: %d" % hits)

	var wound_rolls: Array[int] = []
	var wounds := 0
	var save_rolls: Array[int] = []
	var unsaved_wounds := 0
	var total_damage := 0

	if hits > 0:
		wound_rolls = _roll_dice(hits)
		wounds = _count_successes(wound_rolls, attacker.wound_target)
		print("Wound Rolls: %s" % str(wound_rolls))
		print("Wounds: %d" % wounds)
		if wounds > 0:
			save_rolls = _roll_dice(wounds)
			unsaved_wounds = wounds - _count_successes(save_rolls, target.save_target)
			total_damage = unsaved_wounds * attacker.damage
			print("Save Rolls: %s" % str(save_rolls))
			print("Unsaved Wounds: %d" % unsaved_wounds)

	print("Total Damage: %d" % total_damage)
	combat_resolved.emit({
		"attacker_name": attacker_name,
		"target_name": target_name,
		"hit_target": attacker.hit_target,
		"wound_target": attacker.wound_target,
		"save_target": target.save_target,
		"hit_rolls": hit_rolls,
		"hits": hits,
		"wound_rolls": wound_rolls,
		"wounds": wounds,
		"save_rolls": save_rolls,
		"unsaved_wounds": unsaved_wounds,
		"total_damage": total_damage,
	})
	if total_damage > 0:
		target.take_damage(total_damage)


func roll_d6() -> int:
	return randi_range(1, 6)


func _roll_dice(count: int) -> Array[int]:
	var rolls: Array[int] = []
	for _i in count:
		rolls.append(roll_d6())
	return rolls


func _count_successes(rolls: Array[int], target_number: int) -> int:
	var successes := 0
	for roll in rolls:
		if roll >= target_number:
			successes += 1
	return successes


func _on_unit_selected(unit: Unit) -> void:
	if unit.team != Unit.Team.PLAYER:
		return
	if unit.current_ap == 0:
		print("Unit exhausted: %s" % unit.name)
		return
	_set_active_unit(unit)
	_show_movement_range(unit)


func _on_unit_defeated(unit: Unit) -> void:
	if _active_unit == unit:
		_set_active_unit(null)
		_clear_movement_range()
	if _hovered_unit == unit:
		_set_hovered_unit(null)


func _get_units() -> Array[Unit]:
	var units: Array[Unit] = []
	for node in get_tree().get_nodes_in_group("units"):
		if node is Unit:
			units.append(node)
	return units


func is_tile_occupied(grid_position: Vector2i, ignore_unit: Unit = null) -> bool:
	for unit in _get_units():
		if unit == ignore_unit:
			continue
		if grid_position in unit.get_occupied_tiles():
			return true
	return false


func can_place_unit(unit: Unit, anchor: Vector2i) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	for tile in unit.get_occupied_tiles(anchor):
		if not _is_on_board(tile):
			return false
		if is_tile_occupied(tile, unit):
			return false
	return true


func grid_to_world(grid_position: Vector2i) -> Vector3:
	var offset := _grid_offset()
	return Vector3(
		grid_position.x * TILE_SIZE - offset,
		TILE_Y + TILE_HEIGHT * 0.5,
		grid_position.y * TILE_SIZE - offset
	)


func grid_to_world_for_footprint(anchor: Vector2i, footprint: Vector2i) -> Vector3:
	var width := maxi(footprint.x, 1)
	var height := maxi(footprint.y, 1)
	var offset := _grid_offset()
	return Vector3(
		(anchor.x + (width - 1) * 0.5) * TILE_SIZE - offset,
		TILE_Y + TILE_HEIGHT * 0.5,
		(anchor.y + (height - 1) * 0.5) * TILE_SIZE - offset
	)


func _grid_offset() -> float:
	return (BOARD_SIZE - 1) * TILE_SIZE / 2.0


func _create_tiles() -> void:
	var offset := _grid_offset()
	var light_material := _make_material(COLOR_LIGHT)
	var dark_material := _make_material(COLOR_DARK)
	var tile_size := Vector3(TILE_SIZE, TILE_HEIGHT, TILE_SIZE)

	for z in BOARD_SIZE:
		for x in BOARD_SIZE:
			var tile := MeshInstance3D.new()
			tile.name = "Tile_%d_%d" % [x, z]

			var mesh := BoxMesh.new()
			mesh.size = tile_size
			tile.mesh = mesh

			var grid_position := Vector2i(x, z)
			var is_light := (x + z) % 2 == 0
			var base_material := light_material if is_light else dark_material
			tile.set_meta("base_material", base_material)
			tile.set_meta("grid_position", grid_position)
			_apply_tile_material(tile, base_material)
			tile.position = Vector3(
				x * TILE_SIZE - offset,
				TILE_Y,
				z * TILE_SIZE - offset
			)

			var body := StaticBody3D.new()
			body.name = "Body"
			body.collision_layer = LAYER_TILES
			body.collision_mask = 0
			var collision := CollisionShape3D.new()
			collision.name = "Collision"
			var shape := BoxShape3D.new()
			shape.size = tile_size
			collision.shape = shape
			body.add_child(collision)
			tile.add_child(body)

			_tiles[grid_position] = tile
			add_child(tile)


func get_reachable_tiles(unit: Unit) -> Array[Vector2i]:
	var origin := unit.grid_position
	var move_range := unit.move_range
	var reachable: Array[Vector2i] = []
	var visited := {origin: true}
	var distance := {origin: 0}
	var frontier: Array[Vector2i] = [origin]
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var current_distance: int = distance[current]
		if current_distance >= move_range:
			continue

		for direction in directions:
			var next: Vector2i = current + direction
			if visited.has(next):
				continue
			visited[next] = true
			if not can_place_unit(unit, next):
				continue

			distance[next] = current_distance + 1
			frontier.append(next)
			reachable.append(next)

	return reachable


func _is_on_board(grid_position: Vector2i) -> bool:
	return (
		grid_position.x >= 0
		and grid_position.x < BOARD_SIZE
		and grid_position.y >= 0
		and grid_position.y < BOARD_SIZE
	)


func _show_selected_footprint(unit: Unit) -> void:
	_clear_selected_footprint()
	if unit == null or not is_instance_valid(unit):
		return
	for occupied in unit.get_occupied_tiles():
		if not _tiles.has(occupied):
			continue
		var tile: MeshInstance3D = _tiles[occupied]
		_selected_tiles.append(tile)
		_refresh_tile_visual(tile)


func _clear_selected_footprint() -> void:
	var previous := _selected_tiles.duplicate()
	_selected_tiles.clear()
	for tile in previous:
		_refresh_tile_visual(tile)


func _show_movement_range(unit: Unit) -> void:
	_clear_movement_range()
	var anchors := get_reachable_tiles(unit)
	_reachable_anchors = anchors.duplicate()
	var footprint_positions: Dictionary = {}
	for anchor in anchors:
		_move_anchor_tiles.append(_tiles[anchor])
		for occupied in unit.get_occupied_tiles(anchor):
			footprint_positions[occupied] = true
	for occupied in footprint_positions:
		if occupied in anchors:
			continue
		if not _tiles.has(occupied):
			continue
		_move_footprint_tiles.append(_tiles[occupied])
	for tile in _move_anchor_tiles:
		_refresh_tile_visual(tile)
	for tile in _move_footprint_tiles:
		_refresh_tile_visual(tile)
	print("Movement range: %d anchors" % anchors.size())


func _try_move_active_unit(tile: MeshInstance3D) -> bool:
	if tile == null or _active_unit == null:
		return false
	if not _is_player_turn():
		return false
	if _active_unit.team != Unit.Team.PLAYER:
		return false
	var target: Vector2i = tile.get_meta("grid_position")
	if target not in _reachable_anchors:
		return false

	var moved := try_move_unit(_active_unit, target)
	if moved:
		_clear_movement_range()
		if _active_unit != null and is_instance_valid(_active_unit):
			_show_selected_footprint(_active_unit)
	return moved


func try_move_unit(unit: Unit, target_grid: Vector2i) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if target_grid == unit.grid_position:
		return false
	if not can_place_unit(unit, target_grid):
		return false
	var reachable := get_reachable_tiles(unit)
	if target_grid not in reachable:
		return false
	if not unit.can_spend_ap(1):
		print("Not enough AP to move: %s" % unit.name)
		return false

	unit.move_to(target_grid, grid_to_world_for_footprint(target_grid, unit.footprint))
	unit.spend_ap(1)
	_clear_active_if_exhausted(unit)
	return true


func _clear_active_if_exhausted(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if unit.current_ap > 0:
		return
	if _active_unit != unit:
		return
	_set_active_unit(null)
	_clear_movement_range()


func _clear_movement_range() -> void:
	var previous_tiles: Array[MeshInstance3D] = []
	previous_tiles.append_array(_move_anchor_tiles)
	previous_tiles.append_array(_move_footprint_tiles)
	_move_anchor_tiles.clear()
	_move_footprint_tiles.clear()
	_reachable_anchors.clear()
	for tile in previous_tiles:
		_refresh_tile_visual(tile)


func _update_hover() -> void:
	_update_tile_hover()
	_update_unit_hover()


func _update_tile_hover() -> void:
	var tile := _raycast_tile()
	if tile == _hovered_tile:
		return

	if tile:
		print("Hover: %s" % tile.name)

	var previous := _hovered_tile
	_hovered_tile = tile
	if previous:
		_refresh_tile_visual(previous)
	if tile:
		_refresh_tile_visual(tile)


func _update_unit_hover() -> void:
	var unit := _raycast_unit()
	if _hovered_unit != null and not is_instance_valid(_hovered_unit):
		_set_hovered_unit(unit)
		return
	if unit == _hovered_unit:
		return
	_set_hovered_unit(unit)


func _set_hovered_unit(unit: Unit) -> void:
	if unit != null and (not is_instance_valid(unit) or unit.is_queued_for_deletion()):
		unit = null
	_hovered_unit = unit
	hovered_unit_changed.emit(unit)


func _refresh_tile_visual(tile: MeshInstance3D) -> void:
	if tile == _hovered_tile:
		_apply_tile_material(tile, _highlight_material)
	elif tile in _move_anchor_tiles:
		_apply_tile_material(tile, _move_range_material)
	elif tile in _selected_tiles:
		_apply_tile_material(tile, _selected_material)
	elif tile in _move_footprint_tiles:
		_apply_tile_material(tile, _move_footprint_material)
	else:
		_apply_tile_material(tile, tile.get_meta("base_material"))


func _raycast_tile() -> MeshInstance3D:
	return _tile_from_collider(_intersect_ray(LAYER_TILES).get("collider"))


func _raycast_unit() -> Unit:
	var unit := _unit_from_collider(_intersect_ray(LAYER_UNITS).get("collider"))
	if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return null
	return unit


func _intersect_ray(collision_mask: int) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}

	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _tile_from_collider(collider: Variant) -> MeshInstance3D:
	if collider is Node:
		var parent := (collider as Node).get_parent()
		if parent is MeshInstance3D and parent.has_meta("grid_position"):
			return parent
	return null


func _unit_from_collider(collider: Variant) -> Unit:
	if collider is Node:
		if collider.has_meta("unit"):
			return collider.get_meta("unit") as Unit
		var parent := (collider as Node).get_parent()
		if parent is Unit:
			return parent
	return null


func _apply_tile_material(tile: MeshInstance3D, material: Material) -> void:
	tile.material_override = material
	if tile.mesh is PrimitiveMesh:
		(tile.mesh as PrimitiveMesh).material = material


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
