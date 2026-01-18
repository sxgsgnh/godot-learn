# EditorNode 整体分析报告

## 目录

1. [EditorNode 概览](#editornode-概览)
2. [EditorData 详细分析](#editordata-详细分析)
3. [EditorPlugin 详细分析](#editorplugin-详细分析)
4. [三者关系与交互](#三者关系与交互)
5. [核心功能流程](#核心功能流程)
6. [适用于 rm-editor 分支的分析](#适用于-rm-editor-分支的分析)

---

## EditorNode 概览

### 1.1 类定义

```cpp
class EditorNode : public Node {
    GDCLASS(EditorNode, Node);
    // ...
};
```

**继承关系**：`EditorNode` → `Node` → `CanvasItem` → `Node2D`

**位置**：`editor/editor_node.h` (1061 行)

### 1.2 核心职责

EditorNode 是 Godot 编辑器的核心控制器，负责：

| 职责 | 说明 |
|-----|-----|
| **UI 布局管理** | 管理编辑器的整个 GUI 结构（菜单栏、工具栏、Dock 等） |
| **场景管理** | 打开、保存、关闭编辑中的场景 |
| **插件系统** | 加载、管理和卸载编辑器插件 |
| **项目配置** | 管理项目设置、导出、构建等 |
| **工具栏和菜单** | 提供编辑器菜单和工具栏选项 |
| **主屏幕切换** | 管理 2D/3D/脚本/资源库编辑器模式切换 |
| **撤销/重做** | 管理编辑器的撤销重做系统 |
| **调试器集成** | 集成调试功能 |

### 1.3 主要枚举类型

```cpp
enum MenuOptions {
    // Scene 菜单
    SCENE_NEW_SCENE,
    SCENE_OPEN_SCENE,
    SCENE_SAVE_SCENE,
    SCENE_SAVE_AS_SCENE,
    SCENE_SAVE_ALL_SCENES,
    SCENE_CLOSE,
    SCENE_QUIT,
    // ...

    // Project 菜单
    PROJECT_OPEN_SETTINGS,
    PROJECT_EXPORT,
    PROJECT_RELOAD_CURRENT_PROJECT,
    // ...

    // Tools 菜单
    TOOLS_ORPHAN_RESOURCES,
    TOOLS_BUILD_PROFILE_MANAGER,
    TOOLS_PROJECT_UPGRADE,
    // ...

    // Editor 菜单
    EDITOR_OPEN_SETTINGS,
    EDITOR_COMMAND_PALETTE,
    EDITOR_TOGGLE_FULLSCREEN,
    // ...

    // Help 菜单
    HELP_SEARCH,
    // ...
};

enum ActionOnPlay {
    ACTION_ON_PLAY_DO_NOTHING,
    ACTION_ON_PLAY_OPEN_OUTPUT,
    ACTION_ON_PLAY_OPEN_DEBUGGER,
};

enum SceneNameCasing {
    SCENE_NAME_CASING_AUTO,
    SCENE_NAME_CASING_PASCAL_CASE,
    SCENE_NAME_CASING_SNAKE_CASE,
    // ...
};
```

### 1.4 EditorNode 的 9 个直接子节点

```
EditorNode
├── EditorPropertyNameProcessor (属性处理)
├── EditorFileSystem (文件系统监控)
├── EditorExport (导出管理)
├── EditorResourcePreview (资源预览)
├── ProgressDialog (进度对话框)
├── Panel (gui_base) ← UI 根容器
├── Timer (layout_save_timer)
├── Timer (scan_changes_timer)
└── AudioStreamPreviewGenerator (音频预览)

[以及 32+ 个对话框作为 gui_base 的子节点]
```

---

## EditorData 详细分析

### 2.1 类定义与用途

```cpp
class EditorData {
    // 编辑器的中央数据管理系统
    // 管理场景、插件、选择历史、自定义类型等
};
```

**位置**：`editor/editor_data.h` (336 行)

**核心职责**：
- 管理编辑中的场景列表
- 管理编辑器插件
- 管理编辑选择历史
- 管理自定义类型
- 管理撤销/重做系统

### 2.2 核心子类和数据结构

#### 2.2.1 EditorSelectionHistory

```cpp
class EditorSelectionHistory {
private:
    struct _Object {
        Ref<RefCounted> ref;
        ObjectID object;
        String property;
        bool inspector_only = false;
    };

    struct HistoryElement {
        Vector<_Object> path;  // 选择路径（可能有子资源）
        int level = 0;         // 当前在路径中的位置
    };

    Vector<HistoryElement> history;
    int current_elem_idx;  // 当前历史位置
};
```

**功能**：
- 记录用户在编辑器中选择过的对象
- 支持前进/后退导航（类似浏览器的前进后退）
- 支持子资源选择（例如嵌套资源的独立编辑）

**主要方法**：
```cpp
void add_object(ObjectID p_object, const String &p_property = "");
bool next();  // 下一个历史记录
bool previous();  // 上一个历史记录
ObjectID get_current();
void clear();
```

#### 2.2.2 EditedScene

```cpp
struct EditedScene {
    Node *root = nullptr;  // 场景根节点
    String path;  // 文件路径
    uint64_t file_modified_time = 0;  // 文件修改时间

    Dictionary editor_states;  // 编辑器特定状态（Dock 状态等）
    List<Node *> selection;  // 当前选择的节点
    Vector<EditorSelectionHistory::HistoryElement> history_stored;  // 保存的历史
    int history_current = 0;  // 当前历史位置

    Dictionary custom_state;  // 自定义状态
    NodePath live_edit_root;  // 实时编辑根节点
    int history_id = 0;  // 历史 ID
    uint64_t last_checked_version = 0;  // 最后检查版本
};
```

**用途**：
- 存储每个编辑中的场景的所有状态
- 支持多场景编辑
- 场景切换时恢复之前的编辑状态

#### 2.2.3 CustomType

```cpp
struct CustomType {
    String name;  // 类型名称
    Ref<Script> script;  // 对应的脚本
    Ref<Texture2D> icon;  // 自定义图标
};
```

**用途**：
- 允许用户定义自定义节点类型
- 在场景树中显示自定义类型
- 从脚本实例化自定义类型

### 2.3 EditorData 的核心数据成员

```cpp
class EditorData {
private:
    // 插件管理
    Vector<EditorPlugin *> editor_plugins;  // 所有编辑器插件
    HashMap<StringName, EditorPlugin *> extension_editor_plugins;  // 扩展插件

    // 自定义类型
    HashMap<String, Vector<CustomType>> custom_types;  // 分类的自定义类型

    // 剪贴板
    struct PropertyData {
        String name;
        Variant value;
    };
    List<PropertyData> clipboard;  // 属性剪贴板

    // 撤销/重做
    EditorUndoRedoManager *undo_redo_manager;
    Vector<Callable> undo_redo_callbacks;  // 回调列表
    HashMap<StringName, Callable> move_element_functions;  // 数组元素移动函数

    // 场景管理
    Vector<EditedScene> edited_scene;  // 所有编辑中的场景
    int current_edited_scene = -1;  // 当前编辑的场景索引
    int last_created_scene = 1;  // 上次创建的场景 ID

    // 脚本类图标
    HashMap<StringName, String> _script_class_icon_paths;
    HashMap<String, StringName> _script_class_file_to_path;
    HashMap<String, Ref<Texture2D>> _script_icon_cache;
};
```

### 2.4 EditorData 的主要方法

#### 插件管理

```cpp
// 添加/移除编辑器插件
void add_editor_plugin(EditorPlugin *p_plugin);
void remove_editor_plugin(EditorPlugin *p_plugin);

// 查询插件
int get_editor_plugin_count() const;
EditorPlugin *get_editor_plugin(int p_idx);
EditorPlugin *get_handling_main_editor(Object *p_object);  // 获取处理对象的插件
Vector<EditorPlugin *> get_handling_sub_editors(Object *p_object);  // 获取辅助编辑器

// 扩展插件
void add_extension_editor_plugin(const StringName &p_class_name, EditorPlugin *p_plugin);
EditorPlugin *get_extension_editor_plugin(const StringName &p_class_name);
```

#### 场景管理

```cpp
// 获取场景数据
int get_edited_scene_count() const;
int get_edited_scene() const;  // 当前编辑的场景
EditedScene &get_edited_scene_root(int p_idx);

// 切换场景
void set_edited_scene(int p_scene);
void add_edited_scene(int p_at_pos);
void remove_scene(int p_idx);
```

#### 自定义类型

```cpp
// 添加/移除自定义类型
void add_custom_type(const String &p_type, const String &p_inherits,
                     const Ref<Script> &p_script, const Ref<Texture2D> &p_icon);
void remove_custom_type(const String &p_type);

// 查询自定义类型
const CustomType *get_custom_type_by_name(const String &p_name) const;
const CustomType *get_custom_type_by_path(const String &p_path) const;
Variant instantiate_custom_type(const String &p_type, const String &p_inherits);
```

#### 撤销/重做

```cpp
// 回调管理
void add_undo_redo_inspector_hook_callback(Callable p_callable);
void remove_undo_redo_inspector_hook_callback(Callable p_callable);
const Vector<Callable> get_undo_redo_inspector_hook_callback();

// 数组元素移动
void add_move_array_element_function(const StringName &p_class, Callable p_callable);
Callable get_move_array_element_function(const StringName &p_class) const;
```

#### 剪贴板

```cpp
void copy_object_params(Object *p_object);  // 复制对象属性
void paste_object_params(Object *p_object);  // 粘贴对象属性
```

#### 状态保存/恢复

```cpp
Dictionary get_editor_plugin_states() const;  // 获取所有插件状态
void set_editor_plugin_states(const Dictionary &p_states);  // 设置插件状态
Dictionary get_scene_editor_states(int p_idx) const;  // 获取场景编辑器状态

void save_editor_external_data();  // 保存外部数据
void apply_changes_in_editors();  // 应用编辑器更改
```

### 2.5 EditorData 数据流

```
场景编辑流程
    ↓
编辑器修改对象
    ↓
EditorData 记录状态变化
    ├─ 撤销/重做管理（UndoRedo）
    ├─ 选择历史（SelectionHistory）
    ├─ 场景状态（EditedScene）
    └─ 编辑器状态（editor_states Dictionary）
    ↓
保存场景
    ├─ 场景保存为 .tscn 文件
    └─ 编辑器状态保存（可选）
    ↓
关闭编辑器
    ↓
下次打开场景
    ├─ 恢复编辑器状态
    ├─ 恢复选择历史
    └─ 恢复 Dock 布局
```

---

## EditorPlugin 详细分析

### 3.1 类定义与继承

```cpp
class EditorPlugin : public Node {
    GDCLASS(EditorPlugin, Node);
    friend class EditorData;
};
```

**继承关系**：`EditorPlugin` → `Node` → `CanvasItem` → `Node2D`

**位置**：`editor/plugins/editor_plugin.h` (307 行)

### 3.2 EditorPlugin 的角色

EditorPlugin 是编辑器扩展的基类，允许开发者：
- 添加自定义编辑器功能
- 创建新的编辑器窗口/Dock
- 处理特定文件类型
- 自定义场景导入/导出
- 添加自定义节点类型
- 集成外部工具

### 3.3 自定义容器枚举

```cpp
enum CustomControlContainer {
    CONTAINER_TOOLBAR,                      // 工具栏
    CONTAINER_SPATIAL_EDITOR_MENU,          // 3D 编辑器菜单
    CONTAINER_SPATIAL_EDITOR_SIDE_LEFT,     // 3D 编辑器左侧边栏
    CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT,    // 3D 编辑器右侧边栏
    CONTAINER_SPATIAL_EDITOR_BOTTOM,        // 3D 编辑器底部
    CONTAINER_CANVAS_EDITOR_MENU,           // 2D 编辑器菜单
    CONTAINER_CANVAS_EDITOR_SIDE_LEFT,      // 2D 编辑器左侧边栏
    CONTAINER_CANVAS_EDITOR_SIDE_RIGHT,     // 2D 编辑器右侧边栏
    CONTAINER_CANVAS_EDITOR_BOTTOM,         // 2D 编辑器底部
    CONTAINER_INSPECTOR_BOTTOM,             // 检查器底部
    CONTAINER_PROJECT_SETTING_TAB_LEFT,     // 项目设置左侧标签
    CONTAINER_PROJECT_SETTING_TAB_RIGHT,    // 项目设置右侧标签
};

enum DockSlot {
    DOCK_SLOT_LEFT_UL,      // 左上
    DOCK_SLOT_LEFT_BL,      // 左下
    DOCK_SLOT_LEFT_UR,      // 左中上
    DOCK_SLOT_LEFT_BR,      // 左中下
    DOCK_SLOT_RIGHT_UL,     // 右上
    DOCK_SLOT_RIGHT_BL,     // 右下
    DOCK_SLOT_RIGHT_UR,     // 右中上
    DOCK_SLOT_RIGHT_BR,     // 右中下
    DOCK_SLOT_BOTTOM,       // 底部
    DOCK_SLOT_MAX,
};

enum AfterGUIInput {
    AFTER_GUI_INPUT_PASS,       // 继续处理
    AFTER_GUI_INPUT_STOP,       // 停止处理
    AFTER_GUI_INPUT_CUSTOM,     // 自定义处理
};
```

### 3.4 虚函数接口（GDVIRTUAL）

```cpp
// ========== 输入处理 ==========

// 2D 画布输入处理
GDVIRTUAL1R(bool, _forward_canvas_gui_input, Ref<InputEvent>)
// 返回 true 表示处理了输入事件

// 2D 画布绘制覆盖
GDVIRTUAL1(_forward_canvas_draw_over_viewport, Control *)
// 在 2D 编辑器上方绘制

// 2D 画布强制绘制
GDVIRTUAL1(_forward_canvas_force_draw_over_viewport, Control *)
// 强制在最上方绘制

// 3D 场景输入处理
GDVIRTUAL2R(int, _forward_3d_gui_input, Camera3D *, Ref<InputEvent>)
// 返回 AfterGUIInput 值

// 3D 场景绘制覆盖
GDVIRTUAL1(_forward_3d_draw_over_viewport, Control *)
GDVIRTUAL1(_forward_3d_force_draw_over_viewport, Control *)

// ========== 插件信息 ==========

GDVIRTUAL0RC(String, _get_plugin_name)  // 插件名称
GDVIRTUAL0RC(Ref<Texture2D>, _get_plugin_icon)  // 插件图标
GDVIRTUAL0RC(bool, _has_main_screen)  // 是否有主屏幕
GDVIRTUAL1(_make_visible, bool)  // 显示/隐藏插件 UI

// ========== 编辑对象 ==========

GDVIRTUAL1(_edit, Object *)  // 编辑指定对象
GDVIRTUAL1RC(bool, _handles, Object *)  // 是否处理该对象类型

// ========== 状态管理 ==========

GDVIRTUAL0RC(Dictionary, _get_state)  // 获取插件状态
GDVIRTUAL1(_set_state, Dictionary)  // 恢复插件状态
GDVIRTUAL0(_clear)  // 清除临时数据

// ========== 数据管理 ==========

GDVIRTUAL1RC(String, _get_unsaved_status, String)  // 获取未保存状态
GDVIRTUAL0(_save_external_data)  // 保存外部数据
GDVIRTUAL0(_apply_changes)  // 应用更改

// ========== 调试 ==========

GDVIRTUAL0RC(Vector<String>, _get_breakpoints)  // 获取断点列表

// ========== 构建 ==========

GDVIRTUAL0R(bool, _build)  // 构建项目（返回 false 阻止运行）
GDVIRTUAL2RC(Vector<String>, _run_scene, String, Vector<String>)  // 运行场景

// ========== 布局 ==========

GDVIRTUAL1(_set_window_layout, Ref<ConfigFile>)  // 应用窗口布局
GDVIRTUAL1(_get_window_layout, Ref<ConfigFile>)  // 获取窗口布局

// ========== 生命周期 ==========

GDVIRTUAL0(_enable_plugin)  // 启用插件
GDVIRTUAL0(_disable_plugin)  // 禁用插件
```

### 3.5 公共 API 方法

#### 控制 UI 方法

```cpp
// 添加/移除 Dock
void add_dock(EditorDock *p_dock);
void remove_dock(EditorDock *p_dock);

// 添加/移除控制到容器
void add_control_to_container(CustomControlContainer p_location, Control *p_control);
void remove_control_from_container(CustomControlContainer p_location, Control *p_control);

// 工具菜单
void add_tool_menu_item(const String &p_name, const Callable &p_callable);
void add_tool_submenu_item(const String &p_name, PopupMenu *p_submenu);
void remove_tool_menu_item(const String &p_name);
PopupMenu *get_export_as_menu();  // 获取"导出为"菜单
```

#### 输入转发

```cpp
void set_input_event_forwarding_always_enabled();
bool is_input_event_forwarding_always_enabled();

void set_force_draw_over_forwarding_enabled();
bool is_force_draw_over_forwarding_enabled();
```

#### 通知

```cpp
void notify_main_screen_changed(const String &screen_name);  // 主屏幕改变
void notify_scene_changed(const Node *scn_root);  // 场景改变
void notify_scene_closed(const String &scene_filepath);  // 场景关闭
void notify_resource_saved(const Ref<Resource> &p_resource);  // 资源保存
void notify_scene_saved(const String &p_scene_filepath);  // 场景保存
```

#### 输入处理虚函数实现

```cpp
virtual bool forward_canvas_gui_input(const Ref<InputEvent> &p_event);
virtual void forward_canvas_draw_over_viewport(Control *p_overlay);
virtual EditorPlugin::AfterGUIInput forward_3d_gui_input(Camera3D *p_camera, const Ref<InputEvent> &p_event);
```

#### 其他功能

```cpp
// 底部面板
Button *add_control_to_bottom_panel(Control *p_control, const String &p_title);
void remove_control_from_bottom_panel(Control *p_control);
void make_bottom_panel_item_visible(Control *p_item);
void hide_bottom_panel();

// 脚本创建对话框
ScriptCreateDialog *get_script_create_dialog();
EditorInterface *get_editor_interface();

// 扩展 API
void add_import_plugin(const Ref<EditorImportPlugin> &p_importer);
void add_export_plugin(const Ref<EditorExportPlugin> &p_exporter);
void add_export_platform(const Ref<EditorExportPlatform> &p_platform);
void add_node_3d_gizmo_plugin(const Ref<EditorNode3DGizmoPlugin> &p_gizmo_plugin);
void add_inspector_plugin(const Ref<EditorInspectorPlugin> &p_plugin);
void add_scene_format_importer_plugin(const Ref<EditorSceneFormatImporter> &p_importer);
void add_autoload_singleton(const String &p_name, const String &p_path);
void add_debugger_plugin(const Ref<EditorDebuggerPlugin> &p_plugin);
```

### 3.6 EditorPlugins 工厂类

```cpp
class EditorPlugins {
    // 静态插件工厂
    static EditorPluginCreateFunc creation_funcs[MAX_CREATE_FUNCS];
    static int creation_func_count;

public:
    static int get_plugin_count();
    static EditorPlugin *create(int p_idx);

    template <typename T>
    static void add_by_type();  // 添加插件类型

    static void add_create_func(EditorPluginCreateFunc p_func);
};
```

**用途**：
- 集中管理所有编辑器插件的创建
- 支持动态插件加载
- 支持 GDExtension 插件系统

### 3.7 常见的 EditorPlugin 子类

在 Godot 编辑器中有许多 EditorPlugin 的实现：

```
EditorPlugin
├── Node3DEditorPlugin (3D 编辑器)
├── CanvasItemEditorPlugin (2D 编辑器)
├── ScriptEditorPlugin (脚本编辑器)
├── AnimationPlayerEditorPlugin (动画编辑器)
├── AudioBusEditorPlugin (音频总线编辑器)
├── TileSetEditorPlugin (瓷砖集编辑器)
├── ShaderEditorPlugin (着色器编辑器)
├── VisualShaderEditorPlugin (可视化着色器编辑器)
└── ... 更多编辑器插件
```

---

## 三者关系与交互

### 4.1 架构图

```
┌─────────────────────────────────────────────────────┐
│                    EditorNode                        │
│                 (主编辑器控制器)                      │
├─────────────────────────────────────────────────────┤
│
│  ┌──────────────────────────┐    ┌────────────────┐
│  │    EditorData            │    │ EditorPlugin   │
│  │  (中央数据管理)          │    │  (编辑器扩展)  │
│  │                          │    │                │
│  ├─ edited_scene            │    ├─ GDVIRTUAL API │
│  ├─ editor_plugins ◄────────┼────┤ 虚函数接口    │
│  ├─ selection_history       │    │                │
│  ├─ custom_types ◄──────┐   │    ├─ GUI 控制     │
│  ├─ undo_redo_manager   │   │    │ UI 元素       │
│  └─ clipboard           │   │    └────────────────┘
│                         │   │
│                         │   │
└────────────┬────────────┼───┼─────────────────────┘
             │            │   │
             │            │   │
        ┌────▼────────────▼───▼─────┐
        │   编辑器数据流 & 事件       │
        │                           │
        ├─ 场景打开/关闭             │
        ├─ 选择对象变化             │
        ├─ 属性编辑变化             │
        ├─ 插件启用/禁用            │
        └─ 主屏幕切换              │
```

### 4.2 数据流向

#### 场景编辑流程

```
用户操作（如修改节点属性）
    ↓
EditorNode 捕获事件
    ↓
转发给相应的 EditorPlugin（如 Node3DEditorPlugin）
    ↓
插件处理并修改场景树
    ↓
修改通过 EditorUndoRedoManager 记录（EditorData 管理）
    ↓
EditorSelectionHistory 更新选择历史
    ↓
通知其他编辑器组件（如属性检查器）
    ↓
场景标记为已修改
    ↓
用户保存（Ctrl+S）
    ↓
EditorNode 调用 save_scene()
    ↓
场景保存为 .tscn 文件
    ↓
EditorData 保存编辑器状态
```

#### 多场景编辑流程

```
Scene Tab 1       Scene Tab 2       Scene Tab 3
    (已打开)          (已打开)         (未打开)
    ↓               ↓                ↓
┌─────────┐    ┌─────────┐    ┌──────────┐
│ Node    │    │ Node    │    │ 待加载   │
│ 3D Ed.  │    │ Canvas  │    │          │
│ Active  │    │ Ed.     │    │          │
└────┬────┘    └────┬────┘    └──────────┘
     │              │
     └──────┬───────┘
            │
       EditorData.edited_scene[3]
            │
    ┌───────────────────┐
    │ EditedScene:      │
    │ - root            │ (保存的节点树)
    │ - editor_states   │ (Dock 布局等)
    │ - selection       │ (选择的节点)
    │ - history         │ (编辑历史)
    └───────────────────┘
```

### 4.3 相互通信

```cpp
// EditorData 中的插件管理
EditorPlugin *main_editor = editor_data->get_handling_main_editor(object);
if (main_editor) {
    main_editor->edit(object);  // 通知插件编辑对象
}

// EditorPlugin 中访问编辑器数据
EditorNode *editor = get_undo_redo()->get_version();  // 获取撤销/重做管理器
EditorInterface *interface = get_editor_interface();  // 获取编辑器接口

// EditorNode 中协调数据和插件
editor_data->add_editor_plugin(plugin);
editor_data->set_editor_plugin_states(states);
```

---

## 核心功能流程

### 5.1 编辑器启动流程

```
main() 启动
    ↓
Main::setup() (解析命令行参数)
    ↓
Main::setup2()
    ├─ 初始化所有服务器
    ├─ 创建 DisplayServer（显示窗口）
    └─ 创建 EditorNode
        ↓
    EditorNode::_ready()
        ├─ 初始化 UI 布局
        ├─ 创建所有子节点和 Dock
        ├─ 创建 EditorData
        ├─ 注册所有 EditorPlugin
        └─ 加载项目设置
        ↓
    Main::start()
        ├─ 加载上次打开的场景
        └─ 进入主循环
```

### 5.2 打开场景流程

```
File → Open Scene (或 Ctrl+O)
    ↓
EditorNode::_menu_option(SCENE_OPEN_SCENE)
    ↓
打开文件对话框
    ↓
用户选择 .tscn 文件
    ↓
EditorNode::open_scene_file(path)
    ├─ 创建 EditedScene 结构
    ├─ 加载 .tscn 文件
    ├─ 添加到 EditorData.edited_scene
    ├─ 创建场景标签页
    └─ 设置为当前编辑的场景
        ↓
    EditorNode::_set_current_scene(index)
        ├─ 调用 EditorPlugin.notify_scene_changed(root)
        ├─ 更新所有编辑器插件
        │   └─ Node3DEditorPlugin::_edit(root)
        │   └─ CanvasItemEditorPlugin::_edit(root)
        │   └─ ScriptEditorPlugin::_edit(root)
        └─ 恢复之前的编辑状态（选择、Dock 布局等）
```

### 5.3 保存场景流程

```
File → Save Scene (或 Ctrl+S)
    ↓
EditorNode::_menu_option(SCENE_SAVE_SCENE)
    ↓
EditorNode::save_scene(path)
    ├─ 调用 EditorPlugin._save_external_data()
    │  （保存外部资源）
    ├─ 序列化场景树
    ├─ 保存为 .tscn 文件
    ├─ 保存 EditorData.editor_states 到项目文件
    ├─ 标记场景为已保存
    └─ 更新文件修改时间
        ↓
    通知 EditorPlugin
        └─ 调用 notify_scene_saved(path)
```

### 5.4 撤销/重做流程

```
用户修改场景（如移动节点）
    ↓
EditorNode 通过 EditorUndoRedoManager 记录
    ↓
EditorData 管理 UndoRedo 栈
    │
    ├─ Action: Set Position
    │   ├─ Old Value: (0, 0)
    │   ├─ New Value: (100, 50)
    │   └─ Callback: notify change
    │
    └─ 压入 Undo 栈
        ↓
用户按 Ctrl+Z（撤销）
    ↓
EditorUndoRedoManager::version_changed 信号
    ↓
执行 Undo 操作
    ├─ 恢复: Position = (0, 0)
    └─ 调用回调通知编辑器
        ↓
    所有编辑器组件更新
        └─ 3D 编辑器重新绘制
        └─ 属性检查器更新
        └─ 场景树刷新
```

### 5.5 插件加载流程

```
EditorNode 初始化
    ↓
for each plugin_class in EditorPlugins:
    ├─ 创建插件实例: plugin = EditorPlugins::create(i)
    ├─ 调用 plugin._enable_plugin()
    ├─ 将插件添加到 EditorData: editor_data->add_editor_plugin(plugin)
    ├─ 通知插件场景改变: plugin.notify_scene_changed(current_scene)
    └─ 添加插件 UI 到编辑器
        ├─ 如果有 main_screen: 添加主屏幕按钮
        ├─ 添加 Dock（如果有）
        ├─ 添加工具菜单项
        └─ 添加自定义控制到容器
```

---

## 适用于 rm-editor 分支的分析

### 6.1 核心依赖关系

```
EditorNode 依赖
├── EditorData
│   ├── EditorPlugin（强依赖）
│   ├── EditorUndoRedoManager
│   └── EditorSelectionHistory
├── EditorDockManager
├── EditorMainScreen
├── EditorSceneTabs
├── EditorTitleBar
└── 所有 EditorPlugin 子类（弱依赖）
```

### 6.2 可以移除的组件

如果要创建最小的编辑器或完全移除编辑器，可以考虑移除：

| 组件 | 说明 | 影响 |
|------|-----|------|
| ProjectManager | 项目管理器 | 用户需要命令行指定项目 |
| 所有 EditorPlugin | 所有编辑器插件 | 失去编辑功能 |
| EditorNode | 整个编辑器节点 | 完全移除编辑器 |
| EditorData | 中央数据管理 | 需要自己管理数据 |

### 6.3 可以保留的组件（用于轻量级编辑）

```cpp
// 最小编辑器核心
- EditorUndoRedoManager (撤销/重做)
- EditorSelectionHistory (选择历史)
- EditorPlugin (插件基类)
- EditorInterface (编辑器接口)

// 这允许：
- 第三方开发者开发插件
- 最小化编辑器功能
- 保留扩展性
```

### 6.4 移除建议

#### 立即可删除

```cpp
// 在 rm-editor 分支中：
1. 项目管理器相关代码 (ProjectManager)
2. 所有内置 EditorPlugin 子类
3. 编辑器特定的 UI 组件（Dock、菜单等）
4. 导出和导入系统（EditorExport, EditorImport）
```

#### 条件保留

```cpp
// 如果想保留基本扩展能力：
1. EditorPlugin 基类（用于第三方插件）
2. EditorData（数据管理）
3. EditorUndoRedoManager（撤销/重做）
4. EditorInterface（编辑器接口）
```

#### 必须保留

```cpp
// 游戏运行时也需要的：
1. SceneTree（场景树）
2. Node 系统（节点系统）
3. Input 系统（输入系统）
4. UndoRedo（撤销/重做，可用于游戏）
```

### 6.5 rm-editor 实现方案

#### 方案 A：完全移除编辑器

```
编译标志: TOOLS_DISABLED
- 完全移除 EditorNode
- 完全移除 EditorData
- 完全移除所有 EditorPlugin
- 保留 SceneTree 和核心系统
```

#### 方案 B：轻量级编辑器（推荐）

```
编译标志: LIGHTWEIGHT_EDITOR
- 保留 EditorData 和 EditorPlugin 基类
- 移除所有内置编辑器插件
- 移除编辑器 UI（菜单、Dock 等）
- 允许第三方开发者开发插件
- 支持场景编辑和调试
```

#### 方案 C：脚本编辑器模式

```
编译标志: SCRIPT_EDITOR_ONLY
- 保留 ScriptEditorPlugin
- 保留 EditorData 和 UndoRedo
- 移除 3D/2D 编辑器
- 移除资源导入系统
- 轻量级脚本编辑
```

### 6.6 代码清理建议

**第一步：标识所有编辑器代码**
```cpp
#ifdef TOOLS_ENABLED
    // 编辑器代码
#endif
```

**第二步：检查循环依赖**
```cpp
EditorNode ↔ EditorData ↔ EditorPlugin
// 确保在移除时破断这些循环
```

**第三步：处理回调和信号**
```cpp
// 所有编辑器通知都需要有 null 检查
if (editor_node) {
    editor_node->notify_scene_changed(scene);
}
```

**第四步：编译和测试**
```bash
# 编译最小配置
scons platform=linuxbsd target=editor tools=no

# 测试游戏运行
./godot game.tscn
```

---

## 总结

### 核心要点

1. **EditorNode** 是编辑器的主控制器
   - 管理 UI 布局
   - 协调所有编辑器组件
   - 处理用户交互

2. **EditorData** 是编辑器的中央数据管理系统
   - 管理编辑中的场景
   - 管理编辑器插件
   - 管理撤销/重做系统
   - 管理选择历史

3. **EditorPlugin** 是编辑器扩展的基类
   - 提供虚函数接口供子类实现
   - 支持输入处理和自定义绘制
   - 支持 Dock 和工具菜单
   - 支持对象编辑

4. **三者关系**
   - EditorNode 创建和管理 EditorData
   - EditorData 管理所有 EditorPlugin 实例
   - EditorPlugin 通过 EditorInterface 与 EditorNode 交互

5. **对于 rm-editor 分支**
   - 可以通过条件编译完全移除编辑器
   - 或保留轻量级版本用于脚本编辑
   - 建议保留 EditorPlugin 基类以支持第三方开发

