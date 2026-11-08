extends Control
## Let the host's normal modal Escape route cancel back to the opener.
signal cancel_requested
func request_close()->void:
	cancel_requested.emit()
