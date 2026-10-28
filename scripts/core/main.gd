extends Control
## Boot screen for Step 0. Proves the project runs and that the
## fixed 60-tick simulation loop is ticking at the right rate.

const SIM_TICKS_PER_SECOND := 60

var _tick_count := 0
var _ticks_last_second := 0
var _second_timer := 0.0

@onready var _info_label: Label = $InfoLabel


func _ready() -> void:
	print("Robot Fighter booted on Godot %s" % Engine.get_version_info().string)
	print("Physics ticks per second: %d" % Engine.physics_ticks_per_second)
	assert(Engine.physics_ticks_per_second == SIM_TICKS_PER_SECOND,
		"Combat logic expects exactly 60 ticks per second.")


# All combat logic will live in _physics_process so it runs at a fixed 60 ticks/sec,
# independent of how fast the screen is drawing.
func _physics_process(_delta: float) -> void:
	_tick_count += 1


func _process(delta: float) -> void:
	_second_timer += delta
	if _second_timer >= 1.0:
		_ticks_last_second = _tick_count
		_tick_count = 0
		_second_timer -= 1.0
	_info_label.text = "ROBOT FIGHTER\nStep 0: project setup OK\n\nGodot %s\nSimulation ticks last second: %d / %d\nRender FPS: %d" % [
		Engine.get_version_info().string,
		_ticks_last_second,
		SIM_TICKS_PER_SECOND,
		Engine.get_frames_per_second(),
	]
