## Popup Manager Autoload
@icon("uid://bb5jexvdhrpeg")
extends BasePopupManager
## A global system to handle application-wide popup dialogs and modal states.
##
## This manager centralizes the creation of alerts, confirmations, and custom
## popups. It automatically handles the "dimmed" background state to block
## input to the rest of the application while a dialog is active.
## This extends the [BasePopupManager] class, add any game-specific logic here
