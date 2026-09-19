class_name Game
extends Node3D

enum Turn {
	PLAYER,
	ENEMY,
}

var current_turn: Turn = Turn.PLAYER
var _board: Node
var _hud: Node


func _ready() -> void:
	_board = $Board
	_hud = $CanvasLayer
	_board.setup(self)
	if _hud.has_method("setup"):
		_hud.setup(self, _board)
	start_turn(Turn.PLAYER)


func is_player_turn() -> bool:
	return current_turn == Turn.PLAYER


func start_turn(turn: Turn) -> void:
	current_turn = turn
	if _board.has_method("clear_turn_state"):
		_board.clear_turn_state()

	if current_turn == Turn.PLAYER:
		print("=== PLAYER TURN ===")
	else:
		print("=== ENEMY TURN ===")

	if _hud != null and _hud.has_method("refresh_turn"):
		_hud.refresh_turn()

	var team := Unit.Team.PLAYER if current_turn == Turn.PLAYER else Unit.Team.ENEMY
	for unit in _units_of_team(team):
		unit.reset_ap()

	if current_turn == Turn.ENEMY:
		_run_enemy_ai()
		end_turn()


func end_turn() -> void:
	if current_turn == Turn.PLAYER:
		start_turn(Turn.ENEMY)
	else:
		start_turn(Turn.PLAYER)


func _run_enemy_ai() -> void:
	var player := _first_unit_of_team(Unit.Team.PLAYER)
	if player == null:
		return

	for enemy in _units_of_team(Unit.Team.ENEMY):
		if not is_instance_valid(player):
			return
		_activate_enemy(enemy, player)


func _activate_enemy(enemy: Unit, player: Unit) -> void:
	while is_instance_valid(enemy) and enemy.current_ap > 0:
		if not is_instance_valid(player):
			break
		if _board.can_attack(enemy, player):
			print("Enemy decision: ATTACK")
			if not _board.try_attack(enemy, player):
				break
			continue

		var destination: Variant = _closest_reachable_tile(enemy, player)
		if destination == null:
			break
		print("Enemy decision: MOVE")
		if not _board.try_move_unit(enemy, destination):
			break


func _closest_reachable_tile(enemy: Unit, player: Unit) -> Variant:
	var reachable: Array[Vector2i] = _board.get_reachable_tiles(enemy)
	if reachable.is_empty():
		return null

	var best: Vector2i = reachable[0]
	var best_distance := _manhattan(best, player.grid_position)
	for tile in reachable:
		var distance := _manhattan(tile, player.grid_position)
		if distance < best_distance:
			best = tile
			best_distance = distance
	return best


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _first_unit_of_team(team: Unit.Team) -> Unit:
	var units := _units_of_team(team)
	if units.is_empty():
		return null
	return units[0]


func _units_of_team(team: Unit.Team) -> Array[Unit]:
	var units: Array[Unit] = []
	for node in get_tree().get_nodes_in_group("units"):
		if node is Unit and node.team == team:
			units.append(node)
	return units
