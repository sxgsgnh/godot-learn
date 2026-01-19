# GUI快捷键系统 - 快速参考指南

**文件**: GUI_SHORTCUT_SYSTEM_QUICK_REFERENCE.md
**版本**: 1.0
**日期**: 2026-01-19

---

## 🎯 快速判断表

### 我应该在哪里处理快捷键?

| 需求 | 处理函数 | 作用域 | 代码位置 |
|------|---------|--------|---------|
| **游戏全局暂停(ESC)** | `_input()` | 全局 | 全局 Node |
| **对话框确认(Enter)** | `_shortcut_input()` | 对话框 | Dialog Node |
| **文本复制(Ctrl+C)** | `gui_input()` | 焦点 | TextEdit |
| **菜单快捷键** | `_shortcut_input()` | 上下文 | Menu Node |
| **焦点控件快捷键** | `gui_input()` | 焦点 | Control |
| **后备快捷键** | `_unhandled_input()` | 全局 | 全局 Node |

---

## 📍 处理函数的优先级

```
_input()                    ⭐⭐⭐ 最高优先级
    ↓
gui_input() (焦点控件)      ⭐⭐⭐
    ↓
_shortcut_input()           ⭐⭐ 快捷键优先级
    ↓
_unhandled_input()          ⭐ 最低优先级
```

---

## 💡 3 种快捷键类型的完整示例

### 类型 1: 全局快捷键 (无上下文)

```gdscript
# 在全局 Node 中,快捷键始终有效
extends Node

func _shortcut_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        # 在任何地方都可以触发
        get_tree().quit()
        get_tree().set_input_as_handled()
```

**特点**: 无上下文, 优先级中等, 全局作用

### 类型 2: 局部快捷键 (有上下文)

```gdscript
# 在 Dialog 中,快捷键仅在对话框焦点时有效
extends Control

class_name MyDialog

func _ready():
    # 设置快捷键上下文为此对话框
    set_shortcut_context(self)

func _shortcut_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept"):
        # 仅在焦点在此对话框内时触发
        _on_accepted()
        get_tree().set_input_as_handled()
```

**特点**: 有上下文, 优先级中等, 局部作用

### 类型 3: 焦点快捷键 (gui_input)

```gdscript
# 在焦点控件中的快捷键,优先级最高
extends TextEdit

func gui_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.is_action_pressed("ui_copy"):
            _copy()
            get_tree().set_input_as_handled()
            return
```

**特点**: 焦点控件, 优先级最高, 极限作用

---

## 🔧 快捷键上下文操作

### 设置上下文

```gdscript
# 方式 1: 指定为自己
dialog.set_shortcut_context(dialog)

# 方式 2: 指定为其他节点
button.set_shortcut_context(button_container)

# 方式 3: 清除上下文
node.set_shortcut_context(null)
```

### 检查上下文

```gdscript
# 获取上下文节点
ctx = control.get_shortcut_context()

# 检查焦点是否在上下文内
if control.is_focus_owner_in_shortcut_context():
    print("焦点在快捷键上下文范围内")
```

### 查询当前焦点

```gdscript
# 获取当前焦点控件
focused = get_viewport().gui_get_focus_owner()

# 检查是否有焦点
if focused:
    print("当前焦点:", focused.name)
else:
    print("没有焦点")
```

---

## ⚡ 常见快捷键处理模式

### 模式 1: 优雅的优先级处理

```gdscript
# 不会互相干扰的三层快捷键处理

# Level 1: 全局输入 (最高)
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("global_quit"):
        quit_game()
        get_tree().set_input_as_handled()

# Level 2: 快捷键 (中等)
func _shortcut_input(event: InputEvent) -> void:
    if event.is_action_pressed("dialog_accept"):
        handle_dialog_accept()
        get_tree().set_input_as_handled()

# Level 3: 未处理输入 (最低)
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("fallback_action"):
        handle_fallback()
        get_tree().set_input_as_handled()
```

### 模式 2: 对话框快捷键

```gdscript
extends ConfirmationDialog

func _ready():
    set_shortcut_context(self)

func _shortcut_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept"):
        confirmed.emit()
        get_tree().set_input_as_handled()

    elif event.is_action_pressed("ui_cancel"):
        cancelled.emit()
        get_tree().set_input_as_handled()
```

### 模式 3: 多窗口焦点快捷键

```gdscript
extends Control

class_name EditorWindow

func _ready():
    set_shortcut_context(self)

func gui_input(event: InputEvent) -> void:
    if event is InputEventKey:
        if event.is_action_pressed("save"):
            _save_file()
            get_tree().set_input_as_handled()
            return

        if event.is_action_pressed("close"):
            close_window()
            get_tree().set_input_as_handled()
            return
```

---

## ❌ 常见陷阱与解决方案

### 陷阱 1: 忘记消费事件

```gdscript
# ❌ 错误: 没有消费事件,会继续传播
func _shortcut_input(event: InputEvent) -> void:
    if event.is_action_pressed("my_action"):
        do_something()
        # ← 忘记 get_tree().set_input_as_handled()

# ✅ 正确
func _shortcut_input(event: InputEvent) -> void:
    if event.is_action_pressed("my_action"):
        do_something()
        get_tree().set_input_as_handled()  # ← 消费事件
```

### 陷阱 2: 没有设置上下文

```gdscript
# ❌ 错误: 没有设置上下文,快捷键全局有效
extends Control

func _shortcut_input(event: InputEvent) -> void:
    if event.is_action_pressed("dialog_action"):
        # ← 这个会在整个游戏中都触发!
        do_something()

# ✅ 正确
extends Control

func _ready():
    set_shortcut_context(self)  # ← 限制范围

func _shortcut_input(event: InputEvent) -> void:
    if event.is_action_pressed("dialog_action"):
        # ← 现在仅在此 Node 有焦点时触发
        do_something()
        get_tree().set_input_as_handled()
```

### 陷阱 3: 快捷键冲突

```gdscript
# ❌ 错误: 多个地方处理相同快捷键
# 全局处理
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept"):
        global_handle()
        get_tree().set_input_as_handled()

# 快捷键处理
func _shortcut_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept"):
        # ← 永远不会执行,因为 _input 已消费
        shortcut_handle()
        get_tree().set_input_as_handled()

# ✅ 正确: 使用不同的动作
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("global_accept"):
        global_handle()
        get_tree().set_input_as_handled()

func _shortcut_input(event: InputEvent) -> void:
    if event.is_action_pressed("dialog_accept"):
        shortcut_handle()
        get_tree().set_input_as_handled()
```

### 陷阱 4: 上下文不匹配

```gdscript
# ❌ 错误: 焦点和上下文不匹配
dialog.set_shortcut_context(dialog)

# 如果焦点不在 dialog 内,快捷键不会触发
# 即使 dialog 可见!

# ✅ 正确: 显式设置焦点
dialog.show()
dialog.first_button.grab_focus()  # ← 确保焦点在对话框内
```

---

## 🚀 实用代码片段

### 片段 1: 安全的快捷键检查

```gdscript
func safe_shortcut_input(event: InputEvent) -> void:
    # 检查是否是快捷键事件
    if not event is InputEventKey:
        return

    if not event.pressed:  # 仅处理按下事件
        return

    # 检查是否已被消费
    if get_tree().is_input_handled():
        return

    # 现在处理快捷键
    if event.is_action_pressed("my_action"):
        do_something()
        get_tree().set_input_as_handled()
```

### 片段 2: 快捷键上下文管理器

```gdscript
# 集中管理快捷键上下文
class_name ShortcutManager

static var active_dialog: Control = null

static func set_active_dialog(dialog: Control) -> void:
    # 清除上一个对话框的上下文
    if active_dialog:
        active_dialog.set_shortcut_context(null)

    # 设置新对话框的上下文
    if dialog:
        dialog.set_shortcut_context(dialog)
        dialog.grab_focus()

    active_dialog = dialog
```

### 片段 3: 全局快捷键管理器

```gdscript
# 全局快捷键处理器
extends Node

func _shortcut_input(event: InputEvent) -> void:
    # 处理游戏全局快捷键

    if event.is_action_pressed("game_pause"):
        get_tree().paused = !get_tree().paused
        get_tree().set_input_as_handled()

    elif event.is_action_pressed("quicksave"):
        save_game()
        get_tree().set_input_as_handled()

    elif event.is_action_pressed("quickload"):
        load_game()
        get_tree().set_input_as_handled()
```

---

## 📊 快捷键事件流决策树

```
快捷键事件产生
    ↓
[检查优先级 1: _input()]
    ├─ 是否消费? → 是: 结束
    └─ 否: 继续
    ↓
[检查优先级 2: gui_input(焦点)]
    ├─ 是否有焦点? → 否: 跳过
    ├─ 是否消费? → 是: 结束
    └─ 否: 继续
    ↓
[检查优先级 3: _shortcut_input()]
    ├─ 是否对应动作? → 否: 跳过
    ├─ 是否有上下文? → 是: 检查焦点是否在范围内
    ├─ 是否消费? → 是: 结束
    └─ 否: 继续
    ↓
[检查优先级 4: _unhandled_input()]
    └─ 最后尝试处理

结果: 事件已处理或未处理
```

---

## 🎓 学习路径

### 第 1 天: 基础
- [ ] 理解快捷键与动作的区别
- [ ] 学会设置快捷键上下文
- [ ] 实现简单的对话框快捷键

### 第 2 天: 进阶
- [ ] 理解三层优先级
- [ ] 学会处理优先级冲突
- [ ] 实现多窗口快捷键系统

### 第 3 天: 高级
- [ ] 深入研究源代码
- [ ] 设计自己的快捷键系统
- [ ] 优化快捷键性能

---

## 📚 相关代码位置

| 功能 | 位置 |
|------|------|
| InputMap 定义 | core/input/input_map.h |
| 快捷键匹配 | core/input/input_map.cpp:event_is_action() |
| Control 快捷键 | scene/gui/control.h/cpp |
| 快捷键上下文 | scene/gui/control.cpp:2014-2040 |
| SceneTree 处理 | scene/main/scene_tree.cpp:_call_input_pause() |
| Viewport 处理 | scene/main/viewport.cpp |
| BaseButton 快捷键 | scene/gui/base_button.cpp:_shortcut_input() |

---

**最后更新**: 2026-01-19
**维护者**: Godot 快捷键系统分析
**许可**: MIT
