class_name RunData
extends BaseRunData

## Game-specific run data for the delivery/cargo-carry loop: money, delivery count,
## streak multiplier, and run-over state. Pure logic -- no scene-tree lookups, no
## networking; the owner (server-side delivery/job flow) calls the register_* methods
## and broadcasts the returned message plus this resource's state however it likes.
## Streak: consecutive damage-free deliveries multiply the payout; any value lost in
## transit resets it.

# SIGNALS
signal run_ended ## Money went below zero -- the run is over.

# CONSTANTS
const TIME_BONUS_MAX := 50.0 # dollars for an instant delivery...
const TIME_BONUS_DECAY := 0.5 # ...draining this fast per second
const STREAK_STEP := 0.5 # multiplier gained per consecutive damage-free delivery
const STREAK_MAX := 3.0 # multiplier ceiling (reached on the 5th in a row)
const LATE_FEE := 50.0 # dollars charged when the exit timer expires
const RESPAWN_FEE := 15.0 # dollars lost whenever a player is sent back to spawn

# PUBLIC VARIABLES
var money: float = 0.0 ## Team money; below zero ends the run. Read-only outside.
var deliveries: int = 0 ## Successful deliveries this run. Read-only outside.
var streak: int = 0 ## Consecutive damage-free deliveries so far. Read-only outside.
var run_over: bool = false ## True once money went below zero. Read-only outside.


# PUBLIC FUNCTIONS
func register_delivery(remaining_value: float, elapsed_seconds: float,
		spawn_value: float) -> String:
	## Server-only. Applies the payout for a delivered box: remaining value + a
	## decaying time bonus, multiplied by the streak built up BEFORE this delivery.
	## Damage-free (full value on arrival) extends the streak; anything less resets
	## it. Returns the broadcast-ready message.
	var time_bonus := maxf(0.0, TIME_BONUS_MAX - elapsed_seconds * TIME_BONUS_DECAY)
	var multiplier := clampf(1.0 + STREAK_STEP * float(streak), 1.0, STREAK_MAX)
	var damage_free := remaining_value >= spawn_value
	streak = streak + 1 if damage_free else 0
	var payout := (remaining_value + time_bonus) * multiplier
	money += payout
	deliveries += 1
	var msg := "Delivered! ($%.0f cargo + $%.0f time bonus) x%.1f streak = $%.0f." \
		% [remaining_value, time_bonus, multiplier, payout]
	if not damage_free:
		msg += " Damage broke the streak."
	return msg + _check_run_over()


func apply_late_fee() -> String:
	## Server-only. Charges the team for dawdling past the exit timer. The streak is
	## untouched -- it tracks cargo damage, not scheduling.
	money -= LATE_FEE
	var msg := "Too slow! A $%.0f waiting fee was charged." % LATE_FEE
	return msg + _check_run_over()


func register_player_respawn() -> String:
	## Server-only. A hazard or enemy sent a player back to spawn; the pot pays for the
	## trip. The streak is untouched -- it tracks cargo damage, not casualties.
	money -= RESPAWN_FEE
	var msg := "A player was sent back to spawn -- $%.0f from the pot." % RESPAWN_FEE
	return msg + _check_run_over()


func reset() -> void:
	## Back to a fresh run (new session / disconnect).
	money = 0.0
	deliveries = 0
	streak = 0
	run_over = false


# PRIVATE FUNCTIONS
func _check_run_over() -> String:
	if run_over or money >= 0.0:
		return ""
	run_over = true
	run_ended.emit()
	return " The team is in debt -- RUN OVER."
