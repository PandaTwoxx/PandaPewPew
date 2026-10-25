extends Control
## Modern, polished Home Screen for PandaPewPew.
## Features procedural graphics, mascot eye tracking, dynamic background,
## sound synthesis, and seamless multiplayer host/join controls.

const CONFIG_FILE := "user://pandapewpew_settings.cfg"
const MapDefs := preload("res://scripts/map_defs.gd")
const ModeDefs := preload("res://scripts/mode_defs.gd")

var _audio: Node
var _address_input: LineEdit
var _port_input: LineEdit
var _host_port_input: LineEdit
var _map_select: OptionButton
var _mode_select: OptionButton
var _mode_desc: Label
var _status_label: Label
var _status_dot: ColorRect
var _cancel_btn: Button
var _host_btn: Button
var _join_btn: Button

# Tab contents
var _tab_play: Control
var _tab_guide: Control
var _tab_settings: Control
var _tab_buttons: Array[Button] = []

# Bun backend controls
var _bun_panel_rooms: Control
var _bun_panel_direct: Control
var _bun_submode_btn_rooms: Button
var _bun_submode_btn_direct: Button
var _bun_room_name_input: LineEdit
var _bun_room_code_input: LineEdit
var _bun_rooms_container: VBoxContainer
var _bun_url_input: LineEdit
var _bun_backend_status_label: Label

var _connecting: bool = false
var _connect_timer: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 1. Background
	var bg_script = load("res://scripts/menu_background.gd")
	var bg = Control.new()
	bg.set_script(bg_script)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 2. Audio Synthesizer
	var audio_script = load("res://scripts/menu_audio.gd")
	_audio = Node.new()
	_audio.set_script(audio_script)
	add_child(_audio)

	# 3. Main UI Layout
	_build_ui()

	# 4. Load persisted preferences
	_load_settings()

	# 5. Multiplayer signal connections
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)


func _exit_tree() -> void:
	if multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.disconnect(_on_connected)
	if multiplayer.connection_failed.is_connected(_on_failed):
		multiplayer.connection_failed.disconnect(_on_failed)


func _process(delta: float) -> void:
	if _connecting:
		_connect_timer += delta
		var dots := ".".repeat(int(_connect_timer * 3.0) % 4)
		_status_label.text = "Connecting to %s:%d%s" % [
			_address_input.text.strip_edges(),
			_join_port_value(),
			dots
		]


func _build_ui() -> void:
	# Root margin container to keep away from screen edges
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 24)
	root_margin.add_theme_constant_override("margin_right", 24)
	root_margin.add_theme_constant_override("margin_top", 16)
	root_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(root_margin)

	# Vertical stack: Top bar, Center Area, Footer
	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	main_vbox.add_theme_constant_override("separation", 10)
	root_margin.add_child(main_vbox)

	# --- TOP BAR ---
	var top_bar := HBoxContainer.new()
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(top_bar)

	var version_badge := _create_badge("PANDA PEW PEW • MULTIPLAYER ARENA", Color(0.15, 0.75, 0.45, 0.35))
	top_bar.add_child(version_badge)

	var spacer_top := Control.new()
	spacer_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer_top)

	# Sound toggle button
	var sound_btn := _create_pill_button("SFX: ON")
	sound_btn.pressed.connect(func():
		var audio_class = load("res://scripts/menu_audio.gd")
		audio_class.sound_enabled = not audio_class.sound_enabled
		sound_btn.text = "SFX: ON" if audio_class.sound_enabled else "SFX: OFF"
		_audio.play_click()
		_save_settings()
	)
	top_bar.add_child(sound_btn)

	# Fullscreen button
	var fs_btn := _create_pill_button("⛶ Fullscreen")
	fs_btn.pressed.connect(func():
		_audio.play_click()
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	)
	top_bar.add_child(fs_btn)

	# --- HERO SECTION (Mascot + Title) ---
	var hero_box := VBoxContainer.new()
	hero_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_box.add_theme_constant_override("separation", 3)
	main_vbox.add_child(hero_box)

	# Panda Mascot Node
	var mascot_script = load("res://scripts/panda_mascot.gd")
	var mascot = Control.new()
	mascot.set_script(mascot_script)
	mascot.custom_minimum_size = Vector2(130, 115)
	mascot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero_box.add_child(mascot)

	# Title Label
	var title_lbl := Label.new()
	title_lbl.text = "PANDA PEW PEW"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 38)
	title_lbl.add_theme_color_override("font_color", Color(0.96, 0.99, 0.98))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.05, 0.4, 0.25, 0.75))
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_lbl.add_theme_constant_override("shadow_outline_size", 6)
	hero_box.add_child(title_lbl)

	# Subtitle
	var sub_lbl := Label.new()
	sub_lbl.text = "FARMYARD FRACAS • 2D BATTLE ARENA"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.4, 0.88, 0.65))
	hero_box.add_child(sub_lbl)

	# --- CENTER CARD ---
	var center_wrap := CenterContainer.new()
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(center_wrap)

	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(550, 310)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.12, 0.16, 0.92)
	card_style.border_color = Color(0.18, 0.7, 0.42, 0.45)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(14)
	card_style.shadow_color = Color(0, 0, 0, 0.45)
	card_style.shadow_size = 16
	card_style.shadow_offset = Vector2(0, 6)
	card_style.content_margin_left = 20
	card_style.content_margin_right = 20
	card_style.content_margin_top = 16
	card_style.content_margin_bottom = 16
	card_panel.add_theme_stylebox_override("panel", card_style)
	center_wrap.add_child(card_panel)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 14)
	card_panel.add_child(card_vbox)

	# --- NAVIGATION TABS ---
	var tabs_bar := HBoxContainer.new()
	tabs_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_bar.add_theme_constant_override("separation", 8)
	card_vbox.add_child(tabs_bar)

	var tab_play_btn := _create_tab_button("⚔️ Play Match", true)
	var tab_guide_btn := _create_tab_button("📖 How to Play", false)
	var tab_settings_btn := _create_tab_button("⚙️ Settings", false)

	_tab_buttons = [tab_play_btn, tab_guide_btn, tab_settings_btn]
	for b in _tab_buttons:
		tabs_bar.add_child(b)

	tab_play_btn.pressed.connect(func(): _switch_tab(0))
	tab_guide_btn.pressed.connect(func(): _switch_tab(1))
	tab_settings_btn.pressed.connect(func(): _switch_tab(2))

	# Container for the tab bodies
	var tab_stack := MarginContainer.new()
	tab_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(tab_stack)

	# --- TAB 1: PLAY ---
	_tab_play = VBoxContainer.new()
	_tab_play.add_theme_constant_override("separation", 12)
	tab_stack.add_child(_tab_play)
	_build_play_tab(_tab_play)

	# --- TAB 2: GUIDE ---
	_tab_guide = VBoxContainer.new()
	_tab_guide.visible = false
	_tab_guide.add_theme_constant_override("separation", 10)
	tab_stack.add_child(_tab_guide)
	_build_guide_tab(_tab_guide)

	# --- TAB 3: SETTINGS ---
	_tab_settings = VBoxContainer.new()
	_tab_settings.visible = false
	_tab_settings.add_theme_constant_override("separation", 10)
	tab_stack.add_child(_tab_settings)
	_build_settings_tab(_tab_settings)

	# --- STATUS BAR (Persistent inside card) ---
	var status_container := PanelContainer.new()
	var status_bg := StyleBoxFlat.new()
	status_bg.bg_color = Color(0.05, 0.08, 0.11, 0.8)
	status_bg.set_corner_radius_all(8)
	status_bg.content_margin_left = 12
	status_bg.content_margin_right = 12
	status_bg.content_margin_top = 8
	status_bg.content_margin_bottom = 8
	status_container.add_theme_stylebox_override("panel", status_bg)
	card_vbox.add_child(status_container)

	var status_hbox := HBoxContainer.new()
	status_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	status_hbox.add_theme_constant_override("separation", 10)
	status_container.add_child(status_hbox)

	_status_dot = ColorRect.new()
	_status_dot.custom_minimum_size = Vector2(10, 10)
	_status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_dot.color = Color(0.2, 0.9, 0.4) # Green ready
	status_hbox.add_child(_status_dot)

	_status_label = Label.new()
	_status_label.text = "Ready to fight! Host a room or join a server."
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.92))
	status_hbox.add_child(_status_label)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.visible = false
	_cancel_btn.add_theme_font_size_override("font_size", 11)
	_cancel_btn.pressed.connect(_on_cancel)
	_cancel_btn.mouse_entered.connect(_audio.play_hover)
	status_hbox.add_child(_cancel_btn)


func _build_play_tab(parent: Control) -> void:
	var submode_bar := HBoxContainer.new()
	submode_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	submode_bar.add_theme_constant_override("separation", 8)
	parent.add_child(submode_bar)

	_bun_submode_btn_rooms = _create_pill_button("🌐 Online Rooms (Bun.js)")
	_bun_submode_btn_direct = _create_pill_button("⚡ Direct LAN / IP")
	submode_bar.add_child(_bun_submode_btn_rooms)
	submode_bar.add_child(_bun_submode_btn_direct)

	_bun_submode_btn_rooms.pressed.connect(func(): _switch_play_submode(0))
	_bun_submode_btn_direct.pressed.connect(func(): _switch_play_submode(1))

	# Container for the two submode panels
	var submode_stack := MarginContainer.new()
	submode_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(submode_stack)

	# --- SUBMODE 0: BUN.JS ONLINE LOBBIES ---
	_bun_panel_rooms = VBoxContainer.new()
	_bun_panel_rooms.add_theme_constant_override("separation", 10)
	submode_stack.add_child(_bun_panel_rooms)
	_build_bun_rooms_panel(_bun_panel_rooms)

	# --- SUBMODE 1: DIRECT IP / LAN ---
	_bun_panel_direct = VBoxContainer.new()
	_bun_panel_direct.visible = false
	_bun_panel_direct.add_theme_constant_override("separation", 10)
	submode_stack.add_child(_bun_panel_direct)
	_build_direct_panel(_bun_panel_direct)

	_switch_play_submode(0)


func _switch_play_submode(mode: int) -> void:
	_audio.play_click()
	_bun_panel_rooms.visible = (mode == 0)
	_bun_panel_direct.visible = (mode == 1)

	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color(0.18, 0.65, 0.42, 0.85)
	active_style.set_corner_radius_all(10)
	active_style.content_margin_left = 10
	active_style.content_margin_right = 10
	active_style.content_margin_top = 3
	active_style.content_margin_bottom = 3

	var inactive_style := StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.12, 0.18, 0.24, 0.6)
	inactive_style.border_color = Color(0.25, 0.4, 0.5, 0.4)
	inactive_style.set_border_width_all(1)
	inactive_style.set_corner_radius_all(10)
	inactive_style.content_margin_left = 10
	inactive_style.content_margin_right = 10
	inactive_style.content_margin_top = 3
	inactive_style.content_margin_bottom = 3

	if mode == 0:
		_bun_submode_btn_rooms.add_theme_stylebox_override("normal", active_style)
		_bun_submode_btn_direct.add_theme_stylebox_override("normal", inactive_style)
		_refresh_bun_rooms()
	else:
		_bun_submode_btn_rooms.add_theme_stylebox_override("normal", inactive_style)
		_bun_submode_btn_direct.add_theme_stylebox_override("normal", active_style)


func _build_bun_rooms_panel(parent: Control) -> void:
	var top_grid := HBoxContainer.new()
	top_grid.add_theme_constant_override("separation", 12)
	parent.add_child(top_grid)

	# 1. Create Room Card
	var create_panel := PanelContainer.new()
	create_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color(0.12, 0.17, 0.22, 0.75)
	c_style.set_corner_radius_all(8)
	c_style.border_color = Color(0.15, 0.6, 0.35, 0.35)
	c_style.set_border_width_all(1)
	c_style.content_margin_left = 10
	c_style.content_margin_right = 10
	c_style.content_margin_top = 8
	c_style.content_margin_bottom = 8
	create_panel.add_theme_stylebox_override("panel", c_style)
	top_grid.add_child(create_panel)

	var c_vbox := VBoxContainer.new()
	c_vbox.add_theme_constant_override("separation", 6)
	create_panel.add_child(c_vbox)

	var c_title := Label.new()
	c_title.text = "HOST ONLINE LOBBY"
	c_title.add_theme_font_size_override("font_size", 12)
	c_title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
	c_vbox.add_child(c_title)

	_bun_room_name_input = _create_line_edit("Panda Arena", "Room Name")
	c_vbox.add_child(_bun_room_name_input)

	var create_btn := _create_action_button("🚀 Create Room", Color(0.12, 0.72, 0.42), Color(0.15, 0.85, 0.48))
	create_btn.pressed.connect(_on_bun_create)
	c_vbox.add_child(create_btn)

	# 2. Join by Code Card
	var join_panel := PanelContainer.new()
	join_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var j_style := StyleBoxFlat.new()
	j_style.bg_color = Color(0.12, 0.17, 0.22, 0.75)
	j_style.set_corner_radius_all(8)
	j_style.border_color = Color(0.15, 0.55, 0.85, 0.35)
	j_style.set_border_width_all(1)
	j_style.content_margin_left = 10
	j_style.content_margin_right = 10
	j_style.content_margin_top = 8
	j_style.content_margin_bottom = 8
	join_panel.add_theme_stylebox_override("panel", j_style)
	top_grid.add_child(join_panel)

	var j_vbox := VBoxContainer.new()
	j_vbox.add_theme_constant_override("separation", 6)
	join_panel.add_child(j_vbox)

	var j_title := Label.new()
	j_title.text = "JOIN BY ROOM CODE"
	j_title.add_theme_font_size_override("font_size", 12)
	j_title.add_theme_color_override("font_color", Color(0.38, 0.8, 1.0))
	j_vbox.add_child(j_title)

	_bun_room_code_input = _create_line_edit("", "e.g. FARM")
	_bun_room_code_input.max_length = 6
	_bun_room_code_input.text_submitted.connect(func(_t): _on_bun_join_code())
	j_vbox.add_child(_bun_room_code_input)

	var join_code_btn := _create_action_button("🎯 Join by Code", Color(0.12, 0.52, 0.88), Color(0.18, 0.65, 1.0))
	join_code_btn.pressed.connect(_on_bun_join_code)
	j_vbox.add_child(join_code_btn)

	# 3. Active Lobbies Browser List
	var list_header := HBoxContainer.new()
	parent.add_child(list_header)

	var list_title := Label.new()
	list_title.text = "ACTIVE ROOMS"
	list_title.add_theme_font_size_override("font_size", 11)
	list_title.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	list_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_header.add_child(list_title)

	var dedicated_btn := _create_mini_pill("☁️ Launch Dedicated")
	dedicated_btn.pressed.connect(_on_bun_spawn_dedicated)
	list_header.add_child(dedicated_btn)

	var refresh_btn := _create_mini_pill("🔄 Refresh")
	refresh_btn.pressed.connect(_refresh_bun_rooms)
	list_header.add_child(refresh_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 75)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	_bun_rooms_container = VBoxContainer.new()
	_bun_rooms_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bun_rooms_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_bun_rooms_container)


func _build_direct_panel(parent: Control) -> void:
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 16)
	parent.add_child(grid)

	# --- LEFT COLUMN: HOST ---
	var host_panel := PanelContainer.new()
	host_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var host_style := StyleBoxFlat.new()
	host_style.bg_color = Color(0.12, 0.17, 0.22, 0.75)
	host_style.set_corner_radius_all(10)
	host_style.border_color = Color(0.15, 0.6, 0.35, 0.35)
	host_style.set_border_width_all(1)
	host_style.content_margin_left = 14
	host_style.content_margin_right = 14
	host_style.content_margin_top = 12
	host_style.content_margin_bottom = 12
	host_panel.add_theme_stylebox_override("panel", host_style)
	grid.add_child(host_panel)

	var host_vbox := VBoxContainer.new()
	host_vbox.add_theme_constant_override("separation", 8)
	host_panel.add_child(host_vbox)

	var host_title := Label.new()
	host_title.text = "HOST DIRECT (LAN/PORT)"
	host_title.add_theme_font_size_override("font_size", 13)
	host_title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
	host_vbox.add_child(host_title)

	var port_row := HBoxContainer.new()
	var port_lbl := Label.new()
	port_lbl.text = "Port:"
	port_lbl.add_theme_font_size_override("font_size", 12)
	port_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	port_row.add_child(port_lbl)

	_host_port_input = _create_line_edit(str(Net.DEFAULT_PORT), "Port")
	port_row.add_child(_host_port_input)
	host_vbox.add_child(port_row)

	_map_select = OptionButton.new()
	for id in MapDefs.ORDER:
		_map_select.add_item(MapDefs.map_name(id))
	host_vbox.add_child(_labeled_row("Map:", _map_select))

	_mode_select = OptionButton.new()
	for id in ModeDefs.ORDER:
		_mode_select.add_item(ModeDefs.MODES[id].name)
	_mode_select.item_selected.connect(func(_i): _update_mode_desc())
	host_vbox.add_child(_labeled_row("Mode:", _mode_select))

	_mode_desc = Label.new()
	_mode_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_desc.add_theme_font_size_override("font_size", 11)
	_mode_desc.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
	host_vbox.add_child(_mode_desc)
	_update_mode_desc()

	var host_desc := Label.new()
	host_desc.text = "Host a direct game on your LAN or forwarded port."
	host_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host_desc.add_theme_font_size_override("font_size", 11)
	host_desc.add_theme_color_override("font_color", Color(0.55, 0.65, 0.7))
	host_vbox.add_child(host_desc)

	var host_spacer := Control.new()
	host_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host_vbox.add_child(host_spacer)

	_host_btn = _create_action_button("🚀 Host LAN", Color(0.12, 0.72, 0.42), Color(0.15, 0.85, 0.48))
	_host_btn.pressed.connect(_on_host)
	host_vbox.add_child(_host_btn)

	# --- RIGHT COLUMN: JOIN ---
	var join_panel := PanelContainer.new()
	join_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var join_style := StyleBoxFlat.new()
	join_style.bg_color = Color(0.12, 0.17, 0.22, 0.75)
	join_style.set_corner_radius_all(10)
	join_style.border_color = Color(0.15, 0.55, 0.85, 0.35)
	join_style.set_border_width_all(1)
	join_style.content_margin_left = 14
	join_style.content_margin_right = 14
	join_style.content_margin_top = 12
	join_style.content_margin_bottom = 12
	join_panel.add_theme_stylebox_override("panel", join_style)
	grid.add_child(join_panel)

	var join_vbox := VBoxContainer.new()
	join_vbox.add_theme_constant_override("separation", 8)
	join_panel.add_child(join_vbox)

	var join_title := Label.new()
	join_title.text = "JOIN VIA IP & PORT"
	join_title.add_theme_font_size_override("font_size", 13)
	join_title.add_theme_color_override("font_color", Color(0.38, 0.8, 1.0))
	join_vbox.add_child(join_title)

	var ip_row := HBoxContainer.new()
	var ip_lbl := Label.new()
	ip_lbl.text = "IP:"
	ip_lbl.custom_minimum_size = Vector2(32, 0)
	ip_lbl.add_theme_font_size_override("font_size", 12)
	ip_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	ip_row.add_child(ip_lbl)

	_address_input = _create_line_edit("127.0.0.1", "Server Address")
	_address_input.text_submitted.connect(func(_t): _on_join())
	ip_row.add_child(_address_input)
	join_vbox.add_child(ip_row)

	var join_port_row := HBoxContainer.new()
	var join_port_lbl := Label.new()
	join_port_lbl.text = "Port:"
	join_port_lbl.custom_minimum_size = Vector2(32, 0)
	join_port_lbl.add_theme_font_size_override("font_size", 12)
	join_port_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	join_port_row.add_child(join_port_lbl)

	_port_input = _create_line_edit(str(Net.DEFAULT_PORT), "Port")
	_port_input.text_submitted.connect(func(_t): _on_join())
	join_port_row.add_child(_port_input)
	join_vbox.add_child(join_port_row)

	# Quick connect preset pills
	var pills_row := HBoxContainer.new()
	pills_row.add_theme_constant_override("separation", 6)
	join_vbox.add_child(pills_row)

	var pill_local := _create_mini_pill("Localhost")
	pill_local.pressed.connect(func():
		_address_input.text = "127.0.0.1"
		_audio.play_click()
	)
	pills_row.add_child(pill_local)

	var pill_default_port := _create_mini_pill("Reset Port")
	pill_default_port.pressed.connect(func():
		_port_input.text = str(Net.DEFAULT_PORT)
		_audio.play_click()
	)
	pills_row.add_child(pill_default_port)

	var join_spacer := Control.new()
	join_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	join_vbox.add_child(join_spacer)

	_join_btn = _create_action_button("🎯 Join Direct", Color(0.12, 0.52, 0.88), Color(0.18, 0.65, 1.0))
	_join_btn.pressed.connect(_on_join)
	join_vbox.add_child(_join_btn)


func _labeled_row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(40, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	row.add_child(lbl)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.add_theme_font_size_override("font_size", 12)
	row.add_child(control)
	return row


func _update_mode_desc() -> void:
	_mode_desc.text = ModeDefs.MODES[ModeDefs.ORDER[_mode_select.selected]].desc


## Host-side choice; clients learn it from the server when they join.
func _apply_game_choice() -> void:
	Net.map_id = MapDefs.ORDER[_map_select.selected]
	Net.mode_id = ModeDefs.ORDER[_mode_select.selected]


func _build_guide_tab(parent: Control) -> void:
	var rows := [
		{"keys": "W / A / S / D  (or Arrow Keys)", "action": "Move your Panda across the bamboo arena"},
		{"keys": "Mouse Cursor", "action": "360° Directional Aiming"},
		{"keys": "Left Mouse Button (Hold)", "action": "Continuous Laser Pew-Pew Blaster"},
		{"keys": "Tab (Hold)", "action": "Show the scoreboard"},
		{"keys": "Escape (ESC)", "action": "Leave current match and return to menu"},
	]

	for r in rows:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 12)

		var badge := _create_badge(r["keys"], Color(0.18, 0.55, 0.85, 0.35))
		badge.custom_minimum_size = Vector2(170, 24)
		item.add_child(badge)

		var desc := Label.new()
		desc.text = r["action"]
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(desc)

		parent.add_child(item)

	var rules_box := PanelContainer.new()
	var rules_style := StyleBoxFlat.new()
	rules_style.bg_color = Color(0.1, 0.14, 0.18, 0.6)
	rules_style.set_corner_radius_all(8)
	rules_style.content_margin_left = 10
	rules_style.content_margin_right = 10
	rules_style.content_margin_top = 8
	rules_style.content_margin_bottom = 8
	rules_box.add_theme_stylebox_override("panel", rules_style)
	parent.add_child(rules_box)

	var rules_lbl := Label.new()
	rules_lbl.text = "🌾 Farmyard Rules: 100 HP • 20 damage per shot • 10s Veggie Blaster burst with 5s cooldown. Dead players respawn after 3s. Modes: Kill Count, Capture the Flag, Conquest."
	rules_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_lbl.add_theme_font_size_override("font_size", 11)
	rules_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
	rules_box.add_child(rules_lbl)


func _build_settings_tab(parent: Control) -> void:
	var desc := Label.new()
	desc.text = "Multiplayer & System Preferences"
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95))
	parent.add_child(desc)

	# Bun Backend configuration block
	var bun_box := PanelContainer.new()
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.06, 0.1, 0.14, 0.85)
	b_style.border_color = Color(0.2, 0.7, 0.45, 0.4)
	b_style.set_border_width_all(1)
	b_style.set_corner_radius_all(8)
	b_style.content_margin_left = 12
	b_style.content_margin_right = 12
	b_style.content_margin_top = 8
	b_style.content_margin_bottom = 8
	bun_box.add_theme_stylebox_override("panel", b_style)
	parent.add_child(bun_box)

	var b_vbox := VBoxContainer.new()
	b_vbox.add_theme_constant_override("separation", 6)
	bun_box.add_child(b_vbox)

	var b_title := Label.new()
	b_title.text = "Bun.js Multiplayer Backend URL:"
	b_title.add_theme_font_size_override("font_size", 11)
	b_title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
	b_vbox.add_child(b_title)

	var b_hbox := HBoxContainer.new()
	b_hbox.add_theme_constant_override("separation", 8)
	b_vbox.add_child(b_hbox)

	_bun_url_input = _create_line_edit(Net.bun_url, "http://localhost:3000")
	_bun_url_input.text_changed.connect(func(new_url: String):
		Net.set_bun_url(new_url)
		_save_settings()
	)
	b_hbox.add_child(_bun_url_input)

	var test_btn := Button.new()
	test_btn.text = "Test Connection"
	test_btn.add_theme_font_size_override("font_size", 11)
	test_btn.pressed.connect(_test_bun_connection)
	b_hbox.add_child(test_btn)

	_bun_backend_status_label = Label.new()
	_bun_backend_status_label.text = "Status: Not tested yet"
	_bun_backend_status_label.add_theme_font_size_override("font_size", 10)
	_bun_backend_status_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	b_vbox.add_child(_bun_backend_status_label)

	# Dedicated server helper block
	var dedicated_box := PanelContainer.new()
	var d_style := StyleBoxFlat.new()
	d_style.bg_color = Color(0.05, 0.08, 0.12, 0.85)
	d_style.border_color = Color(0.2, 0.4, 0.6, 0.4)
	d_style.set_border_width_all(1)
	d_style.set_corner_radius_all(8)
	d_style.content_margin_left = 12
	d_style.content_margin_right = 12
	d_style.content_margin_top = 10
	d_style.content_margin_bottom = 10
	dedicated_box.add_theme_stylebox_override("panel", d_style)
	parent.add_child(dedicated_box)

	var d_vbox := VBoxContainer.new()
	d_vbox.add_theme_constant_override("separation", 6)
	dedicated_box.add_child(d_vbox)

	var d_title := Label.new()
	d_title.text = "Dedicated Headless Server Command:"
	d_title.add_theme_font_size_override("font_size", 11)
	d_title.add_theme_color_override("font_color", Color(0.4, 0.8, 0.65))
	d_vbox.add_child(d_title)

	var cmd_hbox := HBoxContainer.new()
	d_vbox.add_child(cmd_hbox)

	var cmd_lbl := LineEdit.new()
	cmd_lbl.editable = false
	cmd_lbl.text = "godot --headless --path . -- --server --port=7777"
	cmd_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmd_lbl.add_theme_font_size_override("font_size", 11)
	cmd_hbox.add_child(cmd_lbl)

	var copy_btn := Button.new()
	copy_btn.text = "Copy"
	copy_btn.add_theme_font_size_override("font_size", 11)
	copy_btn.pressed.connect(func():
		DisplayServer.clipboard_set(cmd_lbl.text)
		_audio.play_click()
		copy_btn.text = "Copied!"
		get_tree().create_timer(1.5).timeout.connect(func(): copy_btn.text = "Copy")
	)
	cmd_hbox.add_child(copy_btn)

	# Engine info
	var info_lbl := Label.new()
	info_lbl.text = "Engine: Godot 4.3+ • Bun.js Backend & ENet Synchronizer • Authoritative Server"
	info_lbl.add_theme_font_size_override("font_size", 10)
	info_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.65))
	parent.add_child(info_lbl)


# --- TAB SWITCHING ---
func _switch_tab(index: int) -> void:
	_audio.play_click()
	_tab_play.visible = (index == 0)
	_tab_guide.visible = (index == 1)
	_tab_settings.visible = (index == 2)

	for i in range(_tab_buttons.size()):
		var btn := _tab_buttons[i]
		var is_active := (i == index)
		_style_tab_button(btn, is_active)


# --- UI HELPERS ---
func _create_line_edit(initial_text: String, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = initial_text
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 12)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.12, 0.9)
	style.border_color = Color(0.25, 0.45, 0.55, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4

	var focus_style := style.duplicate() as StyleBoxFlat
	focus_style.border_color = Color(0.2, 0.85, 0.5)
	focus_style.set_border_width_all(2)

	edit.add_theme_stylebox_override("normal", style)
	edit.add_theme_stylebox_override("focus", focus_style)
	return edit


func _create_action_button(text: String, normal_col: Color, hover_col: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 36)
	btn.add_theme_font_size_override("font_size", 13)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = normal_col
	normal_style.set_corner_radius_all(8)
	normal_style.shadow_color = Color(normal_col.r, normal_col.g, normal_col.b, 0.35)
	normal_style.shadow_size = 6

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = hover_col
	hover_style.set_corner_radius_all(8)
	hover_style.shadow_color = Color(hover_col.r, hover_col.g, hover_col.b, 0.5)
	hover_style.shadow_size = 10

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = normal_col.darkened(0.2)
	pressed_style.set_corner_radius_all(8)

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.mouse_entered.connect(func():
		_audio.play_hover()
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.08)
	)
	btn.mouse_exited.connect(func():
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	)
	return btn


func _create_tab_button(text: String, active: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(110, 28)
	btn.add_theme_font_size_override("font_size", 12)
	_style_tab_button(btn, active)
	btn.mouse_entered.connect(_audio.play_hover)
	return btn


func _style_tab_button(btn: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4

	if active:
		style.bg_color = Color(0.18, 0.65, 0.42, 0.85)
		style.border_color = Color(0.4, 0.95, 0.65)
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		style.bg_color = Color(0.1, 0.14, 0.18, 0.6)
		style.border_color = Color(0.2, 0.28, 0.35, 0.4)
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)


func _create_pill_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 11)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.18, 0.24, 0.7)
	style.border_color = Color(0.25, 0.4, 0.5, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	btn.add_theme_stylebox_override("normal", style)

	var h_style := style.duplicate() as StyleBoxFlat
	h_style.bg_color = Color(0.18, 0.28, 0.36, 0.9)
	btn.add_theme_stylebox_override("hover", h_style)
	btn.mouse_entered.connect(_audio.play_hover)
	return btn


func _create_mini_pill(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 10)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.22, 0.3, 0.6)
	style.border_color = Color(0.25, 0.45, 0.6, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", style)
	btn.mouse_entered.connect(_audio.play_hover)
	return btn


func _create_badge(text: String, border_color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.14, 0.75)
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9))
	p.add_child(lbl)
	return p


# --- NETWORKING LOGIC ---
func _host_port_value() -> int:
	var p := _host_port_input.text.to_int()
	return p if p > 0 else Net.DEFAULT_PORT


func _join_port_value() -> int:
	var p := _port_input.text.to_int()
	return p if p > 0 else Net.DEFAULT_PORT


func _on_host() -> void:
	_audio.play_click()
	var port := _host_port_value()
	_apply_game_choice()
	var err := Net.host(port)
	if err != OK:
		_set_status("Host failed (error %d). Port %d may already be in use." % [err, port], Color(0.95, 0.25, 0.25))
		_audio.play_alert()
		return

	_save_settings()
	_set_status("Lobby hosted on port %d! Loading arena..." % port, Color(0.2, 0.9, 0.4))
	get_tree().change_scene_to_file(Net.GAME_SCENE)


func _on_join() -> void:
	if _connecting:
		return

	_audio.play_click()
	var addr := _address_input.text.strip_edges()
	var port := _join_port_value()

	if addr.is_empty():
		_set_status("Please specify a valid server address.", Color(0.95, 0.4, 0.25))
		_audio.play_alert()
		return

	_connecting = true
	_connect_timer = 0.0
	_host_btn.disabled = true
	_join_btn.disabled = true
	_cancel_btn.visible = true

	var err := Net.join(addr, port)
	if err != OK:
		_connecting = false
		_host_btn.disabled = false
		_join_btn.disabled = false
		_cancel_btn.visible = false
		_set_status("Join failed immediately (error %d)." % err, Color(0.95, 0.25, 0.25))
		_audio.play_alert()
		return

	_set_status("Connecting to %s:%d..." % [addr, port], Color(0.95, 0.8, 0.2))


func _on_cancel() -> void:
	_audio.play_click()
	Net.leave()
	_connecting = false
	_host_btn.disabled = false
	_join_btn.disabled = false
	_cancel_btn.visible = false
	_set_status("Connection canceled.", Color(0.7, 0.75, 0.8))


func _on_connected() -> void:
	_connecting = false
	_save_settings()
	_set_status("Connected! Loading match...", Color(0.2, 0.9, 0.4))
	get_tree().change_scene_to_file(Net.GAME_SCENE)


func _on_failed() -> void:
	Net.leave()
	_connecting = false
	_host_btn.disabled = false
	_join_btn.disabled = false
	_cancel_btn.visible = false
	_set_status("Could not connect to server. Is the host running?", Color(0.95, 0.3, 0.3))
	_audio.play_alert()


func _set_status(msg: String, col: Color) -> void:
	_status_label.text = msg
	_status_dot.color = col


# --- BUN.JS BACKEND ACTIONS ---

func _on_bun_create() -> void:
	_audio.play_click()
	var r_name := _bun_room_name_input.text.strip_edges()
	if r_name.is_empty():
		r_name = "Panda Arena"

	_set_status("Registering room on Bun.js backend...", Color(0.95, 0.8, 0.2))
	var port := Net.DEFAULT_PORT
	_apply_game_choice()
	var host_err := Net.host(port)
	if host_err != OK:
		_set_status("Host error %d on port %d" % [host_err, port], Color(0.95, 0.25, 0.25))
		_audio.play_alert()
		return

	var room: Dictionary = await Net.create_bun_room(r_name, port, "HostPanda")
	if room.is_empty():
		_set_status("Local lobby started, but Bun backend registration failed.", Color(0.95, 0.6, 0.2))
	else:
		_set_status("Room [%s] active on Bun backend! Loading match..." % room.get("code", "OK"), Color(0.2, 0.9, 0.4))

	_save_settings()
	get_tree().change_scene_to_file(Net.GAME_SCENE)


func _on_bun_join_code() -> void:
	_audio.play_click()
	var code := _bun_room_code_input.text.strip_edges().to_upper()
	if code.is_empty():
		_set_status("Please enter a 4-letter room code (e.g. FARM)", Color(0.95, 0.4, 0.25))
		_audio.play_alert()
		return

	_set_status("Looking up room [%s] on Bun backend..." % code, Color(0.95, 0.8, 0.2))
	var room: Dictionary = await Net.join_bun_room(code)
	if room.is_empty():
		_set_status("Room [%s] not found on Bun backend." % code, Color(0.95, 0.3, 0.3))
		_audio.play_alert()
		return

	var host_addr: String = room.get("hostAddress", "127.0.0.1")
	var host_port: int = room.get("port", Net.DEFAULT_PORT)
	_set_status("Found room [%s] at %s:%d! Connecting..." % [code, host_addr, host_port], Color(0.2, 0.8, 0.5))

	_connecting = true
	_connect_timer = 0.0
	_cancel_btn.visible = true

	var err := Net.join(host_addr, host_port)
	if err != OK:
		_connecting = false
		_cancel_btn.visible = false
		_set_status("Could not connect to room [%s] at %s:%d" % [code, host_addr, host_port], Color(0.95, 0.25, 0.25))
		_audio.play_alert()


func _on_bun_spawn_dedicated() -> void:
	_audio.play_click()
	_set_status("Spawning dedicated headless server via Bun backend...", Color(0.95, 0.8, 0.2))
	var room: Dictionary = await Net.spawn_dedicated_bun_room("Dedicated Arena", MapDefs.ORDER[_map_select.selected], ModeDefs.ORDER[_mode_select.selected])
	if room.is_empty():
		_set_status("Could not spawn dedicated server. Is Bun backend running?", Color(0.95, 0.3, 0.3))
		_audio.play_alert()
		return

	var code: String = room.get("code", "")
	var host_addr: String = room.get("hostAddress", "127.0.0.1")
	var host_port: int = room.get("port", 7800)
	_set_status("Dedicated room [%s] spawned on port %d! Connecting..." % [code, host_port], Color(0.2, 0.9, 0.4))

	_connecting = true
	_connect_timer = 0.0
	_cancel_btn.visible = true

	var err := Net.join(host_addr, host_port)
	if err != OK:
		_connecting = false
		_cancel_btn.visible = false
		_set_status("Could not connect to dedicated room %d" % err, Color(0.95, 0.25, 0.25))
		_audio.play_alert()


func _refresh_bun_rooms() -> void:
	if not _bun_rooms_container:
		return

	# Clear existing children
	for child in _bun_rooms_container.get_children():
		child.queue_free()

	var loading_lbl := Label.new()
	loading_lbl.text = "Fetching live lobbies from Bun backend..."
	loading_lbl.add_theme_font_size_override("font_size", 10)
	loading_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.85))
	_bun_rooms_container.add_child(loading_lbl)

	var rooms: Array = await Net.fetch_bun_rooms()

	# Re-clear after await
	for child in _bun_rooms_container.get_children():
		child.queue_free()

	if rooms.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No active rooms right now. Create one or launch a dedicated room!"
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.7))
		_bun_rooms_container.add_child(empty_lbl)
		return

	for r in rooms:
		if not r is Dictionary:
			continue
		var room_dict: Dictionary = r
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var code_badge := _create_badge(room_dict.get("code", "----"), Color(0.2, 0.85, 0.5, 0.4))
		code_badge.custom_minimum_size = Vector2(50, 20)
		row.add_child(code_badge)

		var name_lbl := Label.new()
		name_lbl.text = room_dict.get("name", "Arena")
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var count_pill := _create_mini_pill("%d/%d" % [room_dict.get("playerCount", 1), room_dict.get("maxPlayers", 32)])
		row.add_child(count_pill)

		if room_dict.get("isDedicated", false):
			var ded_badge := _create_badge("Dedicated", Color(0.3, 0.6, 0.9, 0.4))
			row.add_child(ded_badge)

		var join_room_btn := Button.new()
		join_room_btn.text = "Join"
		join_room_btn.add_theme_font_size_override("font_size", 10)
		var h_addr: String = room_dict.get("hostAddress", "127.0.0.1")
		var h_port: int = room_dict.get("port", Net.DEFAULT_PORT)
		join_room_btn.pressed.connect(func():
			_audio.play_click()
			_connecting = true
			_connect_timer = 0.0
			_cancel_btn.visible = true
			_set_status("Joining [%s] at %s:%d..." % [room_dict.get("code", ""), h_addr, h_port], Color(0.95, 0.8, 0.2))
			Net.join(h_addr, h_port)
		)
		row.add_child(join_room_btn)

		_bun_rooms_container.add_child(row)


func _test_bun_connection() -> void:
	_audio.play_click()
	if _bun_url_input:
		Net.set_bun_url(_bun_url_input.text)
	_bun_backend_status_label.text = "Pinging Bun backend..."
	_bun_backend_status_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))

	var health: Dictionary = await Net.fetch_bun_health()
	if health.get("status", "") == "ok":
		_bun_backend_status_label.text = "🟢 Connected! Active rooms: %d • Total players: %d" % [
			health.get("roomsCount", 0),
			health.get("totalPlayers", 0)
		]
		_bun_backend_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
	else:
		_bun_backend_status_label.text = "🔴 Could not connect to Bun backend at %s" % Net.bun_url
		_bun_backend_status_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))


# --- SETTINGS PERSISTENCE ---
func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("network", "address", _address_input.text.strip_edges())
	cfg.set_value("network", "join_port", _port_input.text.strip_edges())
	cfg.set_value("network", "host_port", _host_port_input.text.strip_edges())
	cfg.set_value("network", "bun_url", Net.bun_url)
	cfg.set_value("game", "map", MapDefs.ORDER[_map_select.selected])
	cfg.set_value("game", "mode", ModeDefs.ORDER[_mode_select.selected])
	var audio_class = load("res://scripts/menu_audio.gd")
	cfg.set_value("audio", "sound_enabled", audio_class.sound_enabled)
	cfg.save(CONFIG_FILE)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_FILE) == OK:
		if cfg.has_section_key("network", "address"):
			_address_input.text = cfg.get_value("network", "address")
		if cfg.has_section_key("network", "join_port"):
			_port_input.text = cfg.get_value("network", "join_port")
		if cfg.has_section_key("network", "host_port"):
			_host_port_input.text = cfg.get_value("network", "host_port")
		if cfg.has_section_key("network", "bun_url"):
			var u: String = cfg.get_value("network", "bun_url")
			Net.set_bun_url(u)
			if _bun_url_input:
				_bun_url_input.text = u
		_map_select.selected = maxi(MapDefs.ORDER.find(cfg.get_value("game", "map", "")), 0)
		_mode_select.selected = maxi(ModeDefs.ORDER.find(cfg.get_value("game", "mode", "")), 0)
		_update_mode_desc()
		if cfg.has_section_key("audio", "sound_enabled"):
			var audio_class = load("res://scripts/menu_audio.gd")
			audio_class.sound_enabled = cfg.get_value("audio", "sound_enabled", true)

