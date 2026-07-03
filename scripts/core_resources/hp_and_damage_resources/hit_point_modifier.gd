class_name HitPointModifier
extends Resource

@export var priority: int = 0 ## Higher priority modifiers are calculated first.
@export var modifier_name: String = "" ## Unique name for this hit point modifier

var _parent_component: HitPointComponent

func setup(component): ## Setup function that adds the parent component as a variable
	_parent_component = component


func modify_damage(amount: int, _damage_type: String) -> int: ## Virtual function to modify damage. Returns the new damage amount.
	return amount


func modify_heal(amount: int) -> int: ## Virtual function to modify healing. Returns the new heal amount.
	return amount


func report_modifier_value_change(value: int) -> void: ## Tell the Hit Point component that the modifier's primary value changed
	_parent_component.report_modifier_value(modifier_name, value)


func timeout(duration: float) -> void: ## Creates a timer which removes this modifier from the parent component on timeout.
	var tree = _parent_component.get_tree()
	if tree:
		await tree.create_timer(duration).timeout
		remove_self()


func remove_self(): ## Removes this modifier from its parent hit point component
	if is_instance_valid(_parent_component):
		_parent_component.remove_modifier_by_reference(self)
