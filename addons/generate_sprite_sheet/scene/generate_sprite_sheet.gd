#============================================================
#    Generate Sprite Sheet
#============================================================
# - author: zhangxuetu
# - datetime: 2023-03-31 00:21:22
# - version: 4.0
#============================================================
## 合并图片为一个精灵表
@tool
class_name GenerateSpriteSheetMain
extends MarginContainer


const MAIN_NODE_META_KEY = &"GenerateSpriteSheetMain_main_node"


# 菜单列表
@onready var menu_list := %menu_list as MenuList
# 文件树
@onready var file_tree := %file_tree as GenerateSpriteSheet_FileTree
# 等待处理文件列表，拖拽进去，选中这个文件，可以从操作台中进行开始处理这个图片
# 处理后的文件在这里面保存，然后生成会从这个列表里生成处理
@onready var pending := %pending as GenerateSpriteSheet_Pending
# 预览图片
@onready var preview_container := %preview_container as GenerateSpriteSheet_PreviewContainer
# 操作处理容器
@onready var handle_container = %handle_container

@onready var export_panding_dialog := %export_panding_dialog as FileDialog
@onready var scan_dir_dialog := %scan_dir_dialog as FileDialog
@onready var export_preview_dialog = %export_preview_dialog

@onready var prompt_info_label = %prompt_info_label
@onready var prompt_info_anim_player = %prompt_info_anim_player 


#============================================================
#  内置
#============================================================
func _init():
	pass


func _ready():
	# 初始化菜单
	menu_list.init_menu({
		"文件": ["扫描目录"],
		"导出": ["导出所有待处理图像"]
	})
	
	# 边距
	for child in handle_container.get_children():
		if child is MarginContainer:
			for dir in ["left", "right", "top", "bottom"]:
				child.set("theme_override_constants/margin_" + dir, 8)
	
	# 提示信息
	Engine.set_meta(MAIN_NODE_META_KEY, self)
	prompt_info_label.modulate.a = 0
	
	
	await get_tree().create_timer(0.1).timeout
	# 扫描加载文件列表(测试使用)
	if file_tree._root == null:
		var path = "res://src/main/assets/texture/"
		file_tree.update_tree(path, GenerateSpriteSheetUtil.get_texture_filter())
	


func _exit_tree():
	GenerateSpriteSheetUtil.save_cache_data()


#============================================================
#  自定义
#============================================================
## 显示消息内容
static func show_message(message: String):
	if Engine.has_meta(MAIN_NODE_META_KEY):
		var node = Engine.get_meta(MAIN_NODE_META_KEY) as GenerateSpriteSheetMain
		var label := node.prompt_info_label as Label
		label.text = " " + message
		# 闪烁动画
		var anim_player = node.prompt_info_anim_player as AnimationPlayer
		anim_player.stop()
		anim_player.play("twinkle")
		


class IfTrue:
	var _value
	
	func _init(value):
		_value = value
	
	func else_show_message(message: String) -> void:
		if _value:
			pass
		else:
			GenerateSpriteSheetMain.show_message(message)
	
	##  如果值为 [code]true[/code] 则执行回调方法
	##[br]
	##[br][code]callback[/code] 这个方法需要有一个参数用于接收上个回调的值 
	func if_true(callback: Callable) -> IfTrue:
		if _value:
			return IfTrue.new(callback.call(_value))
		return IfTrue.new(null)


##  如果值为 [code]true[/code] 则执行回调方法
##[br]
##[br][code]callback[/code]  这个方法没有任何参数，可以有一个返回值用于下一个 if_true 方法的执行，如果没有返回值，
##则默认为 value 参数值
##[br][code]return[/code]  返回一个 IfTrue 对象用以链式调用执行功能
static func if_true(value, callback: Callable) -> IfTrue:
	if value:
		var r = callback.call()
		return IfTrue.new(r if r else value)
	return IfTrue.new(null)


## 如果存在预览图像则执行回调
func if_has_texture_else_show_message(callback: Callable, message: String = "没有预览图像"):
	if_true(preview_container.has_texture(), callback).else_show_message(message)



#============================================================
#  连接信号
#============================================================
func _on_file_tree_selected(path_type, path: String):
	preview_container.clear_texture()
	if path_type == GenerateSpriteSheet_FileTree.PathType.FILE:
		var res : Texture2D = GenerateSpriteSheetUtil.load_image(path)
		if res is Texture2D:
			preview_container.preview(res)


func _on_file_tree_added_item(item: TreeItem):
	# 文件树添加新的 item 时
	var data = item.get_metadata(0) as Dictionary
	if data.path_type == GenerateSpriteSheet_FileTree.PathType.FILE:
		var path = data.path
		var texture = GenerateSpriteSheetUtil.load_image(path)
		item.set_icon(0, texture)
		item.set_icon_max_width(0, 16)


func _on_preview_container_created_texture(texture: Texture2D):
	pending.add_data({
		"texture": texture,
		"path": "",
	})


func _on_add_selected_rect_pressed():
	if_has_texture_else_show_message(func():
		# 添加选中的表格区域的图片到待处理区
		for image_texture in preview_container.get_selected_texture_list():
			pending.add_data({ texture = image_texture })
		preview_container.clear_select()
	)


func _on_clear_select_pressed():
	if_has_texture_else_show_message(func():
		preview_container.clear_select()
	)


func _on_select_all_pressed():
	if_has_texture_else_show_message(func():
		if_true(preview_container.get_preview_grid_visible(), func():
			var grid = preview_container.get_cell_grid()
			for x in grid.x:
				for y in grid.y:
					var coordinate = Vector2i(x, y)
					preview_container.select(coordinate)
		).else_show_message("还未进行切分！")
	)


func _on_menu_list_menu_pressed(idx, menu_path):
	match menu_path:
		"/文件/扫描目录":
			scan_dir_dialog.popup_centered()
		
		"/导出/导出所有待处理图像":
			if_true(pending.get_data_list().size() > 0, func():
				export_panding_dialog.popup_centered()
			).else_show_message("没有待处理的图像")


func _on_file_dialog_dir_selected(dir):
	file_tree.update_tree(dir, GenerateSpriteSheetUtil.get_texture_filter())


func _on_pending_item_double_clicked(data):
	# 预览双击的图片
	var texture = data["texture"]
	preview_container.preview(texture)


func _on_export_panding_dialog_dir_selected(dir: String):
	if_true(DirAccess.dir_exists_absolute(dir), func():
		var list = pending.get_texture_list()
		var idx = -1
		var exported_file_list : Array[String] = []
		var filename : String 
		for texture in list:
			while true:
				idx += 1
				filename = "subtexture_%04d.png" % idx
				if not FileAccess.file_exists(filename):
					break
			exported_file_list.append(dir.path_join(filename))
			ResourceSaver.save(texture, exported_file_list.back() )
		print("已导出文件：")
		print(exported_file_list)
	).else_show_message("没有这个目录")


func _on_animation_panel_played(animation: Animation):
	preview_container.play(animation)


func _on_animation_panel_stopped():
	preview_container.stop()


func _on__merged(data: GenerateSpriteSheet_PendingHandle.Merge):
	var texture_list : Array[Texture2D] = pending.get_selected_texture_list()
	if_true(texture_list.size() > 0, func():
		# 预览
		var merge_texture = data.execute(texture_list)
		if merge_texture:
			preview_container.preview(merge_texture)
		
	).else_show_message("没有选中任何图像")


func _on_export_preview_pressed():
	if_has_texture_else_show_message(func():
		export_preview_dialog.popup_centered()
	)


func _on_export_preview_dialog_file_selected(path):
	# 导出预览图像
	if preview_container.get_texture():
		var texture = preview_container.get_texture()
		ResourceSaver.save(texture, path)
		show_message("已保存预览图像")


func _on__resize_selected(new_size: Vector2i):
	var data_list = pending.get_selected_data_list()
	if_true(data_list, func():
		# 重置待处理区图片大小
		for data in pending.get_selected_data_list():
			var texture = data['texture'] as Texture2D
			if Vector2i(texture.get_size()) != new_size:
				var node = data['node'] as Control
				data['texture'] = GenerateSpriteSheetUtil.resize_texture(texture, new_size)
				node.set_data(data)
	).else_show_message("没有选中的图像")


func _on__rescale(texture_scale: Vector2):
	if_has_texture_else_show_message(func():
		# 缩放
		var texture = preview_container.get_texture()
		var new_texture = GenerateSpriteSheetUtil.scale_texture(texture, texture_scale)
	#	pending.add_data({ "texture": new_texture })
		preview_container.preview(new_texture)
	)


func _on__resize(texture_size):
	if_has_texture_else_show_message(func():
		# 重设大小
		var texture = preview_container.get_texture()
		var new_texture = GenerateSpriteSheetUtil.resize_texture(texture, texture_size)
		preview_container.preview(new_texture)
	)


func _on__recolor(from: Color, to: Color, threshold: float):
	if_has_texture_else_show_message(func():
		var texture = preview_container.get_texture()
		var new_texture = GenerateSpriteSheetUtil.replace_color(texture, from, to, threshold)
		preview_container.preview(new_texture, false)
	)


func _on_git_new_version_meta_clicked(meta):
	OS.shell_open(meta)


func _on_add_preview_texture_pressed():
	if_has_texture_else_show_message(func():
		pending.add_data({ texture = preview_container.get_texture() })
	)


func _on_pending_previewed(texture: Texture2D):
	if_true(is_instance_valid(texture), func():
		preview_container.preview(texture)
	).else_show_message("错误的预览图像")


func _on__outline(color: Color):
	if_has_texture_else_show_message(func():
		var texture = preview_container.get_texture()
		var new_texture = GenerateSpriteSheetUtil.outline(texture, color)
		preview_container.preview(new_texture, false)
	)


func _on__split_column_row(column_row: Vector2i):
	if_has_texture_else_show_message(func():
		var texture_size = Vector2i(preview_container.get_texture().get_size())
		var cell_size : Vector2i = texture_size / column_row
		preview_container.split(cell_size)
	)


func _on__split_size(cell_size: Vector2i):
	if_has_texture_else_show_message(func():
		preview_container.split(cell_size)
	)


func _on__clear_transparency():
	if_has_texture_else_show_message(func():
		var texture = preview_container.get_texture()
		var image = texture.get_image() as Image
		var rect = image.get_used_rect()
		var new_image = image.get_region(rect)
		preview_container.preview( ImageTexture.create_from_image(new_image) )
		
	)