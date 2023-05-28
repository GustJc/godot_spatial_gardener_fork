@tool
extends Control


#-------------------------------------------------------------------------------
# A button with multiple children buttons corresponding to various possible interactions
# It's main purpose is to display a thumbnail and respond to UI inputs
#-------------------------------------------------------------------------------




# These flags define what sort of signals and broadcast
enum InteractionFlags {DELETE, SET_DIALOG, SET_DRAG, PRESS, CHECK, CLEAR, SHOW_COUNT, EDIT_LABEL}
const PRESET_ALL:Array = [	InteractionFlags.DELETE, InteractionFlags.SET_DIALOG, InteractionFlags.SET_DRAG, InteractionFlags.PRESS, 
							InteractionFlags.CHECK, InteractionFlags.CLEAR, InteractionFlags.SHOW_COUNT, InteractionFlags.EDIT_LABEL]

const ThemeAdapter = preload("../../../controls/theme_adapter.gd")

var active_interaction_flags:Array = [] : set = set_active_interaction_flags
@export var thumb_size:int = 100 : set = set_thumb_size
@export var button_size:int = 26 : set = set_button_size

var root_button_nd:Control = null
var texture_rect_nd:Control = null
var selection_panel_nd:Control = null
var check_box_nd:Control = null
var counter_container_nd:Control = null
var counter_label_nd:Control = null
var label_line_edit_nd:Control = null
var menu_button_nd:Control = null
var alt_text_margin_nd:Control = null
var alt_text_label_nd:Control = null

@export var clear_texture: Texture2D = null
@export var delete_texture: Texture2D = null
@export var new_texture: Texture2D = null
@export var options_texture: Texture2D = null

var def_rect_size:Vector2 = Vector2(100.0, 100.0)
var def_button_size:Vector2 = Vector2(24.0, 24.0)
var def_max_title_chars:int = 8


signal requested_delete
signal requested_set_dialog
signal requested_set_drag
signal requested_press
signal requested_check
signal requested_label_edit
signal requested_clear




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func init(_thumb_size:int, _button_size:int, _active_interaction_flags:Array):
	set_meta("class", "UI_ActionThumbnail")
	thumb_size = _thumb_size
	button_size = _button_size
	active_interaction_flags = _active_interaction_flags.duplicate()


# We have some conditional checks here
# Because inheriting nodes might ditch some of the functionality
func _ready():
	var Label_font_size = get_theme_font_size("font_size", "Label")
	_set_default_textures()
	
	if has_node("RootButton"):
		root_button_nd = $RootButton
		if root_button_nd.has_signal("dropped"):
			root_button_nd.dropped.connect(on_set_drag)
		root_button_nd.pressed.connect(on_set_dialog)
		root_button_nd.pressed.connect(on_press)
		root_button_nd.theme_type_variation = "InspectorButton"
	if has_node("TextureRect"):
		texture_rect_nd = $TextureRect
	if has_node("SelectionPanel"):
		selection_panel_nd = $SelectionPanel
		selection_panel_nd.visible = false
		selection_panel_nd.theme_type_variation = "ActionThumbnail_SelectionPanel"
	if has_node("CheckBox"):
		check_box_nd = $CheckBox
		check_box_nd.pressed.connect(on_check)
		check_box_nd.visible = false
	if has_node("CounterContainer"):
		counter_container_nd = $CounterContainer
		counter_label_nd = $CounterContainer/CounterLabel
		counter_label_nd.resized.connect(counter_resized)
		counter_label_nd.add_theme_font_size_override('font_size', Label_font_size)
		counter_container_nd.visible = false
	if has_node("AltTextMargin"):
		alt_text_margin_nd = $AltTextMargin
		alt_text_label_nd = $AltTextMargin/AltTextLabel
		alt_text_label_nd.add_theme_font_size_override('font_size', Label_font_size)
		alt_text_margin_nd.theme_type_variation = "ExternalMargin"
		alt_text_label_nd.visible = false
	if has_node('LabelLineEdit'):
		label_line_edit_nd = $LabelLineEdit
		label_line_edit_nd.add_theme_font_size_override('font_size', Label_font_size)
		label_line_edit_nd.theme_type_variation = "PlantTitleLineEdit"
		label_line_edit_nd.text_changed.connect(on_label_edit)
		label_line_edit_nd.visible = false
	if has_node('MenuButton'):
		menu_button_nd = $MenuButton
		menu_button_nd.theme_type_variation = "MenuButton"
		menu_button_nd.get_popup().id_pressed.connect(on_popup_menu_press)
	
	update_size()
	set_active_interaction_flags(active_interaction_flags)


func _set_default_textures():
	if !clear_texture || !delete_texture || !new_texture || !options_texture:
		var editor_theme = ThemeAdapter.get_theme(self)
		clear_texture = editor_theme.get_theme_item(Theme.DATA_TYPE_ICON, "Clear", "EditorIcons")
		delete_texture = editor_theme.get_theme_item(Theme.DATA_TYPE_ICON, "ImportFail", "EditorIcons")
		new_texture = editor_theme.get_theme_item(Theme.DATA_TYPE_ICON, "Add", "EditorIcons")
		options_texture = editor_theme.get_theme_item(Theme.DATA_TYPE_ICON, "CodeFoldDownArrow", "EditorIcons")
		if has_node("$MenuButton"):
			$MenuButton.icon = options_texture




#-------------------------------------------------------------------------------
# Resizing
#-------------------------------------------------------------------------------


func set_thumb_size(val:int):
	thumb_size = val
	update_size()

func set_button_size(val:int):
	button_size = val
	update_size()


func update_size():
	if !is_inside_tree(): return
	
	visible = false
	
	var thumb_rect = Vector2(thumb_size, thumb_size)
	# I don't know why I need both this and the same thing in the update_size_step2()
	# As well as why I need to set min_rect to 1 beforehand
	# But it seems to break otherwise
	# Control size updating seems a bit broken in general, or just way too convoluted to define a clear set of rules :/
	custom_minimum_size = Vector2.ONE
	size = thumb_rect
	custom_minimum_size = thumb_rect
	
	call_deferred("update_size_step2")


func update_size_step2():
	var thumb_rect = Vector2(thumb_size, thumb_size)
	var button_rect = Vector2(button_size, button_size)
	var short_button_margin = 4
	var long_button_margin = thumb_size - button_size - short_button_margin
	var font_scale = pow(float(button_size) / def_button_size.x, 0.25)
	
	root_button_nd.set_size(thumb_rect)
	if active_interaction_flags.has(InteractionFlags.EDIT_LABEL):
		texture_rect_nd.set_size(Vector2(thumb_size, thumb_size - button_size))
		texture_rect_nd.set_position(Vector2(0.0, button_size))
	else:
		texture_rect_nd.set_size(Vector2(thumb_size, thumb_size))
		texture_rect_nd.set_position(Vector2(0.0, 0.0))
	
	if is_instance_valid(selection_panel_nd):
		selection_panel_nd.set_size(thumb_rect)
	
	if is_instance_valid(check_box_nd):
		check_box_nd.offset_left = short_button_margin
		check_box_nd.offset_bottom = short_button_margin
#		check_box_nd.set_position(Vector2(0, thumb_size - button_size))
	
	if is_instance_valid(counter_container_nd):
		counter_container_nd.set_size(button_rect)
		counter_container_nd.set_position(Vector2(long_button_margin, long_button_margin))
		counter_label_nd.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		counter_label_nd.custom_minimum_size = Vector2.ZERO
		scale_font(counter_label_nd, font_scale)
	
	if is_instance_valid(alt_text_margin_nd):
		alt_text_margin_nd.set_size(texture_rect_nd.size)
		alt_text_margin_nd.set_position(texture_rect_nd.position)
		scale_font(alt_text_label_nd, font_scale)
	
	if is_instance_valid(label_line_edit_nd):
		label_line_edit_nd.set_size(Vector2(thumb_size - 2.0, button_size))
		label_line_edit_nd.set_position(Vector2(1.0, 1.0))
		scale_font(label_line_edit_nd, font_scale * 0.9)
	
	if is_instance_valid(menu_button_nd):
		var max_size = max(menu_button_nd.icon.get_size().x, menu_button_nd.icon.get_size().y)
		var stylebox:StyleBoxFlat = menu_button_nd.get_theme_stylebox('normal', 'MenuButton')
		var menu_button_rect = clamp_rect_to_stylebox_margins(button_rect, max_size, stylebox)
		menu_button_nd.set_size(menu_button_rect)
		if active_interaction_flags.has(InteractionFlags.EDIT_LABEL):
			menu_button_nd.set_position(Vector2(thumb_size - menu_button_rect.x, button_size))
		else:
			menu_button_nd.set_position(Vector2(thumb_size - menu_button_rect.x, 0.0))
	
	size = thumb_rect
	custom_minimum_size = thumb_rect
	visible = true


func clamp_rect_to_stylebox_margins(rect, content_size, stylebox):
	return Vector2(
			max(rect.x, content_size + stylebox.content_margin_right + stylebox.content_margin_left),
			max(rect.y, content_size + stylebox.content_margin_bottom + stylebox.content_margin_top)
		)


func scale_font(node: Control, font_scale: float):
	var font_size = node.get_theme_font_size("font_size")
	node.add_theme_font_size_override("font_size", font_size * font_scale)


func set_counter_val(val:int):
	if is_instance_valid(counter_label_nd):
		counter_label_nd.text = str(val)


func counter_resized():
	counter_label_nd.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)



#-------------------------------------------------------------------------------
# Interaction flags
#-------------------------------------------------------------------------------


func set_active_interaction_flags(flags:Array):
	var ownFlagsCopy = active_interaction_flags.duplicate()
	var flagsCopy = flags.duplicate()
	
	for flag in ownFlagsCopy:
		set_interaction_flag(flag, false)
	for flag in flagsCopy:
		set_interaction_flag(flag, true)


func set_interaction_flag(flag:int, state:bool):
	if state:
		if !active_interaction_flags.has(flag):
			active_interaction_flags.append(flag)
	else:
		active_interaction_flags.erase(flag)

	enable_features_to_flag(flag, state)


func enable_features_to_flag(flag:int, state:bool):
	if is_inside_tree():
		match flag:
			InteractionFlags.CHECK:
				check_box_nd.visible = state
			InteractionFlags.CLEAR:
				if state:
					menu_button_nd.get_popup().remove_item(menu_button_nd.get_popup().get_item_index(0))
				menu_button_nd.get_popup().add_icon_item(clear_texture, 'Clear', 0)
			InteractionFlags.DELETE:
				if state:
					menu_button_nd.get_popup().remove_item(menu_button_nd.get_popup().get_item_index(1))
				menu_button_nd.get_popup().add_icon_item(delete_texture, 'Delete', 1)
			InteractionFlags.SHOW_COUNT:
				counter_container_nd.visible = state
			InteractionFlags.EDIT_LABEL:
				label_line_edit_nd.visible = state


func set_features_val_to_flag(flag:int, val):
	if is_inside_tree():
		match flag:
			InteractionFlags.PRESS:
				selection_panel_nd.visible = val
			InteractionFlags.CHECK:
				check_box_nd.button_pressed = val
			InteractionFlags.EDIT_LABEL:
				if label_line_edit_nd.text != val:
					label_line_edit_nd.text = val


func on_set_dialog():
	if active_interaction_flags.has(InteractionFlags.SET_DIALOG):
		requested_set_dialog.emit()

func on_set_drag(path):
	if active_interaction_flags.has(InteractionFlags.SET_DRAG):
		requested_set_drag.emit(path)

func on_press():
	if active_interaction_flags.has(InteractionFlags.PRESS):
		requested_press.emit()

func on_check():
	if active_interaction_flags.has(InteractionFlags.CHECK):
		requested_check.emit(check_box_nd.button_pressed)

func on_label_edit(label_text: String):
	if active_interaction_flags.has(InteractionFlags.EDIT_LABEL):
		requested_label_edit.emit(label_text)

func on_popup_menu_press(id: int):
	match id:
		0:
			on_clear()
		1:
			on_delete()

func on_clear():
	if active_interaction_flags.has(InteractionFlags.CLEAR):
		requested_clear.emit()

func on_delete():
	if active_interaction_flags.has(InteractionFlags.DELETE):
		requested_delete.emit()




#-------------------------------------------------------------------------------
# Thumbnail itself and other visuals
#-------------------------------------------------------------------------------


func set_thumbnail(texture:Texture2D):
	texture_rect_nd.visible = true
	alt_text_label_nd.visible = false
	
	texture_rect_nd.texture = texture
	alt_text_label_nd.text = ""


func set_alt_text(alt_text:String):
	if !is_instance_valid(alt_text_label_nd) || !is_instance_valid(texture_rect_nd): return
	alt_text_label_nd.visible = true
	texture_rect_nd.visible = false
	
	alt_text_label_nd.text = alt_text
	texture_rect_nd.texture = null
