extends CanvasLayer

var _game: Node
var _selected_unit: Unit
var _hovered_unit: Unit

@onready var _turn_label: Label = $TurnLabel
@onready var _unit_name_label: Label = $UnitPanel/UnitNameLabel
@onready var _type_label: Label = $UnitPanel/TypeLabel
@onready var _hp_label: Label = $UnitPanel/HPLabel
@onready var _ap_label: Label = $UnitPanel/APLabel
@onready var _combat_label: Label = $CombatPanel/CombatLabel
@onready var _rules_label: Label = $RulesPanel/RulesLabel
@onready var _show_enemy_hp_button: CheckButton = $ShowEnemyHPButton

var _show_enemy_hp := false

const QUICK_RULES := """QUICK RULES

ACTIONS
Move: 1 AP
Attack: 1 AP

ATTACK RANGE
Adjacent tiles only
No diagonal attacks

TURN
Spend AP, then End Turn
Enemy acts automatically"""


func setup(game: Node, board: Node) -> void:
	_game = game
	if board.has_signal("active_unit_changed"):
		board.active_unit_changed.connect(_on_active_unit_changed)
	if board.has_signal("hovered_unit_changed"):
		board.hovered_unit_changed.connect(_on_hovered_unit_changed)
	if board.has_signal("combat_resolved"):
		board.combat_resolved.connect(_on_combat_resolved)
	_show_enemy_hp_button.toggled.connect(_on_show_enemy_hp_toggled)
	_show_enemy_hp = _show_enemy_hp_button.button_pressed
	refresh_turn()
	_refresh_unit_info()


func refresh_turn() -> void:
	if _game == null or not _game.has_method("is_player_turn"):
		return
	_turn_label.text = "Turn: PLAYER" if _game.is_player_turn() else "Turn: ENEMY"


func _on_active_unit_changed(unit: Variant) -> void:
	var previous: Variant = _selected_unit
	_selected_unit = unit if _is_valid_unit(unit) else null
	_update_unit_bindings(previous)
	_refresh_unit_info()


func _on_hovered_unit_changed(unit: Variant) -> void:
	var previous: Variant = _hovered_unit
	_hovered_unit = unit if _is_valid_unit(unit) else null
	_update_unit_bindings(previous)
	_refresh_unit_info()


func _update_unit_bindings(previous: Variant = null) -> void:
	if _is_valid_unit(previous):
		if previous != _selected_unit and previous != _hovered_unit:
			if previous.state_changed.is_connected(_refresh_unit_info):
				previous.state_changed.disconnect(_refresh_unit_info)
	for unit in [_selected_unit, _hovered_unit]:
		if _is_valid_unit(unit):
			if not unit.state_changed.is_connected(_refresh_unit_info):
				unit.state_changed.connect(_refresh_unit_info)


func _refresh_unit_info() -> void:
	var unit := _visible_unit()
	if unit == null:
		_unit_name_label.text = "Selected: None"
		_type_label.text = "Type: -"
		_hp_label.text = "HP: -"
		_ap_label.text = "AP: -"
		_refresh_rules_panel(null)
		return
	var prefix := "Selected: " if _is_valid_unit(_selected_unit) else "Unit: "
	_unit_name_label.text = "%s%s" % [prefix, unit.name]
	_type_label.text = "Type: %s" % Unit.Archetype.keys()[unit.archetype]
	if unit.team == Unit.Team.ENEMY and not _show_enemy_hp:
		_hp_label.text = "HP: ?"
	else:
		_hp_label.text = "HP: %d / %d" % [unit.current_hp, unit.max_hp]
	_ap_label.text = "AP: %d / %d" % [unit.current_ap, unit.max_ap]
	_refresh_rules_panel(unit)


func _visible_unit() -> Unit:
	if _is_valid_unit(_selected_unit):
		return _selected_unit
	if _is_valid_unit(_hovered_unit):
		return _hovered_unit
	return null


func _is_valid_unit(unit: Variant) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	return not unit.is_queued_for_deletion()


func _on_show_enemy_hp_toggled(pressed: bool) -> void:
	_show_enemy_hp = pressed
	_refresh_unit_info()


func _on_combat_resolved(result: Dictionary) -> void:
	var lines: PackedStringArray = PackedStringArray([
		"COMBAT",
		"",
		"%s → %s" % [result.attacker_name, result.target_name],
		"",
		"HIT",
		"Rolls: %s" % _format_rolls(result.hit_rolls),
		"Hits: %d" % result.hits,
	])
	if result.hits > 0:
		lines.append("")
		lines.append("WOUND")
		lines.append("Rolls: %s" % _format_rolls(result.wound_rolls))
		lines.append("Wounds: %d" % result.wounds)
	if result.wounds > 0:
		lines.append("")
		lines.append("SAVE")
		lines.append("Rolls: %s" % _format_rolls(result.save_rolls))
		lines.append("Unsaved: %d" % result.unsaved_wounds)
	lines.append("")
	lines.append("DAMAGE: %d" % result.total_damage)
	_combat_label.text = "\n".join(lines)


func _format_rolls(rolls: Variant) -> String:
	var parts: PackedStringArray = []
	for roll in rolls:
		parts.append(str(roll))
	return ", ".join(parts)


func _refresh_rules_panel(unit: Unit) -> void:
	var text := QUICK_RULES + "\n\nUNIT STATS\n"
	if unit == null or not is_instance_valid(unit):
		text += "Select a unit to view stats."
	else:
		text += "\n".join(PackedStringArray([
			"Type: %s" % Unit.Archetype.keys()[unit.archetype],
			"Footprint: %d×%d" % [unit.footprint.x, unit.footprint.y],
			"Move Range: %d" % unit.move_range,
			"Attacks: %d" % unit.attacks,
			"Hit: %d+" % unit.hit_target,
			"Wound: %d+" % unit.wound_target,
			"Save: %d+" % unit.save_target,
			"Damage: %d" % unit.damage,
		]))
	_rules_label.text = text
