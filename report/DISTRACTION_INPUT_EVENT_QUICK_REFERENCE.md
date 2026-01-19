# 分心输入事件响应范围 - 快速参考

**文件**: DISTRACTION_INPUT_EVENT_QUICK_REFERENCE.md
**版本**: 1.0
**日期**: 2026-01-19

---

## 🎯 5分钟速查

### 全局响应范围 (Viewport 级别)

| 操作 | 方式 | 作用域 | 代码 |
|------|------|--------|------|
| **焦点转移** | grab_focus() | 全 Viewport | `button.grab_focus()` |
| **焦点查询** | has_focus() | 跨 Scene Tree | `if control.has_focus():` |
| **焦点释放** | release_focus() | 清空焦点 | `control.release_focus()` |
| **禁用输入** | gui_disable_input | 完全禁用 | `viewport.gui_disable_input = true` |

### 局部响应范围 (Control 级别)

| 操作 | 方式 | 作用域 | 代码 |
|------|------|--------|------|
| **事件处理** | gui_input() | 当前+向上 | `override gui_input(event)` |
| **事件消费** | set_input_as_handled() | 停止传播 | `get_tree().set_input_as_handled()` |
| **焦点模式** | set_focus_mode() | 当前控件 | `button.focus_mode = FOCUS_ALL` |
| **焦点行为** | set_focus_behavior() | 控件+子树 | `control.set_focus_behavior_recursive()` |

---

## 🔄 事件流向速查表

### 键盘输入流向

```
键盘按下
  ↓
Viewport 捕获
  ↓
[优先处理焦点控件] ← focused_control.gui_input()
  ├─ 是否消费? → set_input_as_handled()
  ├─ 是: ✓ 停止 (其他不处理)
  └─ 否: ↓ 继续传播
  ↓
[父节点处理] ← parent.gui_input()
  ├─ 是否消费? → set_input_as_handled()
  └─ 否: ↓ 继续向上
  ↓
[根节点/脚本处理] ← _input()
  └─ 结束
```

### 鼠标输入流向

```
鼠标点击
  ↓
Viewport hit test (从顶层开始)
  ├─ 检查 mouse_filter 设置
  └─ 返回最底层命中的控件
  ↓
[鼠标点击时]
  ├─ 自动 grab_focus() (若 FOCUS_CLICK/ALL)
  └─ 调用 gui_input()
  ↓
[鼠标释放时]
  └─ 返回 mouse_focus (不一定是最底层)
```

### 焦点转移流向

```
grab_focus() 调用
  ↓
保存旧焦点 old_focus
  ↓
[发送 old_focus.focus_exited 信号]
  ├─ 连接的槽立即执行
  └─ 可在此调用 grab_focus() 转移到其他控件
  ↓
[设置新焦点 new_focus]
  └─ gui.focused_control = new_focus
  ↓
[发送 new_focus.focus_entered 信号]
  └─ 连接的槽立即执行
  ↓
[下一帧键盘输入优先到 new_focus]
```

---

## 📋 常见操作速查

### 焦点操作

```gdscript
# ✅ 转移焦点
button.grab_focus()

# ✅ 隐藏焦点框 (仍有焦点，只是不显示)
button.grab_focus(true)

# ✅ 检查是否有焦点
if button.has_focus():
    print("我有焦点")

# ✅ 释放焦点
button.release_focus()

# ✅ 检查焦点模式
if button.focus_mode == Control.FOCUS_ALL:
    print("支持 TAB 导航")
```

### 事件处理

```gdscript
# ✅ 处理 GUI 输入
func gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        print("收到鼠标点击")
        get_tree().set_input_as_handled()  # 消费事件
        return
    # 没有消费的事件继续传播

# ✅ 处理全局输入
func _input(event: InputEvent) -> void:
    if Input.is_action_pressed("ui_accept"):
        print("接受动作")
        get_tree().set_input_as_handled()

# ✅ 等待焦点变化
func _ready():
    focus_entered.connect(_on_focus_entered)
    focus_exited.connect(_on_focus_exited)
```

### 焦点模式设置

```gdscript
# 对话框按钮 (支持 TAB 导航)
dialog_button.focus_mode = Control.FOCUS_ALL

# 工具栏按钮 (仅鼠标点击)
toolbar_button.focus_mode = Control.FOCUS_CLICK

# 标签/装饰 (不参与焦点)
label.focus_mode = Control.FOCUS_NONE

# 禁用整棵子树的焦点
container.set_focus_behavior_recursive(Control.FOCUS_BEHAVIOR_DISABLED)
```

---

## ⚡ 优先级速查

### 事件处理优先级 (从高到低)

1. **焦点控件的 gui_input()**
   - 如果消费 → 停止
   - 如果不消费 → 传给父节点

2. **父节点的 gui_input()**
   - 沿树向上递归

3. **根节点的 _input()**
   - 脚本层全局处理

### 焦点获取优先级 (从高到低)

1. **FOCUS_ALL** (可通过任何输入获得焦点)
2. **FOCUS_CLICK** (仅鼠标点击获得焦点)
3. **FOCUS_NONE** (不参与焦点系统)

### 焦点限制优先级 (从高到低)

1. **FOCUS_BEHAVIOR_DISABLED** → 无法获得焦点
2. **is_visible() == false** → 自动失焦
3. **is_disabled() == true** → 自动失焦
4. **focus_mode == FOCUS_NONE** → 无法获得焦点

---

## 🔒 焦点限制参考

### 防止焦点进入

```gdscript
# ✅ 方法 1: 设置焦点行为
control.set_focus_behavior_recursive(Control.FOCUS_BEHAVIOR_DISABLED)

# ✅ 方法 2: 设置焦点模式
control.focus_mode = Control.FOCUS_NONE

# ✅ 方法 3: 隐藏或禁用
control.hide()
control.set_disabled(true)
```

### 防止事件传播

```gdscript
func gui_input(event: InputEvent) -> void:
    if should_consume_event(event):
        # ... 处理事件 ...
        get_tree().set_input_as_handled()  # ← 停止传播
        return
    # 不消费则继续传播

def set_mouse_filter(filter):
    # MOUSE_FILTER_STOP: 接收鼠标事件,阻止穿透
    # MOUSE_FILTER_PASS: 接收鼠标事件,允许穿透到下层
    # MOUSE_FILTER_IGNORE: 完全忽略鼠标事件
    pass
```

---

## 🚨 常见陷阱

### ❌ 陷阱 1: 焦点循环

```gdscript
# 不要这样做!
func _on_focus_entered():
    grab_focus()  # ← 会再次触发 focus_entered

# ✅ 应该这样做
func _on_focus_entered():
    _on_gained_focus()  # 执行初始化,不再 grab_focus
```

### ❌ 陷阱 2: 假设焦点状态

```gdscript
# 不要这样做!
grab_focus()
print(has_focus())  # ← 可能是 false (如果 grab_focus 被阻止)

# ✅ 应该这样做
if grab_focus():  # 返回是否成功
    print("成功获得焦点")
```

### ❌ 陷阱 3: 过度消费

```gdscript
# 不要这样做!
func gui_input(event: InputEvent) -> void:
    get_tree().set_input_as_handled()  # ← 过度消费
    # 所有事件都被阻止

# ✅ 应该这样做
func gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        # 只消费相关事件
        get_tree().set_input_as_handled()
        return
    # 其他事件不消费
```

### ❌ 陷阱 4: 混合焦点模式

```gdscript
# 不要这样做!
button1.focus_mode = Control.FOCUS_ALL
button2.focus_mode = Control.FOCUS_NONE
button3.focus_mode = Control.FOCUS_CLICK
# ← TAB 导航会很混乱

# ✅ 应该这样做
# 在单个场景中保持焦点模式一致
button1.focus_mode = Control.FOCUS_ALL
button2.focus_mode = Control.FOCUS_ALL
button3.focus_mode = Control.FOCUS_ALL
```

---

## 📊 全局 vs 局部决策表

选择何时使用全局 vs 局部:

| 需求 | 全局方式 | 局部方式 | 优先使用 |
|------|--------|--------|--------|
| **转移焦点** | grab_focus() | - | 全局 |
| **查询焦点** | has_focus() | - | 全局 |
| **处理键盘** | 优先焦点 | gui_input() | 全局优先 |
| **处理鼠标** | hit test | gui_input() | 全局+局部 |
| **停止事件** | (无) | set_input_as_handled() | 局部 |
| **UI 控制** | gui_disable_input | mouse_filter | 全局限制 |
| **焦点限制** | (无直接) | focus_behavior | 局部 |

---

## 🎓 学习路径

### 初级 (10 分钟)
- [ ] 读完 "5分钟速查" 部分
- [ ] 理解全局 vs 局部的区别
- [ ] 学会 grab_focus() 的用法

### 中级 (30 分钟)
- [ ] 阅读 "事件流向速查表"
- [ ] 学习 gui_input() 和事件消费
- [ ] 理解焦点模式和焦点行为

### 高级 (1 小时)
- [ ] 读完整个快速参考
- [ ] 参考详细分析文档 DISTRACTION_INPUT_EVENT_ANALYSIS.md
- [ ] 实现自定义焦点管理系统

---

## 📍 代码位置速查

| 功能 | 代码位置 |
|------|--------|
| Control 焦点方法 | scene/gui/control.cpp:2348-2390 |
| Viewport 焦点管理 | scene/main/viewport.cpp:2699-2760 |
| GUI 事件分发 | scene/main/viewport.cpp:2030-2200 |
| 焦点转移信号 | scene/gui/control.cpp:3940-3960 |
| Hit test 算法 | scene/main/viewport.cpp:_gui_input_event() |

---

## 📚 相关文档

- **详细分析**: DISTRACTION_INPUT_EVENT_ANALYSIS.md (1075 行)
- **架构文档**: 见同目录的其他分析文件

---

**最后更新**: 2026-01-19
**维护者**: Godot 引擎分析
**许可**: MIT
