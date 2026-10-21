class_name ActionResult
extends RefCounted
## Outcome of a gameplay action (remove, install, tighten, toggle...).
##
## Every mechanical action returns one of these so the UI can display a
## precise reason when something is blocked, instead of silently failing.

var ok: bool = false
## Player-facing explanation. Empty for silent successes.
var message: String = ""
## True when the action changed persistent state (used to bump revisions).
var changed: bool = false


static func success(msg: String = "", did_change: bool = true) -> ActionResult:
	var r := ActionResult.new()
	r.ok = true
	r.message = msg
	r.changed = did_change
	return r


static func fail(msg: String) -> ActionResult:
	var r := ActionResult.new()
	r.ok = false
	r.message = msg
	return r


## A success that is still in progress (e.g. a bolt being turned) and has no message.
static func progress() -> ActionResult:
	return success("", true)
