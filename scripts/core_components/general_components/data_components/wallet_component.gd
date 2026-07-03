@icon("uid://dy0xjx8nn3hqo")
class_name WalletComponent
extends Node
## A generic, reusable component for managing currency or points.
##
## This node encapsulates balance tracking, providing methods to add,
## spend, and check affordability. It emits signals whenever the balance
## changes, making it easy to hook up to UI elements or other systems.

# SIGNALS
signal balance_changed(new_balance: int) ## Emitted whenever the balance is modified
signal currency_added(amount: int) ## Emitted when currency is successfully added
signal currency_spent(amount: int) ## Emitted when currency is successfully spent
signal currency_lost(amount: int) ## Emitted when currency is lost
signal max_balance_reached ## Emitted when an addition hits the maximum limit
signal insufficient_funds_attempted ## Emitted when a spend fails due to lack of funds

# EXPORT VARIABLES
@export var starting_balance: int = 0 ## The amount of currency the wallet starts with
@export var min_balance: int = 0 ## The minimum amount of currency allowed
@export var max_balance: int = 99999 ## The maximum amount of currency allowed

# PUBLIC VARIABLES
var current_balance: int = 0 ## The current amount of currency


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_initialize_wallet()


# PUBLIC FUNCTIONS
func add_currency(amount: int) -> void: ## Adds to the balance and clamps to max_balance
	if amount <= 0:
		return
		
	var old_balance := current_balance
	current_balance = clampi(current_balance + amount, 0, max_balance)
	
	var actual_added := current_balance - old_balance
	if actual_added > 0:
		currency_added.emit(actual_added)
		balance_changed.emit(current_balance)
		
	if current_balance == max_balance:
		max_balance_reached.emit()


func spend_currency(amount: int) -> bool: ## Deducts from balance if affordable, returns success
	if amount <= 0:
		return false
		
	if can_afford(amount):
		current_balance -= amount
		currency_spent.emit(amount)
		balance_changed.emit(current_balance)
		return true
		
	insufficient_funds_attempted.emit()
	return false


func lose_currency(amount: int) -> void: ## Removes specified currency amount from the wallet
	if amount <= 0:
		return
	current_balance -= amount
	currency_lost.emit(amount)
	balance_changed.emit(current_balance)


func can_afford(amount: int) -> bool: ## Checks if the current balance can cover the cost
	return current_balance >= amount


func set_balance(amount: int) -> void: ## Hard sets the balance, clamping it to the limits
	var clamped_amount := clampi(amount, 0, max_balance)
	if current_balance != clamped_amount:
		current_balance = clamped_amount
		balance_changed.emit(current_balance)


func set_minimum_balance(amount: int) -> void:
	min_balance = amount


func set_maximum_balance(amount: int) -> void:
	max_balance = amount


func reset_wallet() -> void: ## Resets the wallet back to the starting balance
	set_balance(starting_balance)


# PRIVATE FUNCTIONS
func _initialize_wallet() -> void: # Sets up initial state
	set_balance(starting_balance)
