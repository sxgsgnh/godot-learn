# Godot主题系统快速参考

## 快速查询指南

---

## 第1章 - 核心概念速查

### 1.1 主题数据类型

| 数据类型 | C++枚举 | 用途 | 示例 |
|---------|--------|------|------|
| 颜色 | DATA_TYPE_COLOR | UI颜色 | font_color, bg_color |
| 常量 | DATA_TYPE_CONSTANT | 整数值 | h_separation, margin |
| 字体 | DATA_TYPE_FONT | 文本渲染字体 | 无名默认字体 |
| 字体大小 | DATA_TYPE_FONT_SIZE | 字体点数 | 24, 32等 |
| 图标 | DATA_TYPE_ICON | 纹理资源 | icon, icon_pressed |
| 样式框 | DATA_TYPE_STYLEBOX | 背景/边框 | normal, hover, pressed |

### 1.2 主题查询优先级

```
override (最高)
    ↓
本节点主题
    ↓
父节点主题
    ↓
祖父节点主题
    ↓
全局project_theme
    ↓
全局default_theme
    ↓
ThemeDB::fallback_* (最低)
```

### 1.3 主要类关系

```
Theme ─────────────────┐
(样式数据容器)          │
                      ├─→ ThemeDB ─→ ThemeContext
                      │  (全局管理)   (上下文)
ThemeOwner ───────────┘
(应用到节点)
  │
  └─→ Control/Window
      (GUI组件)
```

---

## 第2章 - 常用API速查表

### 2.1 Theme资源操作

```cpp
// 创建和基本操作
Ref<Theme> theme = Ref<Theme>(memnew(Theme));
theme->set_default_font(font);
theme->set_default_font_size(20);

// 设置主题项目
theme->set_color(name, type, color);
theme->set_icon(name, type, texture);
theme->set_font(name, type, font);
theme->set_font_size(name, type, size);
theme->set_stylebox(name, type, stylebox);
theme->set_constant(name, type, value);

// 查询主题项目
Color c = theme->get_color(name, type);
Ref<Texture2D> icon = theme->get_icon(name, type);
bool has = theme->has_color(name, type);

// 列表操作
theme->get_type_list(list);  // 所有类型
theme->get_icon_list(type, list);  // 某类型的所有图标

// 清除和合并
theme->clear();
theme->merge_with(other_theme);

// 类型变体
theme->set_type_variation("Button_success", "Button");
theme->get_type_variation_base("Button_success");
```

### 2.2 Control的主题方法

```cpp
// 设置主题
control->set_theme(theme);
Ref<Theme> t = control->get_theme();

// 设置类型变体
control->set_theme_type_variation("success");

// 查询主题项目
Color color = control->get_theme_color("font_color");
Ref<Texture2D> icon = control->get_theme_icon("icon");
Ref<Font> font = control->get_theme_font("font");
int size = control->get_theme_font_size("font_size");
Ref<StyleBox> style = control->get_theme_stylebox("normal");
int value = control->get_theme_constant("h_separation");

// 主题所有权
control->set_theme_owner_node(node);
Node *owner = control->get_theme_owner_node();
bool has = control->has_theme_owner_node();

// 监听主题变更
control->theme_changed.connect(_on_theme_changed);
```

### 2.3 ThemeDB全局操作

```cpp
// 获取全局主题
Ref<Theme> default_t = ThemeDB::get_singleton()->get_default_theme();
Ref<Theme> project_t = ThemeDB::get_singleton()->get_project_theme();

// 设置全局主题
ThemeDB::get_singleton()->set_project_theme(new_theme);

// Fallback值
ThemeDB::get_singleton()->set_fallback_font(font);
ThemeDB::get_singleton()->set_fallback_font_size(size);
ThemeDB::get_singleton()->set_fallback_icon(icon);
ThemeDB::get_singleton()->set_fallback_stylebox(stylebox);

// 获取fallback值
Ref<Font> f = ThemeDB::get_singleton()->get_fallback_font();
int s = ThemeDB::get_singleton()->get_fallback_font_size();
```

---

## 第3章 - 常见场景的决策树

### 3.1 "我想改变整个游戏的主题"

```
decision: 编辑器中还是运行时?
├─→ 编辑器中配置
│   └─→ Project Settings → gui/theme/custom
│       │ 选择.tres主题文件
│       └─→ 自动加载为project_theme
│
└─→ 运行时切换
    └─→ ThemeDB::get_singleton()->set_project_theme(new_theme)
        └─→ 所有UI自动更新
```

### 3.2 "某个Panel需要特殊样式"

```
decision: 影响范围?
├─→ 只有这个Panel
│   └─→ panel.theme = special_theme
│       └─→ 只有panel及其子控件受影响
│
└─→ Panel及其所有子控件
    └─→ 同上（自动继承到子控件）

特殊情况: 子控件要使用不同的主题
    └─→ child.theme = different_theme
        └─→ child断开与parent的主题继承
```

### 3.3 "我想为Button创建多个样式"

```
选项1: 使用类型变体
├─→ theme->set_type_variation("Button_success", "Button")
├─→ theme->set_type_variation("Button_danger", "Button")
└─→ button.theme_type_variation = "success"  # 选择变体

选项2: 创建新的主题类型（不推荐）
├─→ theme->set_color("font_color", "SuccessButton", ...)
└─→ button.get_theme_color("font_color", "SuccessButton")

推荐: 选项1更灵活，支持继承
```

### 3.4 "主题改变后控件没有更新"

```
问题诊断:
├─→ Control在树中吗?
│   ├─→ No → control.add_child(); await get_tree().process_frame
│   └─→ Yes → 继续检查
│
├─→ 是否连接了theme_changed信号?
│   ├─→ No → control.theme_changed.connect(...)
│   └─→ Yes → 继续检查
│
└─→ 是否修改了theme内容，而不是替换theme本身?
    ├─→ Yes → 正常，theme.changed会自动传播
    └─→ No → 检查是否在Control外部修改主题
        └─→ theme内部会调用_emit_theme_changed()
        └─→ 此信号会通知所有使用此主题的control
```

---

## 第4章 - 性能优化建议

### 4.1 缓存系统

```
✓ Theme查询是缓存的
  - Control内部维护theme_icon_cache等
  - NOTIFICATION_THEME_CHANGED时清除
  - 自动重建

✓ Batch操作时禁用通知
  theme->_freeze_change_propagation();
  for (...) theme->set_color(...);  // 不发出changed信号
  theme->_unfreeze_and_propagate_changes();  // 一次性发出

✗ 避免频繁修改主题
  - 每次修改都会清除所有使用此主题的control的缓存
  - 应该在启动时设置好，而不是每帧修改
```

### 4.2 主题查询的性能影响

| 操作 | 成本 | 优化建议 |
|-----|------|---------|
| get_theme_color() | 低(缓存) | 正常使用 |
| 第一次查询某项目 | 中(哈希表查找) | 在_ready()或theme_changed中 |
| 修改主题项目 | 高(通知所有observers) | 批量操作时冻结 |
| 替换整个主题 | 高(清除所有缓存) | 在启动时执行 |

---

## 第5章 - 代码示例集合

### 5.1 创建和应用自定义主题

```cpp
// GDScript示例
func _ready():
    # 创建主题
    var theme = Theme.new()
    theme.default_font_size = 24

    # 添加Button样式
    theme.set_color("font_color", "Button", Color.WHITE)
    theme.set_color("font_focus_color", "Button", Color.YELLOW)
    theme.set_color("font_pressed_color", "Button", Color.GRAY)

    # 创建success按钮变体
    theme.set_type_variation("Button_success", "Button")
    theme.set_color("font_color", "Button_success", Color.GREEN)

    # 应用到根节点
    $VBoxContainer.theme = theme

    # 使用按钮变体
    $VBoxContainer/SuccessButton.theme_type_variation = "success"
```

### 5.2 在运行时切换主题

```cpp
var themes = {
    "light": preload("res://themes/light.tres"),
    "dark": preload("res://themes/dark.tres"),
}

func set_theme(theme_name: String):
    if theme_name in themes:
        ThemeDB.get_singleton().set_project_theme(themes[theme_name])
        # 整个UI在下一帧更新

func cycle_theme():
    var current = ThemeDB.get_singleton().get_project_theme()
    if current == themes["light"]:
        set_theme("dark")
    else:
        set_theme("light")
```

### 5.3 监听主题变更

```cpp
func _ready():
    theme_changed.connect(_on_theme_updated)

func _on_theme_updated():
    # 主题改变时调用
    # 重新获取所有可能变化的样式
    var bg = get_theme_stylebox("panel")
    var color = get_theme_color("font_color")
    var font = get_theme_font("font")

    # 应用到自定义绘制或特殊处理
    update()  # 触发_draw()重绘
```

### 5.4 合并多个主题

```cpp
# 场景1: 合并override主题
var base = preload("res://themes/base.tres")
var game_mode = preload("res://themes/game_mode_special.tres")

# 创建合并后的主题
var merged = base.duplicate()
merged.merge_with(game_mode)

get_tree().root.theme = merged
```

---

## 第6章 - 常见问题解决

### 问题1: "设置了theme但没有生效"

**可能原因**:
```
□ Control不在场景树中
  ✓ 解决: 先add_child，再等一帧

□ theme设置为null
  ✓ 解决: 确保theme不是null

□ 在_init()中设置，而不是_ready()
  ✓ 解决: 移到_ready()或_enter_tree()

□ 期望改变全局主题但只改变了局部
  ✓ 解决: ThemeDB.set_project_theme()
```

### 问题2: "性能下降，主题查询很慢"

**可能原因**:
```
□ 频繁创建和销毁主题
  ✓ 解决: 预加载主题资源

□ 每帧修改主题项目
  ✓ 解决: 使用_freeze_change_propagation()

□ 主题层级太深
  ✓ 解决: 在顶层设置主题，不要到处设置

□ 忽视缓存，频繁get_theme_*
  ✓ 解决: 在_ready()或theme_changed中缓存值
```

### 问题3: "子控件不继承父节点的主题"

**可能原因**:
```
□ 子控件设置了自己的theme（即使是null）
  ✓ 解决: 不要显式设置，直接继承

□ 父节点不是Control（例如Node2D）
  ✓ 解决: 只有Control和Window支持主题

□ 子控件在父节点设置主题之前就进入树
  ✓ 解决: 设置主题后重新进入树，或调用propagate_theme_changed
```

---

## 第7章 - 类型变体完整示例

### 7.1 定义多个按钮样式

```cpp
func create_button_theme():
    var theme = Theme.new()

    # 基础Button样式
    theme.set_color("font_color", "Button", Color.WHITE)
    theme.set_stylebox("normal", "Button", btn_normal_style)
    theme.set_stylebox("hover", "Button", btn_hover_style)
    theme.set_stylebox("pressed", "Button", btn_pressed_style)

    # Success按钮变体 (绿色)
    theme.set_type_variation("Button_success", "Button")
    theme.set_color("font_color", "Button_success", Color.GREEN)
    theme.set_stylebox("normal", "Button_success", btn_success_normal)

    # Danger按钮变体 (红色)
    theme.set_type_variation("Button_danger", "Button")
    theme.set_color("font_color", "Button_danger", Color.RED)
    theme.set_stylebox("normal", "Button_danger", btn_danger_normal)

    # Warning按钮变体 (黄色)
    theme.set_type_variation("Button_warning", "Button")
    theme.set_color("font_color", "Button_warning", Color.YELLOW)
    theme.set_stylebox("normal", "Button_warning", btn_warning_normal)

    return theme

func _ready():
    var theme = create_button_theme()
    $VBoxContainer.theme = theme

    # 使用变体
    $VBoxContainer/NormalButton.theme_type_variation = ""        # 默认
    $VBoxContainer/SuccessButton.theme_type_variation = "success"
    $VBoxContainer/DangerButton.theme_type_variation = "danger"
    $VBoxContainer/WarningButton.theme_type_variation = "warning"
```

---

## 第8章 - 编辑器特性

### 8.1 在Inspector中编辑主题

```
选中Control节点 → Theme属性 → 创建新Theme或选择现有

可以直接在Inspector中:
├─ 添加颜色: Button/colors/font_color
├─ 添加图标: Button/icons/icon
├─ 添加样式框: Button/styles/normal
├─ 添加字体: Label/fonts/font
├─ 添加常量: Button/constants/h_separation
└─ 定义变体: Button/base_type = Button_success
```

### 8.2 ThemeEditor插件

```
编辑器菜单 → Editor → Theme Editor
├─ 浏览所有内置主题
├─ 预览主题项目
├─ 编辑颜色、字体等
└─ 导出为主题资源
```

---

## 第9章 - 调试技巧

### 9.1 打印主题信息

```cpp
func debug_theme(control: Control):
    print("Control: %s" % control.name)
    print("Theme: %s" % control.get_theme())
    print("Owner Node: %s" % control.get_theme_owner_node())

    # 打印某个颜色的查询过程
    var color = control.get_theme_color("font_color")
    print("font_color = %s" % color)

    # 打印所有类型
    var types = []
    control.get_theme().get_type_list(types)
    print("Available types: %s" % types)
```

### 9.2 追踪主题变更

```cpp
func _ready():
    # 连接theme_changed信号
    theme_changed.connect(_on_theme_changed)

    # 如果使用全局主题变更
    ThemeDB.get_singleton().fallback_changed.connect(
        _on_global_theme_changed)

func _on_theme_changed():
    print("Theme changed at: %s, frame: %d" % [
        get_stack(false)[0].function,
        Engine.get_physics_frames()
    ])

func _on_global_theme_changed():
    print("Global fallback theme changed")
```

---

## 快速参考卡片

### 最常用的5个操作

```gdscript
# 1. 创建和应用主题
var theme = Theme.new()
node.theme = theme

# 2. 查询主题项目
var color = get_theme_color("font_color")

# 3. 修改主题项目
theme.set_color("font_color", "Button", Color.WHITE)

# 4. 切换全局主题
ThemeDB.get_singleton().set_project_theme(new_theme)

# 5. 监听变更
theme_changed.connect(_on_changed)
```

### 主题查询链 (从快到慢)

```
1. Override (本地缓存) ← 最快
2. 本节点主题缓存
3. 父节点主题缓存
4. ...更多祖先...
5. 全局主题查询
6. Fallback值 ← 最慢
```

---

## 附录：文件位置速查

| 功能 | 源文件 |
|-----|-------|
| Theme核心 | scene/resources/theme.h/cpp |
| 全局管理 | scene/theme/theme_db.h/cpp |
| 应用系统 | scene/theme/theme_owner.h/cpp |
| Control集成 | scene/gui/control.h/cpp |
| 默认主题 | scene/theme/default_theme.cpp |
| Editor主题 | editor/themes/theme_*.cpp |

