# SCons 构建顺序与依赖关系分析

本文档说明了 Godot 基于 SCons 的构建系统如何驱动编译顺序、源码选取及代码生成。关键组件是顶层的 `SConstruct` 脚本与仓库中散布的各个 `SCsub` 文件。

---

## 1. 高层流程（SConstruct）

1. **环境初始化**
   * 使用 `EnsureSConsVersion` 和 `EnsurePythonVersion` 检查版本要求。
   * 通过 `_helper_module` 加载辅助模块（如 `methods`、`core.core_builders` 等），以避免导入冲突。
   * 平台检测循环遍历 `platform/*/detect.py` 并填充 `platform_list`、`platform_opts`、`platform_flags`、`platform_exporters`、`platform_apis` 等。
   * 使用 `tools=[]` 创建一个 `Environment` (`env`)（后续再添加工具）。在 `env.__class__` 上注入常用辅助方法（例如 `add_source_files`、`CommandNoCache`、`module_add_dependencies` 等）。
   * 用 `Variables` 定义命令行选项 `opts`，控制目标、平台、组件、优化等。
   * 设置全局变量，例如 `env.disabled_modules`、`env.module_version_string` 和 `env.scons_version`。
   * `env.SConsignFile` 配置构建缓存路径。

2. **顶层 `SConscript` 调用**
   选项处理之后按顺序调用以下脚本（参见 `SConstruct` 第 ~1209–1222 行）：
   ```python
   SConscript("core/SCsub")          # 核心引擎代码和第三方
   SConscript("servers/SCsub")       # 音频、渲染、物理等
   SConscript("scene/SCsub")         # 场景系统（节点集合）
   if env.editor_build:
       SConscript("editor/SCsub")    # 编辑器源码和子目录
   SConscript("drivers/SCsub")       # 平台驱动（alsa、sdl...）
   SConscript("platform/SCsub")      # 共享平台辅助/图标/API
   SConscript("modules/SCsub")       # 内置和自定义模块
   if env.tests:
       SConscript("tests/SCsub")     # 引擎单元测试
   SConscript("main/SCsub")          # 入口、启动图/图标生成
   SConscript("platform/" + env["platform"] + "/SCsub")  # 目标平台特定代码
   ```
   每个 `SConscript` 按顺序评估，其动作（源列表、命令、库声明）都会加入全局依赖图。

3. **依赖图**
   * 使用 `env.Add_source_files` 将 `.cpp` 文件和生成源收集到如 `env.core_sources` 或 `env.editor_sources` 等列表中。
   * 代码生成规则 (`env.CommandNoCache`) 在引用之前创建头文件/CPP 文件。它们会在声明后立即添加到相应的源列表，确保 SCons 在编译之前安排它们。
   * `env.Depends` 和 `env.Prepend(LIBS=...)` 将库连接在一起；链接器参数的顺序反映了 `Prepend` 调用的顺序（例如 core 首先，然后是 servers 等）。
   * 需要局部变量时使用 `env.Clone()`（例如每个模块或组件的标志），不会影响父环境。
   * SCons 使用文件时间戳与生成的图自动决定构建顺序；`SConscript` 调用的顺序仅影响节点被*创建*的顺序，而非最终执行顺序。

---

## 2. 主要根目录 `SCsub` 文件

### 2.1 `core/SCsub`
* 初始化 `env.core_sources` 和用于捆绑库的列表 `thirdparty_obj`。
* 克隆环境为 `env_thirdparty`，禁用编译器警告并用于编译外部代码。
* 根据配置选项（例如 `env["builtin_zlib"]`）有条件地添加 misc、Brotli、Clipper2、zlib、minizip、zstd 等。
* 使用 `CommandNoCache` 生成若干虚拟头文件：
  - `disabled_classes.gen.h`
  - `version_generated.gen.h` 和 `version_hash.gen.cpp`
  - `script_encryption_key.gen.cpp`（若提供 AES 密钥）
  - 证书、作者、捐赠者、许可证头
* 通过更多 `SConscript` 调用链接到子文件夹（`profiling`、`os`、`math`、`crypto` 等），最终构建静态库 `core`。
* `Depends(lib, thirdparty_obj)` 保证第三方代码更新时 core 重新构建。

### 2.2 `editor/SCsub`
* 仅在构建编辑器（`env.editor_build`）时执行。
* 生成文档类路径、导出器注册代码、翻译源和压缩文档头。
* 将所有 `.cpp` 源和生成文件加入 `env.editor_sources`。
* 为每个编辑器子组件（animation、audio、gui 等）调用 `SConscript`。
* 构建静态库 `editor` 并将其 prepend 到 `LIBS`。

### 2.3 `main/SCsub`
* 将环境克隆为 `env_main`。
* 添加基础引擎源文件，并使用 `main_builders` 生成启动画面、编辑器启动画面（可选）和应用图标头。
* 创建程序入口库 `libmain`。

### 2.4 `modules/SCsub`
* 将环境克隆为 `env_modules` 并为模块源码定义 `GODOT_MODULE`。
* 导出 `env_modules`，以便单个模块的 `SCsub` 导入。
* 生成 `modules_enabled.gen.h` 和 `register_module_types.gen.cpp`。
* 遍历 `env.module_list`（此前由 `modules/*/SCsub` 和自定义路径填充）：
  * 清空 `env.modules_sources` 并调用每个模块的 `SCsub`。
  * 若找到源，则构建 `libmodule_<name>.a` 并 prepend 到 `LIBS`。
  * 当启用测试时，收集 `modules/*/tests` 中的头以生成 `modules_tests.gen.h`。
* 最后创建一个仅包含注册代码的 `modules` 桩库，确保所有模块库先定义。

### 2.5 `servers/SCsub`
* 定义 `env.servers_sources` 并添加核心 `register_server_types.cpp`。
* 为每种服务器类型调用子脚本：音频、渲染、物理、导航、XR 等。
* 链接组合后的 `servers` 静态库并将其加入 `LIBS`。

### 2.6 `scene/SCsub`（上文未展开——类似于 servers；详见文件）
* 收集与场景相关的源和子目录。

### 2.7 `drivers/SCsub` / `platform/SCsub`
* `drivers/SCsub` 处理底层驱动（SDL、ALSA 等）。
* `platform/SCsub` 生成导出图标和平台 API 注册代码，构建 `platform` 库。

### 2.8 `tests/SCsub`
* 构建 `libtests`，调整 doctest 配置并包含任何测试 `.cpp` 文件。

---

## 3. 代码生成顺序

大多数生成文件在相应 `SCsub` 中较早创建：
1. 脚本使用 `env.CommandNoCache` 声明命令，输入为纹理、XML 文件、符号列表等，并使用 `_builders` 模块中的生成函数。
2. 返回的目标立即添加到组件的源列表中，确保它们一旦存在就被编译。
3. 通过 `env.Value` 包装生成文件与触发它们的列表/值之间的依赖，例如 `env.Value(env.disabled_classes)`。
4. 某些情况下（核心第三方对象）手动添加 `env.Depends` 将代码生成与重建连接。

由于 SCons 构建有向无环图（DAG），这些生成步骤在任何依赖它们的对象文件或库之前调度。例如，`disabled_classes.gen.h` 在包含它的任何 `.cpp` 之前构建。

---

## 4. 链接顺序与库依赖

库由 `env.add_library` 构建并放入 `env.Prepend(LIBS=…)`。`Prepend` 的调用顺序决定最终链接器命令的顺序。典型序列为：

```
core -> servers -> scene -> editor? -> drivers -> platform -> module_<name>... -> modules -> tests -> main
```

平台特定库由 `SConstruct` 最终的 `SConscript` 调用追加到主树之后。

---

## 5. 总结

要理解或修改构建顺序，请检查顶层 `SConstruct` 和相关组件的 `SCsub`。每个 `SCsub`：
* 如需独立配置则克隆环境
* 将源码收集到组件特定列表
* 用 `CommandNoCache` 将任何生成输出加入该列表
* 调用进一步的 `SConscript` 文件处理嵌套目录
* 创建库并添加到全局 `LIBS` 列表

SCons 自动管理调度；仓库结构和 `SConscript` 调用顺序定义了依赖图。代码生成规则与源码收集交织，确保生成的头和 cpp 文件在编译前出现。

---

*文档生成于 2026‑02‑25。*
