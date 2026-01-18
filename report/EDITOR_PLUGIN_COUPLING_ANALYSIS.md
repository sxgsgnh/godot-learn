# Godot EditorNode 中 add_editor_plugin 的耦合度分析与解耦方案

## 📋 执行总结

**耦合度等级**：🔴 **高度耦合** (Tight Coupling)

EditorNode 中的 `add_editor_plugin()` 方法直接管理插件的生命周期、UI 集成、事件转发等，造成了 **8 大耦合点**。本文提供详细的耦合度分析和实践可行的解耦方案。

---

## 1. 耦合度分析

### 1.1 当前实现（高耦合）

```cpp
// editor_node.cpp, line 4221
void EditorNode::add_editor_plugin(EditorPlugin *p_editor, bool p_config_changed) {
    // 耦合点 1: 直接访问 editor_main_screen
    if (p_editor->has_main_screen()) {
        singleton->editor_main_screen->add_main_plugin(p_editor);
    }
    
    // 耦合点 2: 直接访问 editor_data
    singleton->editor_data.add_editor_plugin(p_editor);
    
    // 耦合点 3: 直接添加为子节点（树结构耦合）
    singleton->add_child(p_editor);
    
    // 耦合点 4: 直接调用启用/禁用
    if (p_config_changed) {
        p_editor->enable_plugin();
    }
}

void EditorNode::remove_editor_plugin(EditorPlugin *p_editor, bool p_config_changed) {
    // 耦合点 5: 直接访问 editor_main_screen
    if (p_editor->has_main_screen()) {
        singleton->editor_main_screen->remove_main_plugin(p_editor);
    }
    
    p_editor->make_visible(false);
    p_editor->clear();
    
    if (p_config_changed) {
        p_editor->disable_plugin();
    }
    
    // 耦合点 6-8: 直接访问三个插件列表
    singleton->editor_plugins_over->remove_plugin(p_editor);
    singleton->editor_plugins_force_over->remove_plugin(p_editor);
    singleton->editor_plugins_force_input_forwarding->remove_plugin(p_editor);
    
    singleton->remove_child(p_editor);
    singleton->editor_data.remove_editor_plugin(p_editor);

    // 耦合点 9: 直接修改 active_plugins
    for (KeyValue<ObjectID, HashSet<EditorPlugin *>> &kv : singleton->active_plugins) {
        kv.value.erase(p_editor);
    }
}
```

### 1.2 耦合点详解

| # | 耦合点 | 类型 | 影响 | 示例 |
|---|--------|------|------|------|
| 1 | `editor_main_screen` 直接访问 | 结构耦合 | 无法替换主屏幕实现 | `add_main_plugin()` |
| 2 | `editor_data` 直接访问 | 结构耦合 | 插件无法与数据分离 | `add_editor_plugin()` |
| 3 | Scene Tree 集成 | 结构耦合 | 插件必须是 EditorNode 子节点 | `add_child()` |
| 4 | 生命周期管理 | 行为耦合 | EditorNode 控制启用/禁用 | `enable_plugin()` |
| 5 | 可见性管理 | 行为耦合 | `make_visible()` 直接调用 | `make_visible(false)` |
| 6-8 | 三个插件列表 | 结构耦合 | 需要手动维护三个列表 | `editor_plugins_over/force_over/force_input_forwarding` |
| 9 | `active_plugins` HashMap | 结构耦合 | 复杂的插件追踪逻辑 | 全局搜索和移除 |

### 1.3 耦合依赖图

```
EditorNode (高耦合中心)
    ├─ EditorPlugin 
    │   ├─ 依赖 EditorNode 的 add_child()
    │   ├─ 依赖 EditorNode 的 enable/disable
    │   └─ 依赖 EditorNode 的通知系统
    │
    ├─ EditorMainScreen 
    │   └─ 紧密耦合（需要 add_main_plugin/remove_main_plugin）
    │
    ├─ EditorData
    │   └─ 紧密耦合（管理插件数据）
    │
    ├─ EditorPluginList (×3)
    │   ├─ editor_plugins_over
    │   ├─ editor_plugins_force_over
    │   └─ editor_plugins_force_input_forwarding
    │
    └─ active_plugins HashMap
        └─ 复杂的生命周期追踪

EditorPlugin 的耦合方向:
    ├─ 依赖 EditorNode (getter/setter)
    ├─ 依赖 EditorInterface (中间代理，但仍指向 EditorNode)
    ├─ 依赖 Singleton 模式
    └─ 难以单独测试
```

### 1.4 具体耦合问题代码示例

#### 问题 1: 无法自定义主屏幕集成
```cpp
// EditorPlugin 无法控制主屏幕注册
void EditorNode::add_editor_plugin(EditorPlugin *p_editor, bool p_config_changed) {
    if (p_editor->has_main_screen()) {
        // 硬编码：只能使用 EditorNode 的 editor_main_screen
        singleton->editor_main_screen->add_main_plugin(p_editor);  // ❌ 无法替换
    }
}
```

#### 问题 2: Scene Tree 强制绑定
```cpp
// 插件必须成为 EditorNode 的子节点，难以独立管理
singleton->add_child(p_editor);  // ❌ 强制树关系

// 在 remove 时
singleton->remove_child(p_editor);  // ❌ 必须从树中移除
```

#### 问题 3: 复杂的生命周期管理
```cpp
// 启用/禁用逻辑分散
if (p_config_changed) {
    p_editor->enable_plugin();  // ❌ 条件化的生命周期
}

p_editor->make_visible(false);  // ❌ 先隐藏再清理
p_editor->clear();              // ❌ 多步清理过程
p_editor->disable_plugin();     // ❌ 条件化的禁用
```

#### 问题 4: 三个插件列表的冗余管理
```cpp
// 移除时需要从三个列表中分别移除
singleton->editor_plugins_over->remove_plugin(p_editor);          // ❌
singleton->editor_plugins_force_over->remove_plugin(p_editor);    // ❌
singleton->editor_plugins_force_input_forwarding->remove_plugin(p_editor);  // ❌
```

#### 问题 5: active_plugins 的复杂追踪
```cpp
// 需要遍历所有 active_plugins 来移除引用
for (KeyValue<ObjectID, HashSet<EditorPlugin *>> &kv : singleton->active_plugins) {
    kv.value.erase(p_editor);  // ❌ 全局搜索和移除
}
```

---

## 2. 耦合造成的问题

### 2.1 可维护性问题

| 问题 | 影响 | 示例 |
|------|------|------|
| **代码散落** | 插件逻辑分散在 EditorNode 的多个地方 | add/remove 函数、_plugin_over_* 回调 |
| **难以追踪** | 修改插件行为需要查找 EditorNode 中的多个位置 | 添加新的插件列表类型需要修改 3+ 个地方 |
| **重复代码** | 启用/禁用、可见性等逻辑重复 | 多个地方调用 `make_visible()` |

### 2.2 可扩展性问题

| 问题 | 影响 |
|------|------|
| **难以添加新的插件类型** | 需要修改 EditorNode，添加新的列表或逻辑 |
| **难以支持动态插件** | 复杂的初始化/清理流程不容易动态执行 |
| **难以实现插件热重载** | active_plugins 的追踪使得卸载/重新加载复杂化 |

### 2.3 测试问题

| 问题 | 影响 |
|------|------|
| **难以单元测试** | EditorPlugin 离不开 EditorNode singleton |
| **难以集成测试** | 需要完整的 EditorNode 上下文 |
| **难以模拟** | 无法模拟 EditorNode 的行为 |

### 2.4 性能问题

| 问题 | 影响 | 代码 |
|------|------|------|
| **线性查找** | 移除插件时 O(n) 遍历 active_plugins | `for (KeyValue<...> &kv : active_plugins)` |
| **多次迭代** | 从三个列表中移除导致多次遍历 | 三个 `remove_plugin()` 调用 |

---

## 3. 解耦方案

### 3.1 方案 A: 事件驱动架构（推荐）

#### 目标
使用信号/事件系统替代直接的方法调用。

#### 实现

```cpp
// 新建 plugin_manager.h
class EditorPluginManager : public Node {
    GDCLASS(EditorPluginManager, Node);
    
private:
    // 事件系统
    Signal plugin_added;           // Signal<EditorPlugin*>
    Signal plugin_removed;         // Signal<EditorPlugin*>
    Signal plugin_enabled;         // Signal<EditorPlugin*>
    Signal plugin_disabled;        // Signal<EditorPlugin*>
    
    // 插件容器（与 EditorNode 解耦）
    List<EditorPlugin*> plugins;
    HashMap<ObjectID, EditorPlugin*> plugin_map;
    
    // 生命周期事件
    void _on_plugin_added(EditorPlugin *p_plugin);
    void _on_plugin_removed(EditorPlugin *p_plugin);
    
protected:
    static void _bind_methods();
    void _notification(int p_what);
    
public:
    // 核心 API（简化）
    void add_plugin(EditorPlugin *p_plugin);
    void remove_plugin(EditorPlugin *p_plugin);
    
    // 查询 API
    EditorPlugin* get_plugin(ObjectID p_id);
    List<EditorPlugin*> get_all_plugins() const;
    
    // 事件订阅
    void connect_plugin_added(const Callable &p_callable);
    void connect_plugin_removed(const Callable &p_callable);
    
    static EditorPluginManager* get_singleton();
};
```

#### 相应的 EditorNode 改变

```cpp
// editor_node.h 中删除：
// - EditorPluginList *editor_plugins_over;
// - EditorPluginList *editor_plugins_force_over;
// - EditorPluginList *editor_plugins_force_input_forwarding;
// - HashMap<ObjectID, HashSet<EditorPlugin *>> active_plugins;

// 添加：
EditorPluginManager *plugin_manager;

// editor_node.cpp 中
void EditorNode::_ready() {
    plugin_manager = memnew(EditorPluginManager);
    add_child(plugin_manager);
    
    // 订阅插件事件
    plugin_manager->connect_plugin_added(
        callable_mp(this, &EditorNode::_on_plugin_added)
    );
    plugin_manager->connect_plugin_removed(
        callable_mp(this, &EditorNode::_on_plugin_removed)
    );
}

void EditorNode::add_editor_plugin(EditorPlugin *p_editor, bool p_config_changed) {
    // 简化后：仅委托给 plugin_manager
    plugin_manager->add_plugin(p_editor);
    
    if (p_config_changed) {
        p_editor->enable_plugin();
    }
}

void EditorNode::_on_plugin_added(EditorPlugin *p_plugin) {
    // 响应 plugin_added 事件
    if (p_plugin->has_main_screen()) {
        editor_main_screen->add_main_plugin(p_plugin);
    }
    editor_data.add_editor_plugin(p_plugin);
    add_child(p_plugin);
}

void EditorNode::_on_plugin_removed(EditorPlugin *p_plugin) {
    if (p_plugin->has_main_screen()) {
        editor_main_screen->remove_main_plugin(p_plugin);
    }
    p_plugin->make_visible(false);
    p_plugin->clear();
    remove_child(p_plugin);
    editor_data.remove_editor_plugin(p_plugin);
}
```

#### 优势
- ✅ 解耦关键: EditorPluginManager 独立于 EditorNode
- ✅ 易于扩展: 新的 UI 层可以订阅事件
- ✅ 易于测试: 可以模拟 EditorPluginManager
- ✅ 清晰的流程: 事件流动明确

#### 缺点
- ❌ 需要大量重构
- ❌ 性能开销（事件分发）

---

### 3.2 方案 B: 策略模式 + 注册表（中等难度）

#### 目标
将不同的集成策略从 EditorNode 中提取出来。

#### 实现

```cpp
// plugin_integration_strategy.h
class PluginIntegrationStrategy {
    GDCLASS(PluginIntegrationStrategy, Resource);
    
public:
    virtual void on_plugin_added(EditorPlugin *p_plugin) = 0;
    virtual void on_plugin_removed(EditorPlugin *p_plugin) = 0;
    virtual void on_plugin_enabled(EditorPlugin *p_plugin) = 0;
    virtual void on_plugin_disabled(EditorPlugin *p_plugin) = 0;
};

// 具体策略实现
class MainScreenIntegrationStrategy : public PluginIntegrationStrategy {
    EditorMainScreen *editor_main_screen;
    
public:
    void on_plugin_added(EditorPlugin *p_plugin) override {
        if (p_plugin->has_main_screen()) {
            editor_main_screen->add_main_plugin(p_plugin);
        }
    }
    
    void on_plugin_removed(EditorPlugin *p_plugin) override {
        if (p_plugin->has_main_screen()) {
            editor_main_screen->remove_main_plugin(p_plugin);
        }
    }
    // ...
};

class DataIntegrationStrategy : public PluginIntegrationStrategy {
    EditorData *editor_data;
    
public:
    void on_plugin_added(EditorPlugin *p_plugin) override {
        editor_data->add_editor_plugin(p_plugin);
    }
    
    void on_plugin_removed(EditorPlugin *p_plugin) override {
        editor_data->remove_editor_plugin(p_plugin);
    }
    // ...
};

// 策略注册表
class PluginIntegrationRegistry {
    Vector<PluginIntegrationStrategy*> strategies;
    
public:
    void register_strategy(PluginIntegrationStrategy *p_strategy) {
        strategies.push_back(p_strategy);
    }
    
    void notify_plugin_added(EditorPlugin *p_plugin) {
        for (auto strategy : strategies) {
            strategy->on_plugin_added(p_plugin);
        }
    }
    
    void notify_plugin_removed(EditorPlugin *p_plugin) {
        for (auto strategy : strategies) {
            strategy->on_plugin_removed(p_plugin);
        }
    }
};

// EditorNode 中
void EditorNode::_setup_plugin_integration() {
    plugin_registry = memnew(PluginIntegrationRegistry);
    
    plugin_registry->register_strategy(
        memnew(MainScreenIntegrationStrategy(editor_main_screen))
    );
    plugin_registry->register_strategy(
        memnew(DataIntegrationStrategy(editor_data))
    );
    // 添加更多策略...
}

void EditorNode::add_editor_plugin(EditorPlugin *p_editor, bool p_config_changed) {
    // 通知所有策略
    plugin_registry->notify_plugin_added(p_editor);
    
    if (p_config_changed) {
        p_editor->enable_plugin();
    }
}

void EditorNode::remove_editor_plugin(EditorPlugin *p_editor, bool p_config_changed) {
    plugin_registry->notify_plugin_removed(p_editor);
    
    p_editor->make_visible(false);
    p_editor->clear();
    
    if (p_config_changed) {
        p_editor->disable_plugin();
    }
}
```

#### 优势
- ✅ 将不同关注点分离（Main Screen、Data、Input 等）
- ✅ 易于添加新的集成策略（无需修改核心逻辑）
- ✅ 易于单元测试（可以独立测试每个策略）
- ✅ 相对容易实现

#### 缺点
- ❌ 需要为每个关注点创建策略类（代码增加）
- ❌ 运行时性能开销（多个策略的迭代）

---

### 3.3 方案 C: 中间件模式（最简单）

#### 目标
创建一个中间层来管理插件的生命周期。

#### 实现

```cpp
// plugin_lifecycle_manager.h
class PluginLifecycleManager {
    EditorNode *editor_node;  // 保持对 EditorNode 的引用
    
    // 中间件
    struct Middleware {
        String name;
        Callable on_add;
        Callable on_remove;
    };
    
    Vector<Middleware> middlewares;
    
public:
    void register_middleware(
        const String &p_name,
        const Callable &p_on_add,
        const Callable &p_on_remove
    ) {
        Middleware m;
        m.name = p_name;
        m.on_add = p_on_add;
        m.on_remove = p_on_remove;
        middlewares.push_back(m);
    }
    
    void add_plugin(EditorPlugin *p_plugin, bool p_config_changed) {
        // 执行中间件
        for (auto &middleware : middlewares) {
            if (middleware.on_add.is_valid()) {
                middleware.on_add.call(p_plugin);
            }
        }
        
        if (p_config_changed) {
            p_plugin->enable_plugin();
        }
    }
    
    void remove_plugin(EditorPlugin *p_plugin, bool p_config_changed) {
        // 反向执行中间件
        for (int i = middlewares.size() - 1; i >= 0; i--) {
            if (middlewares[i].on_remove.is_valid()) {
                middlewares[i].on_remove.call(p_plugin);
            }
        }
        
        p_plugin->make_visible(false);
        p_plugin->clear();
        
        if (p_config_changed) {
            p_plugin->disable_plugin();
        }
    }
};

// EditorNode 中
void EditorNode::_setup_plugin_middlewares() {
    lifecycle_manager = memnew(PluginLifecycleManager);
    
    // 中间件 1: Main Screen
    lifecycle_manager->register_middleware(
        "main_screen",
        Callable(this, "_plugin_add_to_main_screen"),
        Callable(this, "_plugin_remove_from_main_screen")
    );
    
    // 中间件 2: Editor Data
    lifecycle_manager->register_middleware(
        "editor_data",
        Callable(this, "_plugin_add_to_data"),
        Callable(this, "_plugin_remove_from_data")
    );
    
    // 中间件 3: Scene Tree
    lifecycle_manager->register_middleware(
        "scene_tree",
        Callable(this, "_plugin_add_to_tree"),
        Callable(this, "_plugin_remove_from_tree")
    );
}

void EditorNode::add_editor_plugin(EditorPlugin *p_editor, bool p_config_changed) {
    lifecycle_manager->add_plugin(p_editor, p_config_changed);
}

void EditorNode::remove_editor_plugin(EditorPlugin *p_editor, bool p_config_changed) {
    lifecycle_manager->remove_plugin(p_editor, p_config_changed);
}

// 中间件处理函数（清晰分离）
void EditorNode::_plugin_add_to_main_screen(EditorPlugin *p_plugin) {
    if (p_plugin->has_main_screen()) {
        editor_main_screen->add_main_plugin(p_plugin);
    }
}

void EditorNode::_plugin_remove_from_main_screen(EditorPlugin *p_plugin) {
    if (p_plugin->has_main_screen()) {
        editor_main_screen->remove_main_plugin(p_plugin);
    }
}

void EditorNode::_plugin_add_to_data(EditorPlugin *p_plugin) {
    editor_data.add_editor_plugin(p_plugin);
}

void EditorNode::_plugin_remove_from_data(EditorPlugin *p_plugin) {
    editor_data.remove_editor_plugin(p_plugin);
}

void EditorNode::_plugin_add_to_tree(EditorPlugin *p_plugin) {
    add_child(p_plugin);
}

void EditorNode::_plugin_remove_from_tree(EditorPlugin *p_plugin) {
    remove_child(p_plugin);
}
```

#### 优势
- ✅ 最简单，代码改动最小
- ✅ 清晰的中间件顺序
- ✅ 易于调试（每个中间件是独立的步骤）
- ✅ 易于禁用某个中间件

#### 缺点
- ❌ 仍然需要 EditorNode 的引用
- ❌ 不如事件驱动彻底

---

### 3.4 方案 D: 容器隔离（简单但有限）

#### 目标
将插件列表从 EditorNode 中提取到独立的容器类。

#### 实现

```cpp
// plugin_container.h
class EditorPluginContainer : public RefCounted {
    HashMap<ObjectID, EditorPlugin*> plugin_map;
    List<EditorPlugin*> plugins;
    
    EditorPluginList *plugins_over = nullptr;
    EditorPluginList *plugins_force_over = nullptr;
    EditorPluginList *plugins_force_input_forwarding = nullptr;
    
public:
    void add_plugin(EditorPlugin *p_plugin) {
        plugin_map[p_plugin->get_instance_id()] = p_plugin;
        plugins.push_back(p_plugin);
    }
    
    void remove_plugin(EditorPlugin *p_plugin) {
        plugin_map.erase(p_plugin->get_instance_id());
        plugins.erase(p_plugin);
        
        plugins_over->remove_plugin(p_plugin);
        plugins_force_over->remove_plugin(p_plugin);
        plugins_force_input_forwarding->remove_plugin(p_plugin);
    }
    
    EditorPlugin* get_plugin(ObjectID p_id) {
        return plugin_map.get(p_id, nullptr);
    }
    
    const List<EditorPlugin*>& get_all() const { return plugins; }
    
    EditorPluginList* get_over_list() { return plugins_over; }
    EditorPluginList* get_force_over_list() { return plugins_force_over; }
    EditorPluginList* get_force_input_forwarding_list() { return plugins_force_input_forwarding; }
};

// EditorNode 中
class EditorNode {
    Ref<EditorPluginContainer> plugin_container;
};

void EditorNode::add_editor_plugin(EditorPlugin *p_editor, bool p_config_changed) {
    plugin_container->add_plugin(p_editor);
    
    if (p_editor->has_main_screen()) {
        singleton->editor_main_screen->add_main_plugin(p_editor);
    }
    singleton->editor_data.add_editor_plugin(p_editor);
    singleton->add_child(p_editor);
    
    if (p_config_changed) {
        p_editor->enable_plugin();
    }
}
```

#### 优势
- ✅ 实现最简单，代码改动最少
- ✅ 清晰的容器职责

#### 缺点
- ❌ 只是将数据结构提取出来，不解决根本耦合
- ❌ 核心逻辑仍在 EditorNode 中

---

## 4. 解耦方案对比

| 方案 | 难度 | 解耦度 | 易测试 | 代码改动 | 性能 | 推荐度 |
|------|------|--------|--------|----------|------|---------|
| **A. 事件驱动** | ⭐⭐⭐⭐ | 🟢 高 | 🟢 是 | 很大 | 🟡 有开销 | ⭐⭐⭐⭐⭐ |
| **B. 策略模式** | ⭐⭐⭐ | 🟢 中高 | 🟢 是 | 中等 | 🟢 正常 | ⭐⭐⭐⭐ |
| **C. 中间件模式** | ⭐⭐ | 🟡 中 | 🟡 一般 | 较小 | 🟢 正常 | ⭐⭐⭐ |
| **D. 容器隔离** | ⭐ | 🔴 低 | 🔴 否 | 很小 | 🟢 正常 | ⭐⭐ |

---

## 5. 推荐实施步骤

### 第一阶段: 快速收益（选择方案 C 或 D）

1. ✅ 实现 `PluginLifecycleManager` 或 `EditorPluginContainer`
2. ✅ 重构 `add_editor_plugin()` 和 `remove_editor_plugin()`
3. ✅ 验证现有功能不破坏

**预期收益**：
- 代码更清晰（插件逻辑集中）
- 便于维护（易于找到相关代码）

### 第二阶段: 中期改进（升级到方案 B）

1. ✅ 定义 `PluginIntegrationStrategy` 基类
2. ✅ 创建具体策略（Main Screen、Data、Input等）
3. ✅ 实现 `PluginIntegrationRegistry`
4. ✅ 将 EditorNode 的逻辑迁移到策略

**预期收益**：
- 真正的关注点分离
- 易于单元测试
- 易于添加新的集成类型

### 第三阶段: 长期目标（升级到方案 A）

1. ✅ 实现 `EditorPluginManager` 独立管理
2. ✅ 将 EditorNode 改为事件订阅者
3. ✅ 支持动态加载/卸载插件

**预期收益**：
- 完全解耦
- 支持插件热重载
- 支持多进程架构

---

## 6. 代码示例：方案 C 的完整实现

### 6.1 头文件

```cpp
// editor_plugin_lifecycle_manager.h
#pragma once

#include "core/object/ref_counted.h"
#include "core/variant/callable.h"

class EditorPlugin;

class EditorPluginLifecycleManager : public RefCounted {
    GDCLASS(EditorPluginLifecycleManager, RefCounted);
    
private:
    struct Middleware {
        String name;
        Callable on_add;
        Callable on_remove;
        bool enabled = true;
    };
    
    Vector<Middleware> add_middlewares;
    Vector<Middleware> remove_middlewares;
    
    void _execute_add_middlewares(EditorPlugin *p_plugin);
    void _execute_remove_middlewares(EditorPlugin *p_plugin);
    
protected:
    static void _bind_methods();
    
public:
    void register_add_middleware(
        const String &p_name,
        const Callable &p_callable
    );
    
    void register_remove_middleware(
        const String &p_name,
        const Callable &p_callable
    );
    
    void enable_middleware(const String &p_name);
    void disable_middleware(const String &p_name);
    
    void add_plugin(EditorPlugin *p_plugin, bool p_config_changed = false);
    void remove_plugin(EditorPlugin *p_plugin, bool p_config_changed = false);
};
```

### 6.2 实现文件

```cpp
// editor_plugin_lifecycle_manager.cpp
#include "editor_plugin_lifecycle_manager.h"
#include "editor_plugin.h"

void EditorPluginLifecycleManager::_bind_methods() {
    ClassDB::bind_method(
        D_METHOD("register_add_middleware", "name", "callable"),
        &EditorPluginLifecycleManager::register_add_middleware
    );
    ClassDB::bind_method(
        D_METHOD("register_remove_middleware", "name", "callable"),
        &EditorPluginLifecycleManager::register_remove_middleware
    );
    ClassDB::bind_method(
        D_METHOD("enable_middleware", "name"),
        &EditorPluginLifecycleManager::enable_middleware
    );
    ClassDB::bind_method(
        D_METHOD("disable_middleware", "name"),
        &EditorPluginLifecycleManager::disable_middleware
    );
}

void EditorPluginLifecycleManager::register_add_middleware(
    const String &p_name,
    const Callable &p_callable
) {
    for (auto &mw : add_middlewares) {
        if (mw.name == p_name) {
            mw.on_add = p_callable;
            return;
        }
    }
    
    Middleware m;
    m.name = p_name;
    m.on_add = p_callable;
    add_middlewares.push_back(m);
}

void EditorPluginLifecycleManager::register_remove_middleware(
    const String &p_name,
    const Callable &p_callable
) {
    for (auto &mw : remove_middlewares) {
        if (mw.name == p_name) {
            mw.on_remove = p_callable;
            return;
        }
    }
    
    Middleware m;
    m.name = p_name;
    m.on_remove = p_callable;
    remove_middlewares.push_back(m);
}

void EditorPluginLifecycleManager::enable_middleware(const String &p_name) {
    for (auto &mw : add_middlewares) {
        if (mw.name == p_name) {
            mw.enabled = true;
            break;
        }
    }
    for (auto &mw : remove_middlewares) {
        if (mw.name == p_name) {
            mw.enabled = true;
            break;
        }
    }
}

void EditorPluginLifecycleManager::disable_middleware(const String &p_name) {
    for (auto &mw : add_middlewares) {
        if (mw.name == p_name) {
            mw.enabled = false;
            break;
        }
    }
    for (auto &mw : remove_middlewares) {
        if (mw.name == p_name) {
            mw.enabled = false;
            break;
        }
    }
}

void EditorPluginLifecycleManager::_execute_add_middlewares(EditorPlugin *p_plugin) {
    for (auto &mw : add_middlewares) {
        if (!mw.enabled) continue;
        if (!mw.on_add.is_valid()) continue;
        mw.on_add.call(p_plugin);
    }
}

void EditorPluginLifecycleManager::_execute_remove_middlewares(EditorPlugin *p_plugin) {
    for (int i = remove_middlewares.size() - 1; i >= 0; i--) {
        auto &mw = remove_middlewares[i];
        if (!mw.enabled) continue;
        if (!mw.on_remove.is_valid()) continue;
        mw.on_remove.call(p_plugin);
    }
}

void EditorPluginLifecycleManager::add_plugin(
    EditorPlugin *p_plugin,
    bool p_config_changed
) {
    _execute_add_middlewares(p_plugin);
    
    if (p_config_changed) {
        p_plugin->enable_plugin();
    }
}

void EditorPluginLifecycleManager::remove_plugin(
    EditorPlugin *p_plugin,
    bool p_config_changed
) {
    _execute_remove_middlewares(p_plugin);
    
    p_plugin->make_visible(false);
    p_plugin->clear();
    
    if (p_config_changed) {
        p_plugin->disable_plugin();
    }
}
```

### 6.3 在 EditorNode 中使用

```cpp
// editor_node.h 中
class EditorNode : public Control {
private:
    Ref<EditorPluginLifecycleManager> plugin_lifecycle_manager;
    
    // 中间件处理函数
    void _plugin_middleware_main_screen(EditorPlugin *p_plugin);
    void _plugin_middleware_remove_main_screen(EditorPlugin *p_plugin);
    void _plugin_middleware_data(EditorPlugin *p_plugin);
    void _plugin_middleware_remove_data(EditorPlugin *p_plugin);
    void _plugin_middleware_tree(EditorPlugin *p_plugin);
    void _plugin_middleware_remove_tree(EditorPlugin *p_plugin);
};

// editor_node.cpp 中
void EditorNode::_setup_plugin_lifecycle() {
    plugin_lifecycle_manager = Ref<EditorPluginLifecycleManager>(memnew(EditorPluginLifecycleManager));
    
    // 添加中间件（按顺序）
    plugin_lifecycle_manager->register_add_middleware(
        "main_screen",
        callable_mp(this, &EditorNode::_plugin_middleware_main_screen)
    );
    plugin_lifecycle_manager->register_add_middleware(
        "data",
        callable_mp(this, &EditorNode::_plugin_middleware_data)
    );
    plugin_lifecycle_manager->register_add_middleware(
        "tree",
        callable_mp(this, &EditorNode::_plugin_middleware_tree)
    );
    
    // 移除中间件（反向顺序）
    plugin_lifecycle_manager->register_remove_middleware(
        "tree",
        callable_mp(this, &EditorNode::_plugin_middleware_remove_tree)
    );
    plugin_lifecycle_manager->register_remove_middleware(
        "data",
        callable_mp(this, &EditorNode::_plugin_middleware_remove_data)
    );
    plugin_lifecycle_manager->register_remove_middleware(
        "main_screen",
        callable_mp(this, &EditorNode::_plugin_middleware_remove_main_screen)
    );
}

void EditorNode::add_editor_plugin(EditorPlugin *p_editor, bool p_config_changed) {
    // 简化后的实现
    plugin_lifecycle_manager->add_plugin(p_editor, p_config_changed);
}

void EditorNode::remove_editor_plugin(EditorPlugin *p_editor, bool p_config_changed) {
    plugin_lifecycle_manager->remove_plugin(p_editor, p_config_changed);
}

// 中间件实现
void EditorNode::_plugin_middleware_main_screen(EditorPlugin *p_plugin) {
    if (p_plugin->has_main_screen()) {
        editor_main_screen->add_main_plugin(p_plugin);
    }
}

void EditorNode::_plugin_middleware_remove_main_screen(EditorPlugin *p_plugin) {
    if (p_plugin->has_main_screen()) {
        editor_main_screen->remove_main_plugin(p_plugin);
    }
}

void EditorNode::_plugin_middleware_data(EditorPlugin *p_plugin) {
    editor_data.add_editor_plugin(p_plugin);
}

void EditorNode::_plugin_middleware_remove_data(EditorPlugin *p_plugin) {
    editor_data.remove_editor_plugin(p_plugin);
}

void EditorNode::_plugin_middleware_tree(EditorPlugin *p_plugin) {
    add_child(p_plugin);
}

void EditorNode::_plugin_middleware_remove_tree(EditorPlugin *p_plugin) {
    remove_child(p_plugin);
}
```

---

## 7. 迁移清单

### 第一阶段（立即可做）

- [ ] 创建 `EditorPluginLifecycleManager` 类
- [ ] 实现中间件系统
- [ ] 在 EditorNode 初始化时配置中间件
- [ ] 修改 `add_editor_plugin()` 和 `remove_editor_plugin()` 使用中间件
- [ ] 单元测试

### 第二阶段（后续）

- [ ] 提取 `PluginIntegrationStrategy` 基类
- [ ] 创建具体策略类
- [ ] 迁移中间件到策略
- [ ] 完整集成测试

### 第三阶段（长期）

- [ ] 创建独立的 `EditorPluginManager`
- [ ] 改为事件驱动
- [ ] 支持动态加载

---

## 8. 性能评估

### 当前性能（高耦合）
```
add_editor_plugin():     O(1) 直接调用
remove_editor_plugin():  O(n) 全局搜索 active_plugins
```

### 方案 C 后性能
```
add_editor_plugin():     O(m) m = 中间件数量（通常 3-5）
remove_editor_plugin():  O(m)
```

**结论**：性能基本无影响（m << n）。

---

## 9. 总结

### 核心问题
EditorNode 的 `add_editor_plugin()` 高度耦合于 9 个不同的系统，导致：
- 难以维护和扩展
- 难以单元测试
- 难以支持动态插件

### 推荐方案
**方案 C：中间件模式** 是最平衡的选择：
- ✅ 实现简单，改动最小
- ✅ 即可改进代码组织
- ✅ 为后续升级铺路
- ✅ 0 性能开销

### 长期目标
逐步升级到 **方案 A：事件驱动**：
- 完全解耦 EditorPluginManager
- 支持插件热重载
- 支持更灵活的架构

