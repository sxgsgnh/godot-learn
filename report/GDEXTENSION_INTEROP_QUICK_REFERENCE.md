# GDExtension 跨扩展通信快速参考

**版本**: 1.0
**用途**: 快速查阅常见通信模式和性能数据

---

## 📊 通信方式速查表

### 按性能排序

```
速度排序（从快到慢）:

1️⃣ 原生 C++ 调用
   └─ 直接函数指针调用，无开销

2️⃣ PtrCall (指针调用)
   └─ 无 Variant 转换，20 ns
   └─ 需要提前知道参数类型

3️⃣ MethodBind Call
   └─ Variant 转换，100 ns
   └─ 需要缓存 MethodBind 指针

4️⃣ Variant Call
   └─ 字符串查找 + Variant 转换，500 ns
   └─ 完全通用，易于使用

5️⃣ Signal/Emit
   └─ 消息队列延迟，1000 ns+
   └─ 异步，完全解耦

6️⃣ 消息总线
   └─ 路由 + 序列化，2000 ns+
   └─ 最灵活，最高开销
```

### 按场景选择

| 场景 | 首选 | 次选 | 第三选 |
|------|------|------|--------|
| **热路径 (每帧 1000+ 次)** | PtrCall | MethodBind | - |
| **性能关键 (每帧 100-1000 次)** | MethodBind | Variant Call | - |
| **一般使用 (每秒几次)** | Variant Call | Signal | - |
| **事件通知 (异步)** | Signal | Message Bus | Variant Call |
| **服务发现** | Message Bus | Singleton | - |
| **跨扩展 RPC** | Message Bus | Signal | - |

---

## 🔧 实现代码片段

### 1. Variant 调用 (通用，推荐新手)

```cpp
// 调用某个对象的方法
Object *target = /* 获取对象 */;
String method_name = "some_method";
Variant arg1 = 42;
Variant args[] = {arg1};

Callable::CallError error;
Variant result;
target->callp(method_name, args, 1, result, error);

if (error.error != Callable::CallError::CALL_OK) {
    print_error("Method call failed!");
}
```

**优点**: ✅ 最简单，完全通用
**缺点**: ❌ 性能最差

---

### 2. MethodBind 缓存调用 (推荐一般场景)

```cpp
// 扩展初始化时
static MethodBind *cached_method = nullptr;

void initialize_extension() {
    cached_method = ClassDB::get_method("TargetClass", "method_name");
    if (!cached_method) {
        ERR_PRINT("Method not found!");
    }
}

// 运行时调用 (高频路径)
void call_target() {
    Object *obj = get_target_object();
    Variant arg = 100;
    Variant result;
    Callable::CallError error;

    result = cached_method->call(obj, &arg, 1, error);
}
```

**优点**: ✅ 性能好，易于使用
**缺点**: ❌ 需要提前初始化

---

### 3. PtrCall (性能关键，不推荐新手)

```cpp
// 获取方法指针
static MethodBind *transform_method =
    ClassDB::get_method("Node3D", "set_transform");

// 性能关键路径 (每帧高频)
void update_transforms(const Vector<Transform3D> &transforms) {
    for (const Transform3D &t : transforms) {
        transform_method->ptrcall(
            node,
            (const void **)&t,
            nullptr  // 无返回值
        );
    }
}
```

**优点**: ✅ 最快，最小开销
**缺点**: ❌ 需要知道类型签名，容易出错

---

### 4. 信号通信 (推荐异步事件)

```cpp
// 发送端 (Extension A)
class DataProvider : public Node {
    GDCLASS(DataProvider, Node);

    ADD_SIGNAL(MethodInfo("data_changed", PropertyInfo(Variant::DICTIONARY, "data")));

    void update_data() {
        Dictionary data;
        data["timestamp"] = Time::get_singleton()->get_ticks_msec();
        data["value"] = 42;

        emit_signal("data_changed", data);
    }
};

// 接收端 (Extension B)
void setup() {
    DataProvider *provider = get_provider();
    Callable callback = Callable(this, "_on_data_changed");
    provider->connect("data_changed", callback);
}

void _on_data_changed(Dictionary p_data) {
    print_line("Received data: ", p_data);
}
```

**优点**: ✅ 完全解耦，一对多
**缺点**: ❌ 异步有延迟，参数序列化开销

---

### 5. 服务发现 (推荐全局服务)

```cpp
// 发布服务 (Extension A)
class UserService : public Object {
    GDCLASS(UserService, Object);

    Variant get_user_info(int p_user_id) {
        // 实现
    }
};

void register_services() {
    UserService *service = memnew(UserService);
    Engine::get_singleton()->add_singleton("UserService", service);
}

// 消费服务 (Extension B)
void access_service() {
    Object *service = Engine::get_singleton()
        ->get_singleton_object("UserService");

    Variant user_info = service->callp("get_user_info", &user_id, 1, error);
}
```

**优点**: ✅ 简单直接，全局访问
**缺点**: ❌ 全局状态，难以隔离测试

---

## 📈 性能优化清单

### 🔴 需要优化的迹象

- [ ] 扩展间调用在性能分析中占比 > 5%
- [ ] 每帧有 100+ 次跨扩展方法调用
- [ ] 使用 Variant 调用处理实时数据流
- [ ] 同一方法名被重复查找

### ✅ 优化步骤

1. **识别热路径**
   ```cpp
   // 使用性能分析器确认瓶颈位置
   // 如果 callp() 占用时间 > 5%，需要优化
   ```

2. **缓存 MethodBind**
   ```cpp
   static MethodBind *cached = ClassDB::get_method(...);
   // 改进: 字符串查找从每次变为一次
   ```

3. **批量操作**
   ```cpp
   // ❌ 不好
   for (int i = 0; i < 10000; i++) {
       obj->callp("update", args, 1, result, error);
   }

   // ✅ 好
   Vector<Update> updates;
   for (int i = 0; i < 10000; i++) {
       updates.push_back({...});
   }
   apply_batch(updates);  // 一次性处理
   ```

4. **使用 PtrCall**
   ```cpp
   // ❌ Variant 调用
   Variant result = method->call(obj, args, count, error);

   // ✅ PtrCall
   method->ptrcall(obj, (const void**)args, &result);
   ```

---

## 🛠️ 调试技巧

### 检查方法是否存在

```cpp
if (ClassDB::class_exists("ClassName")) {
    MethodBind *mb = ClassDB::get_method("ClassName", "method_name");
    if (mb) {
        print_line("方法存在");
    } else {
        print_line("方法不存在");
    }
} else {
    print_line("类不存在 - 扩展可能未加载");
}
```

### 获取对象类型

```cpp
// 检查对象的实际类型
Object *obj = /* ... */;
String class_name = obj->get_class();
print_line("Object class: ", class_name);

// 检查继承链
if (obj->is_class("Node")) {
    print_line("这是一个 Node");
}
```

### 追踪方法调用

```cpp
// 添加日志记录
void traced_call(Object *obj, const String &method, const Variant *args, int arg_count) {
    print_line("Calling: ", obj->get_class(), "::", method);

    Callable::CallError error;
    Variant result;
    obj->callp(method, args, arg_count, result, error);

    if (error.error != Callable::CallError::CALL_OK) {
        print_line("  Error: ", error.error, " at arg ", error.argument);
    } else {
        print_line("  Result: ", result);
    }
}
```

---

## ⚠️ 常见陷阱

### 陷阱 1: 访问不存在的对象

```cpp
// ❌ 不安全
Object *obj = /* 可能已删除 */;
obj->callp("method", args, 1, result, error);  // 可能崩溃

// ✅ 安全
if (ObjectDB::instance_validate(obj)) {
    obj->callp("method", args, 1, result, error);
}
```

### 陷阱 2: 参数数量不匹配

```cpp
// ❌ 错误
Variant arg1 = 42;
Variant arg2 = "hello";
Variant args[] = {arg1, arg2};
obj->callp("method_one_arg", args, 2, result, error);
// ↑ 传递了 2 个参数，但方法只要 1 个

// ✅ 正确
Variant args[] = {arg1};
obj->callp("method_one_arg", args, 1, result, error);
```

### 陷阱 3: 在工作线程中调用

```cpp
// ❌ 不安全
WorkerThreadPool::add_task([](Object *obj) {
    obj->callp("method", args, 1, result, error);  // 竞态条件
});

// ✅ 安全
WorkerThreadPool::add_task([](Object *obj) {
    // 延迟到主线程执行
    callable_mp(obj, &Object::callp)
        .call_deferred("method", args);
});
```

### 陷阱 4: 忘记检查错误

```cpp
// ❌ 易出现 bug
obj->callp("method", args, 1, result, error);
print_line("Result: ", result);  // 如果出错，result 可能无效

// ✅ 好的实践
Callable::CallError error;
obj->callp("method", args, 1, result, error);

if (error.error != Callable::CallError::CALL_OK) {
    print_error("Method call failed: ", error.error);
    return;
}
print_line("Result: ", result);
```

---

## 📋 扩展通信检查列表

### 设计阶段

- [ ] 明确各扩展的职责和接口
- [ ] 识别跨扩展依赖关系
- [ ] 确定通信频率 (热路径 vs 冷路径)
- [ ] 选择合适的通信模式
- [ ] 定义错误处理策略

### 实现阶段

- [ ] 实现 ClassDB 注册
- [ ] 缓存热路径的 MethodBind
- [ ] 添加参数验证
- [ ] 实现错误恢复
- [ ] 编写单元测试

### 测试阶段

- [ ] 测试各扩展单独加载
- [ ] 测试各扩展按不同顺序加载
- [ ] 测试一个扩展缺失的情况
- [ ] 性能测试 (基准测试)
- [ ] 压力测试 (大量并发调用)

### 部署阶段

- [ ] 验证依赖文档
- [ ] 提供版本兼容性声明
- [ ] 创建故障排除指南
- [ ] 监控生产环境性能

---

## 🔗 扩展间依赖与头文件引入

### 编译时依赖 (推荐做法)

```cpp
// ❌ 不要这样做
#include "../../extension_a/src/my_class.h"  // 私有头文件

// ✅ 应该这样做: 导出头文件
#include "extension_common/my_class_export.h"
```

### 项目结构

```
common/
├─ include/extension_common/
│  ├─ my_class_api.h          ← 导出的 API 定义
│  └─ common_types.h          ← 共享类型
extension_a/
├─ public/my_class_api.h      ← 声明
├─ src/my_class.cpp           ← 实现
└─ CMakeLists.txt             ← Copy 头文件
extension_b/
├─ src/uses_extension_a.cpp
└─ CMakeLists.txt             ← 链接到 extension_a
```

### .gdextension 依赖声明

```ini
[configuration]
name="ExtensionB"
version="1.2.0"

[dependencies]
ExtensionA=">=1.0,<2.0"
CommonLib="=1.0.*"

[exports]
classes=["NodeB"]
```

### 运行时单例查询

```cpp
// Extension B 使用 Extension A

Object *provider = Engine::get_singleton()
    ->get_singleton_object("DataProviderA");

if (!provider) {
    ERR_PRINT("ExtensionA not loaded!");
    return;
}

// 安全使用
Variant result = provider->callp("get_data", nullptr, 0, error);
```

### 依赖验证

```cpp
// 快速检查依赖是否满足
bool is_ready() {
    // 检查 1: 扩展是否已加载
    GDExtensionManager *manager = GDExtensionManager::get_singleton();
    if (!manager->is_extension_loaded("ExtensionA")) {
        ERR_PRINT("ExtensionA not loaded!");
        return false;
    }

    // 检查 2: 单例是否存在
    Object *obj = Engine::get_singleton()
        ->get_singleton_object("DataProviderA");
    if (!obj) {
        ERR_PRINT("DataProviderA singleton missing!");
        return false;
    }

    return true;
}
```

### 可选依赖处理

```cpp
// 如果 Extension A 不存在也能工作

Object *optional_ext = Engine::get_singleton()
    ->get_singleton_object("OptionalExtension");

if (optional_ext) {
    // ✅ 使用扩展功能
    optional_ext->callp("enable_feature", nullptr, 0, error);
} else {
    // ✅ 回退到默认行为
    use_default_behavior();
}
```

---

## 📚 相关资源

### 源文件

| 文件 | 行数 | 用途 |
|------|------|------|
| `core/extension/gdextension_interface.cpp` | 1872 | 所有接口实现 |
| `core/extension/gdextension_manager.cpp` | 501 | 扩展生命周期管理 |
| `core/object/object.h` | 1140 | Object 类和反射系统 |
| `core/object/class_db.h` | 800+ | ClassDB API |

### API 文档

```
主要接口函数:
├─ gdextension_object_method_bind_call()     // MethodBind 调用
├─ gdextension_variant_call()                // Variant 调用
├─ gdextension_object_call_script_method()   // 脚本方法调用
├─ gdextension_classdb_get_method()          // 获取 MethodBind
├─ gdextension_global_get_singleton()        // 获取全局单例
└─ gdextension_object_get_instance_from_id() // 通过 ID 获取对象
```

---

**快速提示**: 使用此快速参考配合 `GDEXTENSION_INTEROP_ANALYSIS.md` 深度文档

