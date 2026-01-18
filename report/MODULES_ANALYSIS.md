# Godot 引擎 modules 文件夹模块分析

## 概述

Godot 的 `modules` 文件夹包含 60+ 个可选功能模块，这些模块可根据构建需求启用或禁用。每个模块都必须包含以下三个文件：
- `register_types.cpp/.h` - 模块类型注册
- `SCsub` - 构建脚本
- `config.py` - 配置文件

---

## 核心模块

### 1. **gdscript** - GDScript 脚本语言
**路径**: `modules/gdscript/`

**功能**:
- Godot 官方脚本语言实现
- 动态类型，支持可选类型提示（gradually typed）
- 编译为字节码运行在虚拟机中
- 支持语言服务协议 (LSP) 用于编辑器支持

**主要组件**:
- `gdscript_tokenizer.cpp` - 词法分析器
- `gdscript_parser.cpp` - 语法解析器（构建AST）
- `gdscript_analyzer.cpp` - 语义分析
- `gdscript_compiler.cpp` - 字节码编译
- `gdscript_vm.cpp` - 虚拟机（字节码执行器）
- `language_server/` - LSP 实现（依赖 jsonrpc 和 websocket）

**依赖**: jsonrpc, websocket (可选)

---

### 2. **multiplayer** - 多人游戏支持
**路径**: `modules/multiplayer/`

**功能**:
- 多人游戏同步和 RPC 系统
- 高级复制机制（replication）
- 场景自动同步

**主要类**:
- `SceneMultiplayer` - 多人游戏管理器
- `MultiplayerSpawner` - 网络物体生成
- `MultiplayerSynchronizer` - 属性同步
- `SceneReplicationConfig` - 复制配置

**依赖**: 无强制依赖

---

### 3. **navigation_3d** / **navigation_2d** - 寻路导航
**路径**: `modules/navigation_3d/`, `modules/navigation_2d/`

**功能**:
- 3D/2D 导航网格和寻路系统
- AI 角色移动控制
- 基于 Recast Navigation 库

**主要类**:
- `NavAgent3D` - 导航代理
- `NavRegion3D` - 导航区域
- `NavMap3D` - 导航地图
- `NavObstacle3D` - 导航障碍

**依赖**: csg, gridmap (可选)

---

## 3D 功能模块

### 4. **gltf** - glTF 模型导入导出
**路径**: `modules/gltf/`

**功能**:
- 支持 glTF 2.0 格式（.gltf, .glb）
- 3D 模型导入和导出
- 动画、材质、网格数据保留

**架构**:
- `structures/` - glTF 数据结构
- `extensions/` - glTF 扩展支持
- `GLTFState` - 状态容器
- `GLTFDocument` - 核心处理器
- `editor/` - 编辑器集成

**依赖**: csg, gridmap (可选)

---

### 5. **godot_physics_3d** - 3D 物理引擎（内置）
**路径**: `modules/godot_physics_3d/`

**功能**:
- Godot 原生 3D 物理引擎实现
- 刚体动力学、碰撞检测
- 关节、约束系统

---

### 6. **jolt_physics** - Jolt 物理引擎集成
**路径**: `modules/jolt_physics/`

**功能**:
- 集成 Jolt Physics 库（高性能物理）
- 替代方案（非默认）

---

### 7. **gridmap** - 网格地图系统
**路径**: `modules/gridmap/`

**功能**:
- 基于网格的 3D 场景编辑
- 地形、建筑块级设计
- 快速构建工具

---

### 8. **csg** - 构造立体几何
**路径**: `modules/csg/`

**功能**:
- CSG 操作（并、交、差）
- 用于建模复杂 3D 形状
- 编辑器工具

---

### 9. **lightmapper_rd** - 烘焙光照
**路径**: `modules/lightmapper_rd/`

**功能**:
- 离线光照烘焙系统
- GPU 加速计算
- 烘焙纹理生成

---

### 10. **xatlas_unwrap** - UV 展开
**路径**: `modules/xatlas_unwrap/`

**功能**:
- 自动 UV 坐标生成
- 使用 xatlas 库

---

## 图像格式与处理

### 11-20. **图像格式模块**

| 模块 | 功能 |
|------|------|
| **jpg** | JPEG 图像导入 |
| **png** | PNG 图像导入 |
| **webp** | WebP 图像支持 |
| **svg** | SVG 矢量图形 |
| **bmp** | BMP 图像格式 |
| **tga** | TGA 图像格式 |
| **hdr** | HDR 高动态范围图像 |
| **dds** | 直接绘制面（Direct Draw Surface） |
| **tinyexr** | OpenEXR 高级图像格式 |
| **basis_universal** | 通用纹理压缩格式 |
| **astcenc** | ASTC 纹理压缩 |
| **cvtt** | GPU 纹理压缩 |
| **ktx** | Khronos 纹理格式 |
| **etcpak** | ETC 纹理压缩 |
| **msdfgen** | 多通道有向距离场生成 |

---

## 音频格式模块

### 21-24. **音频处理模块**

| 模块 | 功能 |
|------|------|
| **ogg** | Ogg 容器支持 |
| **vorbis** | Ogg Vorbis 音频编解码 |
| **mp3** | MP3 音频解码 |
| **theora** | Theora 视频编解码 |

---

## 网络与通信

### 25. **websocket** - WebSocket 协议
**路径**: `modules/websocket/`

**功能**:
- WebSocket 客户端/服务器实现
- 实时双向通信
- 多人游戏网络基础

**主要类**:
- `WebSocketClient` - 客户端
- `WebSocketServer` - 服务器
- `WebSocketPeer` - 对等连接
- `WebSocketMultiplayerPeer` - 多人集成

---

### 26. **webrtc** - WebRTC 实时通信
**路径**: `modules/webrtc/`

**功能**:
- 实时音视频通信
- P2P 连接
- 多人游戏语音聊天

---

### 27. **upnp** - UPnP 协议
**路径**: `modules/upnp/`

**功能**:
- 自动端口转发
- 网络设备发现

---

### 28. **enet** - ENet 网络库
**路径**: `modules/enet/`

**功能**:
- 可靠 UDP 网络库
- 低延迟多人游戏网络

---

### 29. **jsonrpc** - JSON-RPC 协议
**路径**: `modules/jsonrpc/`

**功能**:
- JSON 远程过程调用
- 用于编辑器 LSP 通信

---

## 文本与字体处理

### 30-31. **文本服务器模块**

| 模块 | 功能 |
|------|------|
| **text_server_adv** | 高级文本处理（HarfBuzz）|
| **text_server_fb** | Fallback 文本服务器 |

---

### 32. **freetype** - 字体渲染
**路径**: `modules/freetype/`

**功能**:
- TrueType/OpenType 字体渲染
- 文本绘制

---

## 脚本与数据处理

### 33. **regex** - 正则表达式
**路径**: `modules/regex/`

**功能**:
- 正则表达式匹配和替换
- 文本处理工具

---

### 34. **fbx** - FBX 模型导入
**路径**: `modules/fbx/`

**功能**:
- Autodesk FBX 格式导入
- 3D 模型和动画

---

## 程序生成与工具

### 35. **noise** - 噪声生成
**路径**: `modules/noise/`

**功能**:
- Perlin, Simplex 等噪声算法
- 程序生成地形、纹理

**主要类**:
- `FastNoiseLite` - 高性能噪声生成器
- `NoiseTexture2D/3D` - 噪声纹理

---

### 36. **vhacd** - 凸分解
**路径**: `modules/vhacd/`

**功能**:
- 非凸形状分解为凸形
- 物理碰撞优化

---

### 37. **meshoptimizer** - 网格优化
**路径**: `modules/meshoptimizer/`

**功能**:
- 3D 网格优化
- 顶点缓存优化、LOD 生成

---

## 虚拟现实与扩展

### 38-39. **VR 模块**

| 模块 | 功能 |
|------|------|
| **openxr** | OpenXR 标准 VR/AR 支持 |
| **webxr** | Web 平台 XR 支持 |
| **mobile_vr** | 移动 VR（Cardboard 等）|

---

## 编辑器与开发工具

### 40. **mono** - C# 支持
**路径**: `modules/mono/`

**功能**:
- C# 脚本语言集成
- .NET 运行时集成

---

### 41. **objectdb_profiler** - 对象数据库分析
**路径**: `modules/objectdb_profiler/`

**功能**:
- 内存对象跟踪
- 性能分析工具

---

## 密码学与安全

### 42. **mbedtls** - TLS/SSL 库
**路径**: `modules/mbedtls/`

**功能**:
- 加密通信支持
- HTTPS, TLS 连接

---

## 数据管理

### 43. **zip** - ZIP 压缩
**路径**: `modules/zip/`

**功能**:
- ZIP 文件打包和解包
- 资源打包

---

### 44. **raycast** - 光线投射
**路径**: `modules/raycast/`

**功能**:
- 物理射线检测
- 玩家输入检测（鼠标点击）

---

## 音乐系统

### 45. **interactive_music** - 交互式音乐
**路径**: `modules/interactive_music/`

**功能**:
- 动态音乐系统
- 音乐切换和过渡

---

## 其他模块

### 46. **betsy**
- 未明确定义的模块

### 47. **bcdec** - BC 纹理解压
- GPU 纹理格式解压

### 48. **camera** - 摄像机模块
**路径**: `modules/camera/`

**功能**:
- 平台摄像头集成
- 实时摄像头捕获

### 49. **glslang** - GLSL 编译
**功能**:
- GLSL 着色器编译
- SPIR-V 生成

---

## 模块依赖关系

```
gdscript
  ├─ jsonrpc (可选) ─┐
  └─ websocket (可选)┼─ LSP 支持
                      │

multiplayer
  ├─ websocket (通常配合)
  └─ jsonrpc (通常配合)

navigation_3d/2d
  ├─ csg (可选)
  └─ gridmap (可选)

gltf
  ├─ csg (可选)
  └─ gridmap (可选)

webrtc
  └─ 依赖平台库

mobile_vr/openxr
  └─ 依赖平台库
```

---

## 构建时配置

### 启用/禁用模块
在编译时通过 SCons 参数控制：
```bash
scons platform=linux target=editor \
  module_gdscript_enabled=yes \
  module_multiplayer_enabled=yes \
  module_csharp_enabled=no
```

### 完全禁用模块类别
```bash
scons disable_3d=True        # 禁用所有 3D 功能
scons disable_navigation_3d  # 禁用 3D 导航
```

---

## 模块构造规范

每个模块必须实现以下接口（在 `config.py`）：

```python
def can_build(env, platform):
    """返回此平台是否可构建此模块"""
    return True

def configure(env):
    """配置编译器标志等"""
    pass

def get_doc_classes():
    """返回模块导出的类列表"""
    return []

def get_doc_path():
    """文档类文件夹路径"""
    return "doc_classes"
```

在 `register_types.cpp` 中注册类型：
```cpp
void register_module_types() {
    GDREGISTER_CLASS(MyClass);
    // ...
}

void unregister_module_types() {
    // 清理代码
}
```

---

## 模块启用配置表

| 模块类别 | 默认启用 | 可选性 | 性能影响 |
|---------|--------|-------|--------|
| gdscript | ✓ | 必须 | 低 |
| multiplayer | ✓ | 可选 | 低 |
| gltf | ✓ | 可选 | 中 |
| navigation_3d | ✓ | 可选 | 中 |
| physics_3d | ✓ | 可选 | 高 |
| jolt_physics | ✗ | 可选 | 高 |
| websocket | ✓ | 可选 | 低 |
| webrtc | ✓ | 可选 | 中 |
| 图像格式 | ✓ | 可选 | 低-中 |
| 文本/字体 | ✓ | 可选 | 中 |
| VR 模块 | ✗ | 可选 | 高 |
| C# (mono) | ✗ | 可选 | 高 |

---

## 总结

Godot 的模块系统提供了高度的灵活性：

1. **核心功能**: gdscript, multiplayer, 物理系统
2. **3D 功能**: gltf, navigation, csg, lightmapper
3. **网络**: websocket, webrtc, enet, upnp
4. **多媒体**: 14+ 图像格式, 4+ 音频格式
5. **工具**: 正则表达式, 网格优化, 纹理压缩
6. **可扩展**: 支持自定义模块

通过选择性启用模块，开发者可以优化引擎大小和性能，使其适应不同的项目需求（从轻量级 2D 游戏到复杂 3D VR 应用）。
