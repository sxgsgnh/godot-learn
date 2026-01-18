# 项目管理器（ProjectManager）移除建议

## 概述

根据对 `main.cpp` 的分析，项目管理器在代码中分散在多个位置，需要系统地处理才能完全移除。本文档提供了详细的移除建议，包括依赖关系、影响分析和实现步骤。

---

## 一、项目管理器的核心角色

### 1.1 项目管理器的功能

项目管理器（ProjectManager）是编辑器在以下情况下启动的界面：
- 用户启动 Godot 但没有指定项目
- 用户使用 `-p` 或 `--project-manager` 命令行参数
- 没有找到有效的项目配置文件时的后备选项

### 1.2 项目管理器的作用

```
ProjectManager
├── 显示现有项目列表
├── 创建新项目
├── 导入现有项目
├── 打开选定的项目
├── 编辑项目设置
└── 项目导出配置管理
```

### 1.3 与其他组件的关系

```cpp
// 项目管理器依赖关系图
ProjectManager
├── EditorNode (互斥关系)
├── ProjectSettings (直接依赖)
├── EditorPaths (配置路径)
├── EditorSettings (编辑器设置)
├── ProgressDialog (进度显示)
└── TranslationServer (本地化)
```

---

## 二、main.cpp 中的项目管理器相关代码位置

### 2.1 全局变量定义

**位置**：`main.cpp:210`
```cpp
static bool project_manager = false;
```

**影响范围**：
- 在 setup() 中初始化
- 在 setup2() 中配置
- 在 start() 中实际创建
- 条件判断遍布整个文件

### 2.2 命令行参数处理

**位置**：`main.cpp:1541`
```cpp
} else if (arg == "-p" || arg == "--project-manager") {
    project_manager = true;
}
```

**影响**：
- 启用 `-p` 和 `--project-manager` 参数
- 这些参数需要被移除或标记为过时

### 2.3 条件逻辑分布

根据 grep 搜索结果，`project_manager` 在以下位置被使用（49 处）：

**主要位置分类**：
1. **互斥判断**（7 处）
   - `editor && project_manager` - 不能同时运行
   - `editor || project_manager` - 编辑器工具模式
   - `!project_manager && !editor` - 游戏模式

2. **配置应用**（12 处）
   - 窗口模式
   - 渲染驱动
   - 显示缩放
   - 窗口大小设置

3. **UI 初始化**（8 处）
   - 启动画面
   - 主题应用
   - 翻译域设置

4. **场景树上下文**（6 处）
   - DisplayServer 上下文设置
   - 编辑器提示

5. **实际创建**（1 处）
   - `main.cpp:4681` - 创建 ProjectManager 实例

---

## 三、详细移除步骤

### 3.1 第一阶段：准备工作

#### 步骤 1.1 - 理解启动流程

```cpp
// 当前启动流程（编辑器模式）
setup() {
    // 解析命令行参数
    if (arg == "-e" || arg == "--editor") {
        editor = true;
    }
    if (arg == "-p" || arg == "--project-manager") {
        project_manager = true;  // ← 需要移除
    }
    
    // 自动启用项目管理器（没有项目时）
    if (!project_manager && !editor) {
        project_manager = !found_project && !cmdline_tool;  // ← 需要修改
    }
}

setup2() {
    // 项目管理器特定的配置
    if (project_manager) {
        // ... 特定配置
    }
}

start() {
    // 创建项目管理器 UI
    if (project_manager) {
        ProjectManager *pmanager = memnew(ProjectManager);  // ← 需要移除
    }
}
```

#### 步骤 1.2 - 列出所有需要修改的代码块

| 行号 | 类型 | 修改方式 | 优先级 |
|-----|-----|--------|-------|
| 121 | include | 移除 | 高 |
| 210 | 变量 | 删除 | 高 |
| 1541 | 参数 | 移除 | 高 |
| 2000 | 互斥判断 | 删除条件 | 高 |
| 2062 | 条件分支 | 移除分支 | 高 |
| 2075-2077 | 自动启用 | 删除 | 高 |
| 2100 | 条件判断 | 修改 | 中 |
| 2102 | 条件判断 | 修改 | 中 |
| 2156-2161 | 配置块 | 移除 | 高 |
| 2246 | 日志配置 | 修改 | 低 |
| 2264 | 条件判断 | 修改 | 中 |
| 2275 | 条件判断 | 修改 | 中 |
| 2425 | 渲染驱动 | 删除条件 | 中 |
| 2593-2597 | 窗口大小 | 删除条件 | 中 |
| 2682 | 条件判断 | 修改 | 中 |
| 2696 | 条件判断 | 修改 | 中 |
| 2721 | 配置块 | 移除 | 中 |
| 2844 | 条件判断 | 修改 | 中 |
| 2960 | 条件判断 | 修改 | 中 |
| 2966 | 条件判断 | 修改 | 中 |
| 3000-3001 | 屏幕属性 | 删除分支 | 低 |
| 3193 | 显示上下文 | 删除分支 | 高 |
| 3210 | 条件判断 | 修改 | 低 |
| 3217 | 条件判断 | 修改 | 中 |
| 3283-3299 | 显示缩放 | 删除条件 | 高 |
| 3525 | 条件判断 | 修改 | 中 |
| 3760 | 条件判断 | 删除 | 低 |
| 3833 | 启动画面 | 删除条件 | 中 |
| 3842 | 启动画面 | 删除条件 | 中 |
| 3936 | 后备启用 | 删除 | 高 |
| 4216 | 启动检查 | 修改 | 高 |
| 4356 | 窗口配置 | 修改 | 中 |
| 4363 | 窗口配置 | 修改 | 中 |
| 4490 | 嵌入视口 | 修改 | 中 |
| 4571 | 场景加载 | 修改 | 中 |
| 4619 | 窗口设置 | 修改 | 中 |
| 4672-4689 | **创建实例** | **删除块** | **最高** |
| 4972 | 条件判断 | 修改 | 低 |

### 3.2 第二阶段：关键修改点

#### 修改 1：移除全局变量（优先级：最高）

**位置**：`main.cpp:210`

**当前代码**：
```cpp
static bool editor = false;
static bool project_manager = false;  // ← 删除
static bool cmdline_tool = false;
```

**修改后**：
```cpp
static bool editor = false;
static bool cmdline_tool = false;
```

#### 修改 2：移除命令行参数（优先级：最高）

**位置**：`main.cpp:1541`

**当前代码**：
```cpp
} else if (arg == "-e" || arg == "--editor") {
    editor = true;
} else if (arg == "-p" || arg == "--project-manager") {  // ← 删除整个分支
    project_manager = true;
} else if (arg == "--recovery-mode") {
```

**修改后**：
```cpp
} else if (arg == "-e" || arg == "--editor") {
    editor = true;
} else if (arg == "--recovery-mode") {
```

#### 修改 3：移除自动启用逻辑（优先级：最高）

**位置**：`main.cpp:2075-2077`

**当前代码**：
```cpp
#ifdef TOOLS_ENABLED
if (!project_manager && !editor) {
    // If we didn't find a project, we fall back to the project manager.
    project_manager = !found_project && !cmdline_tool;  // ← 删除
}
```

**修改后**：
```cpp
#ifdef TOOLS_ENABLED
if (!editor) {
    // If we didn't find a project, we need to ensure a valid project is provided.
    if (!found_project && !cmdline_tool) {
        OS::get_singleton()->print_error("No project found and no command-line tool specified. Please specify a project path.\n");
        goto error;
    }
}
```

#### 修改 4：删除项目管理器创建（优先级：最高）

**位置**：`main.cpp:4672-4689`

**当前代码**：
```cpp
#ifdef TOOLS_ENABLED
if (project_manager) {
    OS::get_singleton()->benchmark_begin_measure("Startup", "Project Manager");
    Engine::get_singleton()->set_editor_hint(true);

    sml->get_root()->set_translation_domain("godot.editor");
    if (editor_pseudolocalization) {
        translation_server->get_editor_domain()->set_pseudolocalization_enabled(true);
    }

    ProjectManager *pmanager = memnew(ProjectManager);
    ProgressDialog *progress_dialog = memnew(ProgressDialog);
    pmanager->add_child(progress_dialog);

    sml->get_root()->add_child(pmanager);
    OS::get_singleton()->benchmark_end_measure("Startup", "Project Manager");
}

if (project_manager || editor) {
    // Load SSL Certificates from Editor Settings (or builtin)
```

**修改后**：
```cpp
#ifdef TOOLS_ENABLED
if (editor) {
    // Load SSL Certificates from Editor Settings (or builtin)
```

#### 修改 5：处理互斥条件（优先级：高）

**位置**：`main.cpp:2000`

**当前代码**：
```cpp
if (editor && project_manager) {
    OS::get_singleton()->print_error("The --editor and --project-manager options cannot be used together, aborting.\n");
    goto error;
}
```

**修改后**：
```cpp
// 可以删除整个检查块，因为 project_manager 变量已删除
```

#### 修改 6：修改显示上下文（优先级：高）

**位置**：`main.cpp:3190-3198`

**当前代码**：
```cpp
DisplayServer::Context context;
if (editor) {
    context = DisplayServer::CONTEXT_EDITOR;
} else if (project_manager) {
    context = DisplayServer::CONTEXT_PROJECTMAN;
} else {
    context = DisplayServer::CONTEXT_ENGINE;
}
```

**修改后**：
```cpp
DisplayServer::Context context;
if (editor) {
    context = DisplayServer::CONTEXT_EDITOR;
} else {
    context = DisplayServer::CONTEXT_ENGINE;
}
```

### 3.3 第三阶段：条件分支清理

#### 清理模式 1：`editor || project_manager` → `editor`

需要在以下位置修改：
- `main.cpp:2062` - 日志文件设置
- `main.cpp:2100` - 渲染驱动测试
- `main.cpp:2102` - 编辑器提示
- `main.cpp:2275` - 项目路径处理
- `main.cpp:2682` - 文本驱动处理
- `main.cpp:2696` - 项目导入路径
- `main.cpp:2844` - 语言处理
- `main.cpp:2960` - 编辑器路径初始化
- `main.cpp:3210` - 窗口标题扩展
- 更多...

**通用模式**：
```cpp
// 当前
if (editor || project_manager) {
    // editor 特定代码
}

// 修改后
if (editor) {
    // editor 特定代码
}
```

#### 清理模式 2：`!project_manager && !editor` → `!editor`

需要在以下位置修改：
- `main.cpp:2264` - 场景加载
- `main.cpp:3525` - 窗口配置
- `main.cpp:4216` - 启动检查
- `main.cpp:4363` - 窗口模式
- `main.cpp:4490` - 嵌入视口
- `main.cpp:4619` - 场景树配置

**通用模式**：
```cpp
// 当前
if (!editor && !project_manager) {
    // 游戏运行代码
}

// 修改后
if (!editor) {
    // 游戏运行代码
}
```

#### 清理模式 3：条件配置块删除

需要在以下位置删除整个条件块：
- `main.cpp:2156-2161` - 项目管理器提示
- `main.cpp:2593-2597` - 窗口大小（使用 ProjectManager::DEFAULT_WINDOW_WIDTH）
- `main.cpp:3283-3299` - 显示缩放配置
- `main.cpp:3000-3001` - 屏幕属性读取

### 3.4 第四阶段：依赖清理

#### 移除 include

**位置**：`main.cpp:121`

```cpp
// 删除
#include "editor/project_manager/project_manager.h"
```

#### 检查其他依赖

搜索以下内容是否需要调整：
- `ProgressDialog` 的使用（项目管理器创建它）
- 编辑器特定的设置读取
- 启动画面相关代码

---

## 四、影响分析

### 4.1 用户界面的影响

| 功能 | 当前行为 | 移除后行为 |
|------|--------|---------|
| 启动 Godot（无参数） | 打开项目管理器 | 打印错误并退出 |
| `-p` / `--project-manager` | 打开项目管理器 | 参数无效 |
| 无效项目路径 | 进入项目管理器 | 打印错误并退出 |
| 新手用户 | 可视化界面选择项目 | 需要命令行指定项目 |

### 4.2 编译影响

```cpp
// 编译可能需要的调整
#ifdef TOOLS_ENABLED
// 当前：项目管理器与编辑器并存
// 修改后：编辑器模式仅为编辑器

// 需要确保以下仍然编译：
- EditorSettings 读取
- EditorPaths 管理
- 语言和主题处理
- 启动画面显示
```

### 4.3 性能影响

**正面**：
- 减少代码分支
- 减少初始化逻辑
- 更快的启动路径

**负面**：
- 移除便捷用户界面
- 用户需要了解命令行参数

### 4.4 向后兼容性

**破坏性更改**：
- `-p` 和 `--project-manager` 参数将不工作
- 旧脚本可能需要更新

**建议**：
- 在移除前保留参数但标记为过时
- 在帮助文本中提示用户改用其他方式
- 文档更新

---

## 五、实现建议

### 5.1 分阶段实现策略

#### 阶段 1：标记为过时（可选，用于过渡）

```cpp
} else if (arg == "-p" || arg == "--project-manager") {
    OS::get_singleton()->print_warning(
        "The --project-manager parameter is deprecated and will be removed in a future version.\n"
        "Please specify a project path instead.\n");
    project_manager = true;  // 暂时保留功能
}
```

#### 阶段 2：完全移除

按照第二、三阶段的所有修改进行

#### 阶段 3：测试和验证

```bash
# 测试场景 1：指定项目
godot /path/to/project

# 测试场景 2：无参数（应该报错）
godot

# 测试场景 3：编辑器模式
godot --editor /path/to/project

# 测试场景 4：脚本执行
godot script.gd
```

### 5.2 代码审查清单

- [ ] 所有 `project_manager` 变量引用已删除或修改
- [ ] 所有条件分支已调整
- [ ] Include 头文件已删除
- [ ] 命令行参数已移除
- [ ] 错误处理已更新
- [ ] 帮助文本已更新
- [ ] 相关文档已更新
- [ ] 编译通过且无警告
- [ ] 基本功能测试通过
- [ ] 性能测试完成

### 5.3 文件修改顺序建议

为了最小化编译错误，建议按以下顺序修改：

1. **第一步**：移除 include 和变量定义
   - `main.cpp:121` - 移除 include
   - `main.cpp:210` - 删除变量

2. **第二步**：修改启动逻辑
   - `main.cpp:1541` - 移除命令行参数
   - `main.cpp:2000` - 移除互斥检查
   - `main.cpp:2075-2077` - 修改自动启用

3. **第三步**：清理条件分支
   - 批量修改所有 `editor || project_manager` 为 `editor`
   - 批量修改所有 `!editor && !project_manager` 为 `!editor`

4. **第四步**：删除项目管理器创建
   - `main.cpp:4672-4689` - 删除创建块

5. **第五步**：验证编译

---

## 六、风险评估

### 6.1 高风险项

- **项目管理器创建**（4672-4689）
  - 风险：删除主要功能块
  - 缓解：确保完全条件编译在 `#ifdef TOOLS_ENABLED` 内
  - 测试：验证编辑器启动正常

- **自动启用逻辑**（2075-2077）
  - 风险：改变启动流程
  - 缓解：确保有明确的错误消息
  - 测试：测试各种启动场景

### 6.2 中等风险项

- **显示上下文**（3190-3198）
  - 风险：DisplayServer 可能依赖上下文值
  - 缓解：验证 DisplayServer 不使用 CONTEXT_PROJECTMAN
  - 测试：检查显示服务器行为

- **窗口大小配置**（2593-2597）
  - 风险：项目管理器窗口有特定尺寸
  - 缓解：使用编辑器默认尺寸
  - 测试：验证编辑器窗口大小合理

### 6.3 低风险项

- **条件分支修改**（大多数逻辑分支）
  - 风险：最小
  - 验证：编译测试即可

---

## 七、备选方案

### 7.1 完全保留但条件编译

如果希望保留功能但让 rm-editor 分支能够禁用：

```cpp
#ifdef ENABLE_PROJECT_MANAGER
static bool project_manager = false;
#endif

// 在 setup() 中
#ifdef ENABLE_PROJECT_MANAGER
} else if (arg == "-p" || arg == "--project-manager") {
    project_manager = true;
}
#endif

// 在 start() 中
#ifdef ENABLE_PROJECT_MANAGER
if (project_manager) {
    // ... 项目管理器代码
}
#endif
```

**优点**：
- 可在编译时选择启用/禁用
- 容易回滚
- 支持多个版本

**缺点**：
- 代码中包含许多 ifdef
- 增加维护复杂度

### 7.2 使用继承或虚函数

创建启动接口，让项目管理器和编辑器实现共同接口：

```cpp
class ToolInterface {
    virtual void setup() = 0;
    virtual void setup2() = 0;
    virtual int start() = 0;
};

class EditorInterface : public ToolInterface { /* ... */ };
class ProjectManagerInterface : public ToolInterface { /* ... */ };
```

**优点**：
- 高度模块化
- 易于扩展
- 易于维护

**缺点**：
- 需要大规模重构
- 可能影响性能
- 实现复杂

---

## 八、总结建议

### 8.1 推荐方案

**完全移除** + **版本标记** 是最佳方案：

1. **立即执行**（rm-editor 分支）
   - 按照第二阶段的所有修改移除项目管理器
   - 确保编译通过
   - 更新文档说明这是独立构建

2. **主分支策略**（可选）
   - 在官方主分支中暂时保留
   - 标记为"仅在编辑器构建中支持"
   - 后续版本中逐步迁移

### 8.2 实现时间表

- **第 1 天**：分析现有代码，准备修改列表
- **第 2 天**：实施第一、二阶段修改
- **第 3 天**：批量修改条件分支
- **第 4 天**：删除创建块和依赖
- **第 5 天**：编译测试和验证
- **第 6 天**：文档更新和 PR 准备

### 8.3 最小化修改集合

如果只想做最小改动，只需修改以下 5 处：

1. ✅ `main.cpp:121` - 移除 include
2. ✅ `main.cpp:210` - 删除变量
3. ✅ `main.cpp:1541` - 移除参数
4. ✅ `main.cpp:4672-4689` - 删除创建块
5. ✅ `main.cpp:2075-2077` - 处理自动启用

这 5 处修改可以完全禁用项目管理器，其他条件分支虽然冗余但不影响功能。

### 8.4 完整修改集合

为了获得最干净的代码，应该进行所有的条件分支清理（49 处修改都应该处理）。

---

## 九、常见问题与解决方案

### Q1：如果我想快速验证，应该做什么？

**A**：先做最小修改集合（5 处），然后：
1. 编译 rm-editor 版本
2. 测试 `godot --editor /path/to/project` 是否工作
3. 测试 `godot /path/to/project` 是否正常运行

### Q2：完全移除后，用户如何打开项目？

**A**：用户需要：
```bash
# 方式 1：编辑器模式打开
godot --editor /path/to/project

# 方式 2：直接运行游戏
godot /path/to/project

# 方式 3：脚本执行
godot script.gd
```

### Q3：是否可以添加一个简化的项目选择器替代？

**A**：可以，但这是一个独立的功能开发，超出当前范围。建议：
1. 先完成移除
2. 稍后如有需要，可以开发轻量级选择器
3. 与 main.cpp 分离

### Q4：对于 CI/CD 流程有什么影响？

**A**：需要更新脚本：
```bash
# 旧方式（需要改变）
godot --project-manager

# 新方式
godot --editor /path/to/project
```

### Q5：如何处理现有用户的脚本？

**A**：
1. 提前发布公告说明更改
2. 在帮助文本中提示新用法
3. 提供迁移指南

---

## 十、参考资源

### 10.1 相关源文件

- `main/main.cpp` - 主启动文件（需要修改）
- `editor/project_manager/project_manager.h` - 项目管理器头文件
- `editor/project_manager/project_manager.cpp` - 项目管理器实现
- `main/main.h` - 主接口文件

### 10.2 相关类

- `ProjectManager` - 项目管理界面
- `EditorNode` - 编辑器主节点
- `ProgressDialog` - 进度对话框
- `DisplayServer` - 显示服务

### 10.3 编译配置

- `custom.py` - 自定义构建配置
- `SConstruct` - 主构建文件
- `modules.enabled.gen.h` - 模块配置

---

## 结论

移除项目管理器是一个**中等复杂度**的任务，涉及 **49 处代码位置**。建议采用**分阶段方法**，从**最小修改集合**开始逐步扩大。通过系统的方法，可以确保 rm-editor 分支成为一个精简、高效的游戏引擎构建。

关键是**不要盲目删除**，而是**理解依赖关系**后再进行修改。

