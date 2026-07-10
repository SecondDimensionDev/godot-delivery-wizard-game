extends BaseSteamworks


func _ready() -> void:
	super()
	Steam.initRelayNetworkAccess()


func _process(_delta) -> void:
	Steam.run_callbacks()
