# 分心输入事件响应范围分析报告

**创建日期**: 2026-01-19
**分析对象**: Godot Engine 焦点系统和输入事件处理
**报告版本**: 1.0

---

## 目录

1. [概述](#概述)
2. [分心输入事件定义](#分心输入事件定义)
3. [全局响应范围](#全局响应范围)
4. [局部响应范围](#局部响应范围)
5. [事件流向与截断](#事件流向与截断)
6. [响应优先级](#响应优先级)
7. [焦点转移机制](#焦点转移机制)
8. [实现架构](#实现架构)
9. [最佳实践](#最佳实践)

---

## 概述

### 什么是分心输入事件?

分心输入事件（Distraction Input Event）是指在GUI焦点系统中，当一个控件失去焦点或被其他控件覆盖时，发生的输入事件。这些事件可能来自：

1. **焦点转移**: 从一个控件转移到另一个控件
2. **焦点丧失**: 从一个控件丧失所有焦点
3. **外部输入**: 鼠标点击、键盘输入等导致焦点改变
4. **系统事件**: 窗口失活、视口变化等

### 核心特性

| 特性 | 说明 |
|------|------|
| **全局性** | 作用于整个 Viewport 或 Scene Tree |
| **局部性** | 作用于单个 Control 或其子树 |
| **优先级** | 不同事件类型有不同优先级 |
| **可拦截** | 某些事件可被消费和拦截 |
| **级联传播** | 可沿着 Scene Tree 传播 |

---

## 分心输入事件定义

### 1. 焦点事件

#### focus_entered
```
触发条件:
  - Control 获得键盘焦点
  - has_focus() 从 false 变为 true

作用域:
  - 当前获得焦点的 Control
  - 信号: void focus_entered()

位置: scene/gui/control.cpp:3945
```

**源代码示例**:
```cpp
// 焦点获取时的信号发送
if (data.focus_mode != FOCUS_NONE) {
    emit_signal(SceneStringName(focus_entered));
}
```

#### focus_exited
```
触发条件:
  - Control 失去键盘焦点
  - has_focus() 从 true 变为 false

作用域:
  - 原有焦点的 Control
  - 信号: void focus_exited()

位置: scene/gui/control.cpp:3950
```

### 2. 鼠标事件

#### mouse_entered
```
触发条件:
  - 鼠标进入 Control 的矩形区域
  - 作用于可见且启用的控件

作用域:
  - 当前鼠标悬停的 Control
  - 信号: void mouse_entered()
```

#### mouse_exited
```
触发条件:
  - 鼠标离开 Control 的矩形区域
  - 作用于可见且启用的控件

作用域:
  - 原有鼠标悬停的 Control
  - 信号: void mouse_exited()
```

### 3. 输入事件

#### gui_input
```
触发条件:
  - 任何 GUI 输入事件发生
  - 包括: InputEventMouseButton, InputEventMouseMotion,
           InputEventKey, 输入动作等

作用域:
  - 不同根据事件类型和焦点状态
  - 虚函数: virtual void gui_input(const Ref<InputEvent> &p_gui_input)

位置: scene/gui/control.cpp
```

---

## 全局响应范围

### 1. 全局焦点状态 (Global Focus State)

在 Viewport 级别维护的全局状态：

```cpp
struct GUIData {
    // 全局焦点控件
    Control *focused_control = nullptr;

    // 全局鼠标焦点控件
    Control *mouse_focus = nullptr;

    // 全局滚轮焦点控件
    Control *scroll_focus = nullptr;

    // 上次鼠标位置
    Point2i last_mouse_pos;

    // 提示气泡相关
    Control *tooltip_control = nullptr;
    Timer *tooltip_timer = nullptr;
};
```

**位置**: `scene/main/viewport.h` 中的 `Viewport::GUIData` 结构

### 2. 全局事件分发 (Global Event Distribution)

#### 事件来源

1. **Input 单例** (全局输入管理)
   ```
   位置: core/os/input.cpp
   功能: 捕获硬件输入事件
   ```

2. **InputMap** (动作映射)
   ```
   位置: core/os/input_map.cpp
   功能: 将硬件输入映射到逻辑动作
   ```

3. **Viewport 事件队列**
   ```
   位置: scene/main/viewport.cpp
   功能: 缓存和分发 GUI 事件
   ```

#### 全局分发流程

```
硬件输入事件
    ↓
OS 层捕获 (platform/*/input_handler.cpp)
    ↓
Viewport._process_input() 或 _input()
    ↓
[全局处理层]
    ├─ 检查焦点模式 (FOCUS_NONE/FOCUS_CLICK/FOCUS_ALL)
    ├─ 检查 gui_disable_input 标志
    ├─ 检查视口可见性
    └─ 决定是否进行焦点转移
    ↓
[局部分发]
    ├─ 首先尝试 focused_control
    ├─ 失败则尝试 mouse_focus
    ├─ 继续沿树往上传播
    └─ 最后到达 root node
```

### 3. 全局焦点管理 (Global Focus Management)

#### grab_focus - 全局焦点转移

```cpp
void Control::grab_focus(bool p_hide_focus = false) {
    // 位置: scene/gui/control.cpp:2353

    if (!is_inside_tree()) return;
    if (data.focus_mode == FOCUS_NONE) return;

    // 调用 Viewport 的全局焦点转移
    get_viewport()->_gui_control_grab_focus(this, p_hide_focus);
}
```

**效果**:
- 影响整个 Viewport 的焦点状态
- 触发原焦点控件的 focus_exited 信号
- 触发新焦点控件的 focus_entered 信号
- 可选隐藏焦点指示器

#### release_focus - 全局焦点释放

```cpp
void Control::release_focus() {
    // 位置: scene/gui/control.cpp:2379

    if (!has_focus()) return;

    get_viewport()->gui_release_focus();
}
```

**效果**:
- 清除 Viewport 的焦点状态
- 触发焦点控件的 focus_exited 信号
- 焦点落到根节点

### 4. 全局焦点查询 (Global Focus Query)

```cpp
bool Control::has_focus(bool p_ignore_hidden_focus = false) const {
    // 位置: scene/gui/control.cpp:2348

    if (!is_inside_tree()) return false;

    return get_viewport()->_gui_control_has_focus(this, p_ignore_hidden_focus);
}
```

**查询范围**:
- 跨越整个 Scene Tree
- 可选忽略隐藏焦点状态
- 同步查询全局焦点表

### 5. 全局鼠标追踪 (Global Mouse Tracking)

```cpp
void Control::set_mouse_filter(MouseFilter p_filter) {
    // 位置: scene/gui/control.cpp:2189
    // 可选值:
    //   MOUSE_FILTER_STOP    - 阻止鼠标事件传播
    //   MOUSE_FILTER_PASS    - 允许事件传播到下方
    //   MOUSE_FILTER_IGNORE  - 完全忽略鼠标事件
}
```

**作用**:
- 全局影响该控件及其子树的鼠标事件处理
- 参与 Viewport 级别的 hit test
- 影响鼠标焦点的获取

---

## 局部响应范围

### 1. 局部焦点限制 (Local Focus Scope)

#### FocusBehavior - 焦点行为限制

```cpp
enum FocusBehavior {
    FOCUS_BEHAVIOR_INHERITED = 0,    // 继承父节点设置
    FOCUS_BEHAVIOR_ENABLED = 1,      // 启用焦点
    FOCUS_BEHAVIOR_DISABLED = 2      // 禁用焦点
};
```

**作用范围**:
- 仅影响该控件及其子树
- 不跨越树的其他分支
- 可递归应用到所有后代

**代码位置**: `scene/gui/control.h:168`

#### 焦点模式 - FocusMode

```cpp
enum FocusMode {
    FOCUS_NONE = 0,     // 不参与焦点系统
    FOCUS_CLICK = 1,    // 仅点击时获得焦点
    FOCUS_ALL = 2       // 可通过任何方式获得焦点 (键盘导航)
};
```

**作用范围**:
- 仅影响该控件
- 决定该控件是否可成为焦点目标
- 决定焦点转移时是否考虑该控件

**代码位置**: `scene/gui/control.h:142`

### 2. 局部事件消费 (Local Event Consumption)

#### get_tree_input_handled() - 事件消费

```cpp
bool Node::is_input_handled() const {
    // 位置: scene/main/node.cpp
    return get_tree()->_input_is_handled;
}

void Node::get_tree()->set_input_as_handled() {
    // 位置: scene/main/scene_tree.cpp
    _input_is_handled = true;
}
```

**作用**:
- 标记输入事件已处理
- 停止事件向上传播
- 作用范围仅限当前事件处理链

**消费示例**:
```cpp
void MyControl::gui_input(const Ref<InputEvent> &p_event) {
    if (p_event is InputEventMouseButton) {
        // 处理事件
        get_tree()->set_input_as_handled();  // ← 消费事件
        return;
    }
    // 继续传播
}
```

### 3. 局部事件转发 (Local Event Forwarding)

#### 子控件事件处理链

```
输入事件
    ↓
[焦点控件] gui_input() → 处理或转发
    ↓
[父控件] gui_input() → 处理或转发
    ↓
[根控件] gui_input() → 处理或转发
    ↓
[Scene Tree] _input() → 脚本处理
    ↓
[物理世界] _physics_process() → 物理事件
```

**影响范围**:
- 仅影响单个 Control 及其直系祖先
- 不影响兄弟节点或其他分支
- 可通过 `get_tree()->set_input_as_handled()` 中断传播

### 4. 局部可见性限制 (Local Visibility Constraint)

```cpp
void Control::set_visible(bool p_visible) {
    // 位置: scene/gui/control.cpp:2336

    if (!is_inside_tree() && !p_visible) return;

    // 若当前有焦点且被隐藏，则释放焦点
    if (!p_visible && has_focus()) {
        release_focus();
    }
}
```

**局部效果**:
- 控件隐藏时自动失焦
- 不影响其他控件的焦点
- 可级联触发子控件失焦

### 5. 局部禁用限制 (Local Disabled Constraint)

```cpp
void Control::set_disabled(bool p_disabled) {
    // 位置: scene/gui/control.cpp:2325

    // 若禁用且有焦点，则释放焦点
    if (p_disabled && has_focus()) {
        release_focus();
    }
}
```

**局部效果**:
- 禁用控件时自动失焦
- 不接受任何输入事件
- 鼠标点击直接穿透

---

## 事件流向与截断

### 1. 输入事件的完整流向

#### 焦点输入事件 (Focused Input)

```
硬件输入
    ↓
OS 事件队列
    ↓
Engine._process_frame()
    ↓
Input.flush_frame()  → 生成 InputEvent
    ↓
Viewport._input_and_physics_time()  → 开始处理
    ↓
[FocusedControl 优先处理]
    ├─ has_focus() == true?
    ├─ gui_input() 虚函数调用
    ├─ focus_mode 检查 (FOCUS_NONE/CLICK/ALL)
    ├─ 是否消费事件?
    │   └─ 是: set_input_as_handled() → 停止传播 ✓
    │   └─ 否: 继续传播
    └─ 返回到事件循环

[事件未消费，继续向上传播]
    ↓
[Parent Control]
    ├─ gui_input() 虚函数调用
    ├─ 是否消费?
    │   └─ 是: set_input_as_handled() → 停止 ✓
    │   └─ 否: 继续传播
    └─ 返回

[继续递归向上直到根节点]
    ↓
[Scene Root Node]
    ├─ _input() 虚函数 (Godot 脚本层)
    ├─ 是否消费?
    │   └─ 是: set_input_as_handled() → 停止 ✓
    │   └─ 否: 继续
    └─ 返回

[物理输入处理]
    ↓
[全局 _input() 处理]
    ├─ 处理动作映射
    ├─ 触发信号或回调
    └─ 结束
```

**截断点**:
1. ✓ 焦点控件的 `gui_input()` 返回前调用 `get_tree()->set_input_as_handled()`
2. ✓ 父控件的 `gui_input()` 返回前调用 `get_tree()->set_input_as_handled()`
3. ✓ 任何 Node 的 `_input()` 中调用 `get_tree()->set_input_as_handled()`
4. ✓ 设置 `focus_mode = FOCUS_NONE` 跳过该控件
5. ✓ 设置 `mouse_filter = MOUSE_FILTER_IGNORE` 跳过鼠标事件

### 2. 焦点转移的完整流向

#### grab_focus() 被调用时

```
Control.grab_focus()
    ↓
get_viewport()->_gui_control_grab_focus(this, p_hide_focus)
    ↓
[Viewport 级别]
    ├─ 检查输入是否禁用: gui_disable_input
    │   └─ 是: 终止操作
    ├─ 获取当前焦点控件: gui.focused_control
    ├─ 若已有焦点且非同一控件:
    │   ├─ 调用 old_focus->gui_focus_changed(false)
    │   ├─ 发送信号: old_focus.focus_exited()
    │   └─ 清空 gui.focused_control
    ├─ 设置新焦点: gui.focused_control = this
    ├─ 调用 this->gui_focus_changed(true)
    ├─ 发送信号: this.focus_entered()
    └─ 更新 UI (焦点框等)

[焦点转移完成]
    ↓
[焦点控件现在接收优先级最高的输入事件]
    └─ 下一个 gui_input() 调用将首先到达新焦点控件
```

**可被拦截的点**:
1. ✓ 设置 `focus_mode = FOCUS_NONE` 防止 grab_focus()
2. ✓ 在 `focus_entered` 信号处理中 `release_focus()`
3. ✓ 设置 `FocusBehavior::DISABLED` 防止焦点进入

### 3. 鼠标事件流向

#### 鼠标点击产生的焦点转移

```
InputEventMouseButton (LMB)
    ↓
Viewport._gui_input()
    ↓
[Hit Test - 查找鼠标下的控件]
    ├─ 从顶层窗口开始
    ├─ 递归检查: Control.get_local_mouse_position().inside(rect)
    ├─ 检查 mouse_filter 设置
    │   ├─ MOUSE_FILTER_STOP: 停止 hit test
    │   ├─ MOUSE_FILTER_PASS: 继续查找下一层
    │   └─ MOUSE_FILTER_IGNORE: 直接跳过此控件
    └─ 返回最底层的相交控件

[确定目标控件]
    ↓
[若按键被按下 (pressed == true)]
    ├─ gui.mouse_focus = target_control
    ├─ 检查是否是 FOCUS_CLICK 或 FOCUS_ALL 模式
    ├─ 若是: target_control.grab_focus()
    │   └─ 可能触发焦点转移
    └─ 调用 target_control.gui_input(event)

[若按键被释放 (pressed == false)]
    ├─ 调用 mouse_focus.gui_input(event)
    ├─ 清空 mouse_focus = nullptr
    └─ 检查鼠标是否离开控件
        └─ 若离开: 发送 mouse_exited 信号

[事件处理结束]
    └─ 返回是否被消费 (set_input_as_handled 是否被调用)
```

**截断点**:
1. ✓ 设置 `mouse_filter = MOUSE_FILTER_IGNORE` 使事件穿透
2. ✓ 设置 `focus_mode = FOCUS_NONE` 防止焦点转移
3. ✓ 在 `gui_input()` 中调用 `get_tree()->set_input_as_handled()` 消费事件
4. ✓ 父控件处理事件，子控件不会收到

---

## 响应优先级

### 1. 事件处理优先级矩阵

| 事件类型 | 优先级顺序 | 说明 |
|---------|----------|------|
| **焦点输入** | 1. focused_control | 焦点控件优先获得键盘事件 |
| | 2. parents of focused | 沿树向上传播 |
| | 3. _input() handlers | 全局输入处理器 |
| **鼠标输入** | 1. mouse_focus | 鼠标按下时的控件 |
| | 2. mouse_hovered | 鼠标悬停的控件 |
| | 3. hit_test_result | 鼠标坐标下的最顶层控件 |
| | 4. parents | 沿树向上 |
| **焦点转移** | 1. FOCUS_ALL | 高优先级焦点 |
| | 2. FOCUS_CLICK | 中优先级焦点 |
| | 3. FOCUS_NONE | 不参与焦点 |
| **滚轮** | 1. scroll_focus | 专门的滚轮焦点控件 |
| | 2. mouse_focus | 鼠标焦点控件 |
| | 3. focused_control | 键盘焦点控件 |

### 2. 焦点模式的优先级

```cpp
// 优先级从高到低

FOCUS_ALL      // 优先级: ⭐⭐⭐ (最高)
  ├─ 响应键盘导航 (TAB/Shift+TAB)
  ├─ 可通过任何输入获得焦点
  └─ 响应所有焦点事件

FOCUS_CLICK    // 优先级: ⭐⭐ (中等)
  ├─ 仅响应鼠标/触摸点击
  ├─ 不响应键盘导航
  └─ 不参与 TAB 顺序

FOCUS_NONE     // 优先级: ⭐ (最低)
  ├─ 不能获得焦点
  ├─ gui_input() 仍会被调用 (鼠标事件)
  └─ 主要用于非交互控件 (标签、进度条等)
```

### 3. 消费和传播的优先级

```
输入事件到达某控件时的决策树:

输入事件
    ↓
是否消费? (set_input_as_handled)
    ├─ 是: ✓ 事件停止传播 (优先级+100)
    └─ 否: ✗ 事件继续往上
            ↓
            父控件是否消费?
            ├─ 是: ✓ 事件停止传播 (优先级+50)
            └─ 否: ✗ 继续往上...
```

**关键规则**:
- 一旦某个控件消费事件，其他所有控件都不会收到
- 不消费不等于不处理 (可以处理但允许传播)
- 焦点转移是原子操作 (焦点立即改变)

### 4. 信号发送优先级

```
焦点改变时的信号顺序:

1. [原焦点控件] focus_exited 信号发送
   └─ 连接的槽函数立即执行

2. [新焦点控件] focus_entered 信号发送
   └─ 连接的槽函数立即执行

3. [Viewport] _gui_roots_focus_changed 内部信号
   └─ 更新 UI 焦点框等

4. [下一帧] focus_changed(old, new) 信号 (如有)
   └─ 延迟处理
```

**重要**: 信号处理中的 grab_focus() 调用会立即触发另一次焦点转移

---

## 焦点转移机制

### 1. 主动焦点转移

#### 通过 grab_focus() 转移

```cpp
// 最直接的方式
my_button->grab_focus();

// 支持隐藏焦点框
my_button->grab_focus(true);  // 不显示焦点指示器
```

**作用范围**: 全局 Viewport 级别

#### 通过信号连接转移

```gdscript
# GDScript 示例
func _ready():
    button1.pressed.connect(_on_button1_pressed)

func _on_button1_pressed():
    button2.grab_focus()  # 焦点转移到 button2
```

### 2. 隐式焦点转移

#### 鼠标点击产生的焦点转移

```
鼠标点击
    ↓
Viewport hit test
    ↓
检查 focus_mode
    ├─ FOCUS_ALL: grab_focus() 自动调用
    ├─ FOCUS_CLICK: grab_focus() 自动调用
    └─ FOCUS_NONE: 不转移
```

**代码位置**: `scene/main/viewport.cpp:_gui_input()`

#### TAB 键产生的焦点转移

```
TAB 键输入
    ↓
focused_control._handle_focus_move_to_next()
    ↓
查找 focus_neighbor 或下一个 FOCUS_ALL 的控件
    ↓
调用 next_control.grab_focus()
```

**代码位置**: `scene/gui/control.cpp:_focus_moved()`

### 3. 焦点转移限制

#### FocusBehavior 限制

```cpp
// 禁止焦点进入此控件
set_focus_behavior_recursive(FOCUS_BEHAVIOR_DISABLED);

// 即使调用 grab_focus() 也会失败
my_control->grab_focus();  // ← 无效

// 检查焦点是否被禁用
if (my_control->get_focus_behavior() == FOCUS_BEHAVIOR_DISABLED) {
    // 不能获得焦点
}
```

**作用范围**: 该控件及其整个子树

#### 可见性和启用状态

```cpp
// 隐藏时自动失焦
my_control->hide();  // ← 若有焦点会调用 release_focus()

// 禁用时自动失焦
my_control->set_disabled(true);  // ← 若有焦点会调用 release_focus()

// 可见且启用时才能获得焦点
if (my_control->is_visible() && !my_control->is_disabled()) {
    my_control->grab_focus();  // ← 成功
}
```

### 4. 焦点邻域 (Focus Neighbor)

```cpp
// 设置 TAB 焦点邻域
my_button->set_focus_neighbor(SIDE_RIGHT, button_right.get_path());

// 自动 TAB 导航会使用这个邻域
```

**作用范围**:
- 仅影响 TAB 键导航
- 不影响 grab_focus()
- 可以跨越不相邻的控件

---

## 实现架构

### 1. 核心类和结构

#### Viewport::GUIData 结构

```cpp
struct GUIData {
    // 焦点管理
    Control *focused_control = nullptr;           // 当前焦点控件
    Control *mouse_focus = nullptr;               // 鼠标焦点控件
    Control *scroll_focus = nullptr;              // 滚轮焦点控件

    // 焦点属性
    bool unfocus_on_modal_close = true;          // 模态窗口关闭时失焦
    bool gui_disable_input = false;              // 禁用所有 GUI 输入

    // 鼠标状态
    Point2i last_mouse_pos;                       // 上一帧鼠标位置
    bool mouse_in_viewport = false;               // 鼠标在视口内

    // 提示气泡
    Control *tooltip_control = nullptr;           // 当前提示气泡控件
    Timer *tooltip_timer = nullptr;              // 提示气泡计时器

    // 根节点
    List<Control *> roots;                        // 所有根控件 (顶层)
};
```

**位置**: `scene/main/viewport.h:410`

#### Control 类焦点相关成员

```cpp
class Control : public CanvasItem {
private:
    struct Data {
        FocusMode focus_mode = FOCUS_NONE;
        FocusBehavior focus_behavior_recursive = FOCUS_BEHAVIOR_INHERITED;
        bool focus_neighbor_left_exists = false;
        bool focus_neighbor_right_exists = false;
        bool focus_neighbor_up_exists = false;
        bool focus_neighbor_down_exists = false;

        NodePath focus_neighbor_left;
        NodePath focus_neighbor_right;
        NodePath focus_neighbor_up;
        NodePath focus_neighbor_down;
    } data;

public:
    // 焦点操作
    void grab_focus(bool p_hide_focus = false);
    void release_focus();
    bool has_focus(bool p_ignore_hidden_focus = false) const;

    // 焦点模式设置
    void set_focus_mode(FocusMode p_mode);
    FocusMode get_focus_mode() const;
};
```

**位置**: `scene/gui/control.h`

### 2. 关键函数调用链

#### grab_focus() 的完整调用链

```
Control::grab_focus()
    ↓ scene/gui/control.cpp:2353
Viewport::_gui_control_grab_focus(Control* p_control, bool p_hide_focus)
    ↓ scene/main/viewport.cpp:2699
检查: gui_disable_input 标志
    ↓
检查: p_control->get_focus_behavior() != FOCUS_BEHAVIOR_DISABLED
    ↓
获取: old_focus = gui.focused_control
    ↓
若 old_focus != p_control:
    ├─ old_focus->_focus_exited_callback()
    │  └─ 发送 focus_exited 信号
    ├─ gui.focused_control = p_control
    ├─ p_control->_focus_entered_callback()
    │  └─ 发送 focus_entered 信号
    └─ _gui_roots_focus_changed(p_control)
        └─ 更新 UI 焦点框
```

#### gui_input() 的完整调用链

```
Viewport._gui_input(const Ref<InputEvent> &p_event)
    ↓ scene/main/viewport.cpp:2030
检查: gui_disable_input 标志
    ↓
若是 InputEventMouseButton 或 InputEventMouseMotion:
    ├─ 执行 hit test
    ├─ 更新 mouse_focus 和 mouse_hovered
    └─ 可能调用 grab_focus()
        ↓
若有 focused_control:
    ├─ focused_control.gui_input(p_event)  ← 焦点控件优先
    └─ 检查 is_input_handled()
        ├─ 是: 返回 (事件被消费)
        └─ 否: 继续传播
        ↓
        parents.gui_input(p_event)  ← 向上传播
        └─ 检查 is_input_handled()
            ├─ 是: 返回
            └─ 否: 继续
            ↓
            scene_root._input(p_event)  ← 脚本层处理
```

### 3. 信号定义

#### Control 中的焦点相关信号

```cpp
// 位置: scene/gui/control.cpp:4416

ADD_SIGNAL(MethodInfo("focus_entered"));        // 获得焦点时
ADD_SIGNAL(MethodInfo("focus_exited"));         // 失去焦点时
ADD_SIGNAL(MethodInfo("mouse_entered"));        // 鼠标进入时
ADD_SIGNAL(MethodInfo("mouse_exited"));         // 鼠标离开时
ADD_SIGNAL(MethodInfo("gui_input",
    PropertyInfo(Variant::OBJECT, "event",
        PROPERTY_HINT_RESOURCE_TYPE, "InputEvent")));  // GUI 输入时
```

#### Viewport 中的焦点相关信号

```cpp
// 位置: scene/main/viewport.cpp

// 焦点改变信号
SIGNAL(SIGNAL_NAME(gui_focus_changed), "control", control);

// 鼠标进入/离开视口
SIGNAL(SIGNAL_NAME(gui_focus_changed), ...);
```

---

## 最佳实践

### 1. 焦点管理最佳实践

#### ✅ 正确的焦点转移

```gdscript
# 在适当的时机转移焦点
func _on_button_pressed():
    next_control.grab_focus()

# 提供焦点邻域便于 TAB 导航
func _ready():
    button1.focus_neighbor_right = button2.get_path()
    button2.focus_neighbor_left = button1.get_path()
```

#### ❌ 避免的做法

```gdscript
# 不要在 focus_entered 中再次 grab_focus()
func _on_focus_entered():
    grab_focus()  # ← 可能导致无限循环

# 不要假设焦点改变会立即生效
grab_focus()
print(has_focus())  # ← 可能还是 false (检查时间)

# 不要在 gui_input() 中频繁转移焦点
func gui_input(event):
    if event is InputEventKey:
        grab_focus()  # ← 过度转移
```

### 2. 输入事件处理最佳实践

#### ✅ 正确的事件消费

```cpp
void MyControl::gui_input(const Ref<InputEvent> &p_event) {
    Ref<InputEventMouseButton> mb = p_event;
    if (mb.is_valid() && mb->is_pressed()) {
        // 处理事件
        _handle_click(mb->get_position());

        // 消费事件以防止传播
        get_tree()->set_input_as_handled();
        return;
    }

    // 其他事件不消费，继续传播
}
```

#### ❌ 避免的做法

```cpp
void MyControl::gui_input(const Ref<InputEvent> &p_event) {
    // 不要总是消费事件
    get_tree()->set_input_as_handled();  // ← 过度消费

    // 不要在处理前消费
    get_tree()->set_input_as_handled();
    Ref<InputEventMouseButton> mb = p_event;  // ← 消费后处理
    if (mb.is_valid()) {
        // ...
    }
}
```

### 3. 焦点模式设置最佳实践

#### ✅ 正确的模式选择

```gdscript
# 对话框按钮: 支持 TAB 导航
dialog_button.focus_mode = Control.FOCUS_ALL

# 工具栏按钮: 仅鼠标点击
toolbar_button.focus_mode = Control.FOCUS_CLICK

# 标签或分隔符: 不参与焦点
separator.focus_mode = Control.FOCUS_NONE
```

#### ❌ 避免的做法

```gdscript
# 不要过度使用 FOCUS_ALL
every_control.focus_mode = Control.FOCUS_ALL  # ← TAB 导航混乱

# 不要忘记设置焦点模式
my_button.focus_mode  # ← 默认是 FOCUS_NONE，需要手动设置

# 不要混合使用焦点模式
button1.focus_mode = Control.FOCUS_ALL
button2.focus_mode = Control.FOCUS_NONE
button3.focus_mode = Control.FOCUS_CLICK  # ← TAB 导航不一致
```

### 4. 全局焦点状态管理

#### ✅ 处理焦点丧失

```gdscript
# 焦点丧失时保存状态
func _on_focus_exited():
    _save_current_state()

# 焦点恢复时恢复状态
func _on_focus_entered():
    _restore_last_state()
```

#### ✅ 处理窗口失活

```cpp
// 在 Viewport 级别处理
void Viewport::set_gui_disable_input(bool p_disable) {
    if (p_disable && gui.focused_control) {
        gui.focused_control->release_focus();  // 窗口失活时释放焦点
    }
}
```

### 5. 鼠标焦点管理

#### ✅ 正确的鼠标追踪

```gdscript
# 需要追踪鼠标进入/离开时进行设置
func _ready():
    mouse_filter = Control.MOUSE_FILTER_STOP  # 接收鼠标事件
    connect("mouse_entered", _on_mouse_entered)
    connect("mouse_exited", _on_mouse_exited)

func _on_mouse_entered():
    # 准备鼠标悬停状态
    _on_hover = true
    queue_redraw()

func _on_mouse_exited():
    # 清理鼠标悬停状态
    _on_hover = false
    queue_redraw()
```

#### ❌ 避免的做法

```gdscript
# 不要设置 MOUSE_FILTER_IGNORE 后期望鼠标事件
mouse_filter = Control.MOUSE_FILTER_IGNORE
# 现在 gui_input() 不会收到鼠标事件

# 不要在 gui_input() 中改变 mouse_filter
func gui_input(event):
    if event is InputEventMouseButton:
        mouse_filter = Control.MOUSE_FILTER_PASS  # ← 太晚了
```

---

## 总结表

### 全局 vs 局部对比

| 特性 | 全局范围 | 局部范围 |
|------|--------|--------|
| **作用域** | 整个 Viewport | 单个 Control 及子树 |
| **焦点状态** | Viewport 中一个 Control | 该 Control 内部状态 |
| **事件分发** | 由 Viewport 协调 | 由 Control 处理 |
| **转移机制** | grab_focus() 原子操作 | 沿树传播 |
| **查询方式** | has_focus() 跨树查询 | is_focus_mode() 本地查询 |
| **优先级** | 焦点控件最高 | 消费标志决定 |
| **限制** | gui_disable_input | mouse_filter, focus_mode |
| **信号** | focus_entered/exited | gui_input 处理 |
| **性能** | O(1) 快速查询 | O(n) 树遍历 |

### 响应范围决策表

| 场景 | 全局响应 | 局部响应 | 组合方式 |
|------|--------|--------|--------|
| **焦点转移** | ✓ grab_focus() | - | 仅全局 |
| **键盘输入** | ✓ 优先焦点 | ✓ 向上传播 | 全局优先 |
| **鼠标点击** | ✓ hit test | ✓ gui_input() | 全局+局部 |
| **事件消费** | ✓ 消费停止 | ✓ set_handled() | 任一有效 |
| **可见性** | ✓ 自动失焦 | ✓ 局部隐藏 | 级联效果 |
| **禁用状态** | ✓ 自动失焦 | ✓ 拒绝输入 | 级联效果 |

---

**报告完成时间**: 2026-01-19
**报告版本**: 1.0 (完整分析版)
**下一步**: 可基于本报告设计分心输入事件的处理框架
