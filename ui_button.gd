extends TextureButton

const DefaultValues := {
	"expand" : true,
	"ignore_texture_size" : true,
	"stretch_mode" : TextureButton.STRETCH_KEEP_ASPECT_CENTERED,
	"action_mode" : TextureButton.ACTION_MODE_BUTTON_PRESS,
	"focus_mode" : TextureButton.FOCUS_NONE,
}

@export var input_action:StringName
@export var use_default_values := true
@export var touchscreen_only := false

var touch_index := -1
var released := true

func _init():
	if use_default_values:
		for k in DefaultValues.keys():
			self.set(k, DefaultValues.get(k))
			
	if touchscreen_only and not DisplayServer.is_touchscreen_available():
		hide()


func press():
	Input.action_press(input_action, 1.0)
	released = false
	modulate.a = 0.5
	
	
func release():
	Input.action_release(input_action)
	released = true
	modulate.a = 1.0
	
	
func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed and released:
			touch_index = event.index
			press()
			#accept_event()
		elif event.index == touch_index:
			release()
			#accept_event()
			
