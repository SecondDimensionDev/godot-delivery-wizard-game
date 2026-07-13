## SessionManager Autoload
extends BaseSessionManager
## An autoload to manage data for the current game session.
## Stores data that needs to persist for the current game run, across multiple levels.
## Handles saving and loading, along with serialisation of resources. Extends from the base
## class, which has the following public methods: <br>
## save_run()  |  load_run()  |  clear_run()  |  has_saved_run()


# PUBLIC FUNCTIONS
func start_new_run() -> void: ## Initializes a fresh run and saves it to disk.
	super()
	current_run = RunData.new()
	save_run()
