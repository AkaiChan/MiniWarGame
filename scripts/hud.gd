extends CanvasLayer

var _game: Node
var _selected_unit: Unit
var _hovered_unit: Unit

@onready var _turn_label: Label = $LeftStack/TurnPanel/TurnVBox/TurnLabel
@onready var _unit_name_label: Label = $LeftStack/UnitPanel/UnitVBox/UnitNameLabel
@onready var _type_label: Label = $LeftStack/UnitPanel/UnitVBox/TypeLabel
@onready var _hp_label: Label = $LeftStack/UnitPanel/UnitVBox/HPLabel
@onready var _ap_label: Label = $LeftStack/UnitPanel/UnitVBox/APLabel
@onready var _combat_panel: Control = $CombatPanel
@onready var _combat_label: Label = $CombatPanel/CombatLabel
@onready var _rules_label: Label = $RulesPanel/RulesLabel
@onready var _show_enemy_hp_button: CheckButton = $LeftStack/UnitPanel/UnitVBox/ShowEnemyHPButton

var _show_enemy_hp := false

const QUICK_RULES := """QUICK RULES

Move      1 AP
Attack    1 AP
Melee     Adjacent
Diagonal  No"""


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
	_combat_panel.visible = false
	refresh_turn()
	_refresh_unit_info()


func refresh_turn() -> void:
	if _game == null or not _game.has_method("is_player_turn"):
		return
	_turn_label.text = "PLAYER" if _game.is_player_turn() else "ENEMY"


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
		_unit_name_label.text = "No Unit Selected"
		_type_label.visible = false
		_hp_label.visible = false
		_ap_label.visible = false
		_refresh_rules_panel(null)
		return
	_unit_name_label.text = unit.name
	_type_label.text = Unit.Archetype.keys()[unit.archetype]
	_type_label.visible = true
	if unit.team == Unit.Team.ENEMY and not _show_enemy_hp:
		_hp_label.text = "HP    ?"
	else:
		_hp_label.text = "HP    %d / %d" % [unit.current_hp, unit.max_hp]
	_ap_label.text = "AP    %d / %d" % [unit.current_ap, unit.max_ap]
	_hp_label.visible = true
	_ap_label.visible = true
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
	var hit_word := "HIT" if result.hits == 1 else "HITS"
	var lines: PackedStringArray = PackedStringArray([
		"%s × %s" % [result.attacker_name, result.target_name],
		"",
		_compact_phase("HIT %d+" % result.hit_target, result.hit_rolls, "%d %s" % [result.hits, hit_word]),
	])
	if result.hits > 0:
		var wound_word := "WOUND" if result.wounds == 1 else "WOUNDS"
		lines.append(_compact_phase(
			"WOUND %d+" % result.wound_target,
			result.wound_rolls,
			"%d %s" % [result.wounds, wound_word]
		))
	if result.wounds > 0:
		var saved: int = result.wounds - result.unsaved_wounds
		lines.append(_compact_phase(
			"SAVE %d+" % result.save_target,
			result.save_rolls,
			"%d SAVED / %d FAILED" % [saved, result.unsaved_wounds]
		))
	lines.append("DAMAGE     %d" % result.total_damage)
	_combat_label.text = "\n".join(lines)
	_combat_label.reset_size()
	_combat_panel.visible = true


func _compact_phase(title: String, rolls: Variant, result_text: String) -> String:
	return "%-10s%s\n           %s" % [title, _format_dice(rolls), result_text]


func _format_dice(rolls: Variant) -> String:
	var parts: PackedStringArray = []
	for roll in rolls:
		parts.append("[%d]" % int(roll))
	return "  ".join(parts)


func _refresh_rules_panel(unit: Unit) -> void:
	var lines: PackedStringArray = PackedStringArray([
		QUICK_RULES,
		"",
		"Selected Unit",
	])
	if unit == null or not is_instance_valid(unit):
		lines.append("—")
	else:
		lines.append_array(PackedStringArray([
			"Move      %d" % unit.move_range,
			"Attack    %d" % unit.attacks,
			"Hit       %d+" % unit.hit_target,
			"Wound     %d+" % unit.wound_target,
			"Save      %d+" % unit.save_target,
			"Damage    %d" % unit.damage,
		]))
	lines.append("")
	lines.append("Enemy turn is automatic.")
	_rules_label.text = "\n".join(lines)
