extends CustomTabContainer
class_name ViewContainer


signal ready_to_quit
signal quit_canceled

export var dialog_manager: NodePath

var _dialog_manager: DialogManager
var _is_quitting := false


func _ready() -> void:
	_dialog_manager = get_node(dialog_manager)
	GlobalEventBus.register_listener(self, "create_template", "_on_create_template")
	GlobalEventBus.register_listener(self, "load_template", "_on_load_template")
	GlobalEventBus.register_listener(self, "save_template", "_on_save_template")
	GlobalEventBus.register_listener(self, "save_template_as", "_on_save_template_as")
	GlobalEventBus.register_listener(self, "open_settings", "_load_settings_view")
	
	Signals.safe_connect(self, "tabs_cleared", self, "_on_tabs_cleared")
	Signals.safe_connect(_dialog_manager, "canceled", self, "_on_close_cancel")
	Signals.safe_connect(_dialog_manager, "discard", self, "_on_close_discard")
	Signals.safe_connect(_dialog_manager, "confirm", self, "_on_close_confirm")
	
	_load_start_view()


func save_all_and_close() -> void:
	_is_quitting = true
	
	while get_child_count() > 0:
		if not _is_quitting:
			return
		select_tab(0)
		if get_child(0) is ConceptGraphEditorView:
			_on_tab_close_request(0)
			yield(self, "tab_closed")
		else:
			close_tab(0)
	
	emit_signal("ready_to_quit")


func _save_current_template(close := false) -> void:
	var view = get_current_tab_content()
	if not view is ConceptGraphEditorView:
		return
	
	view.save_template()
	if close:
		yield(view, "template_saved")
		close_tab()


func _save_all_templates() -> void:
	for view in get_children():
		if view is ConceptGraphEditorView:
			view.save_template()


func _load_start_view():
	if _is_view_opened(WelcomeView):
		return
	var start_view = preload("res://ui/views/welcome/welcome_view.tscn").instance()
	add_tab(start_view)


func _load_settings_view():
	if _is_view_opened(EditorSettingsView):
		return 
	var settings_view = preload("res://ui/views/settings/editor_settings_view.tscn").instance()
	add_tab(settings_view)


func _create_template(path: String) -> void:
	pass


func _load_template(path: String) -> void:
	# Check if the requested template isn't already open
	for i in get_child_count():
		var view = get_child(i)
		if not view is ConceptGraphEditorView:
			continue

		# If the template is already loaded, focus the existing tab
		if view._template_path == path:
			select_tab(i)
			return

	# Template isn't already loaded, create an editor view
	var editor: ConceptGraphEditorView = load("res://ui/views/editor/editor_view.tscn").instance()
	editor.name = path.get_file().get_basename()
	add_tab(editor)
	editor.load_template(path)


func _save_template_as(path: String) -> void:
	pass


func _is_view_opened(type: GDScript) -> bool:
	for view in get_children():
		if view is type:
			return true
	return false


func _on_tabs_cleared() -> void:
	if _is_quitting:
		emit_signal("ready_to_quit")
	else:
		_load_start_view()


func _on_create_template(path = null) -> void:
	if path:
		_create_template(path)
	else:
		_dialog_manager.show_file_dialog(Constants.CREATE)


func _on_load_template(path = null) -> void:
	if path:
		_load_template(path)
	else:
		_dialog_manager.show_file_dialog(Constants.LOAD)


func _on_save_template_as(path = null) -> void:
	if path:
		_save_template_as(path)
	else:
		_dialog_manager.show_file_dialog(Constants.SAVE_AS)


func _on_tab_close_request(tab: int) -> void:
	var view = get_tab_content(tab)
	if view is ConceptGraphEditorView and view.has_pending_changes():
		_dialog_manager.show_confirm_dialog()
	else:
		._on_tab_close_request(tab)


func _on_close_confirm() -> void:
	_save_current_template(true)


func _on_close_discard() -> void:
	close_tab(current_tab)


func _on_close_canceled() -> void:
	if _is_quitting:
		_is_quitting = false
		emit_signal("tab_closed")	# Don't leave the yield pending
		emit_signal("quit_canceled")