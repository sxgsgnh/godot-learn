# Godot 渲染系统与渲染管线深度分析

## 目录
1. [渲染系统架构](#渲染系统架构)
2. [渲染管线流程](#渲染管线流程)
3. [2D 批处理渲染机制](#2d-批处理渲染机制)
4. [不同渲染器的批处理实现](#不同渲染器的批处理实现)
5. [Mobile 渲染器批处理优化](#mobile-渲染器批处理优化)
6. [Forward+ 渲染器批处理优化](#forward-渲染器批处理优化)
7. [UI 渲染加速方案](#ui-渲染加速方案)

---

## 渲染系统架构

### 1. 整体架构（RenderingServer）

```
┌─────────────────────────────────────────────────────┐
│         RenderingServer (rendering_server.cpp)      │
│  高层 API：canvas_item_add_rect, canvas_item_draw   │
└─────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Canvas Cull  │  │ Scene Cull   │  │ Compositor  │
│ (2D Culling) │  │ (3D Culling) │  │ (Post-fx)   │
└──────────────┘  └──────────────┘  └──────────────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                           ▼
            ┌─────────────────────────────┐
            │  Renderer (RenderingMethod)  │
            │  - RD (Rendering Device)    │
            │  - Vulkan/D3D12/GL Backend  │
            └─────────────────────────────┘
```

### 2. 2D 渲染路径关键组件

| 组件 | 文件 | 功能 |
|------|------|------|
| **Canvas Cull** | `renderer_canvas_cull.cpp` | 2D 项目裁剪、排序 |
| **Canvas Render** | `renderer_canvas_render.cpp` | 2D 渲染接口基类 |
| **RD Canvas Render** | `renderer_rd/renderer_canvas_render_rd.cpp` | Vulkan 后端 2D 渲染实现 |
| **GLES3 Canvas** | `drivers/gles3/rasterizer_canvas_gles3.cpp` | OpenGL 后端 2D 渲染 |
| **Canvas Item** | `scene/main/canvas_item.cpp` | 场景树中的 2D 节点 |

---

## 渲染管线流程

### 2D 渲染完整流程

```
1. 帧更新 (Frame Update)
   ↓
2. 相机与视口设置
   ├─ 设置投影矩阵
   ├─ 设置视口裁剪
   └─ 设置画布变换
   ↓
3. 光源管理
   ├─ 更新光源位置和参数
   ├─ 更新阴影图（如果需要）
   └─ 更新光照缓冲区
   ↓
4. 项目收集与排序 (canvas_render_items)
   ├─ 遍历 Item 链表
   ├─ 按 z_index 排序
   ├─ 执行裁剪测试（AABB）
   ├─ 分离 Canvas Groups
   └─ 收集 MAX_RENDER_ITEMS（256*1024）个项目到 items[] 数组
   ↓
5. 批处理记录 (_render_batch_items)
   ├─ 遍历项目列表
   ├─ 按材质/剪辑/纹理分组
   ├─ 创建 Batch 对象
   ├─ 生成 InstanceData（128 字节/项）
   └─ 填充批处理缓冲区
   ↓
6. 渲染执行
   ├─ 绑定渲染管线 (RenderPipeline)
   ├─ 绑定着色器
   ├─ 绑定制服缓冲区 (UBO)
   ├─ 绑定实例数据缓冲区 (SSBO/顶点缓冲)
   ├─ 设置 Push Constant
   └─ Draw Call（instanced）
   ↓
7. 后处理
   ├─ 生成 SDF 纹理（如需要）
   ├─ Canvas Group 合并
   └─ 反向屏幕缓冲区处理
```

---

## 2D 批处理渲染机制

### 核心数据结构

#### 1. InstanceData（128 字节）
```cpp
struct InstanceData {
    float world[6];              // 2x3 变换矩阵
    float ninepatch_pixel_size[2]; // NinePatch 像素大小

    union {
        // RECT 模式
        struct {
            float modulation[4];      // 颜色调制
            float ninepatch_margins[4]; // NP 边距
            float dst_rect[4];        // 目标矩形
            float src_rect[4];        // 源矩形
            float pad[2];
        };
        // PRIMITIVE 模式
        struct {
            float points[6];   // 三个顶点（vec2）
            float uvs[6];      // 三个 UV（vec2）
            uint32_t colors[6]; // 压缩颜色
        };
    };

    uint32_t flags;              // 标志位（光照数量、裁剪、MSDF等）
    uint32_t instance_uniforms_ofs; // 自定义 Uniform 偏移
    uint32_t lights[4];          // 光源索引数组
};

static_assert(sizeof(InstanceData) == 128, "..."); // 验证大小
```

**为什么是 128 字节？**
- GPU 内存对齐优化（16 字节对齐的 8 倍）
- 顶点属性分 8 个 16 字节块传输
- 标准化性能基准

#### 2. Batch 结构
```cpp
struct Batch {
    uint32_t start;              // 实例缓冲区起始索引
    uint32_t instance_count;     // 实例数量
    RID instance_buffer;         // 实例缓冲区 RID
    InstanceData push_data;      // 单实例时的推送常数

    TextureInfo *tex_info;       // 纹理状态
    Color modulate;              // 色调
    float msdf_pix_range;        // MSDF 像素范围

    Item *clip;                  // 剪辑所有者
    RID material;                // 材质 RID
    CanvasMaterialData *material_data; // 材质数据

    const Item::Command *command; // 命令指针
    Item::Command::Type command_type; // 命令类型
    ShaderVariant shader_variant; // 着色器变体
    RD::RenderPrimitive render_primitive; // 图元类型
    bool use_lighting;
    bool use_msdf;
    bool use_lcd;
    bool has_blend;
};
```

#### 3. TextureState（批处理分割点）
```cpp
struct TextureState {
    RID texture;              // 纹理 RID
    uint32_t other = 0;       // 编码的附加状态

    // Bit 布局
    // [2:0]   - FILTER (3 bits)
    // [4:3]   - REPEAT (2 bits)
    // [5]     - TEXTURE_IS_DATA (1 bit)
    // [6]     - LINEAR_COLORS (1 bit)

    // 重载运算符支持 HashMap<TextureState, ...>
    bool operator==(const TextureState &p_val) const;
    uint32_t hash() const;
};
```

**批处理分割条件：**
1. 纹理变化
2. 材质变化
3. 剪辑矩形变化
4. 混合模式变化
5. 着色器变体变化

---

### 批处理流程详解

#### 第一步：项目收集 (`canvas_render_items`)

```cpp
void RendererCanvasRenderRD::canvas_render_items(
    RID p_to_render_target,
    Item *p_item_list,
    const Color &p_modulate,
    Light *p_light_list,
    Light *p_directional_light_list,
    const Transform2D &p_canvas_transform,
    RenderingServer::CanvasItemTextureFilter p_default_filter,
    RenderingServer::CanvasItemTextureRepeat p_default_repeat,
    bool p_snap_2d_vertices_to_pixel,
    bool &r_sdf_used,
    RenderingMethod::RenderInfo *r_render_info)
{
    // 1. 初始化
    item_count = 0;
    Transform2D canvas_transform_inverse = p_canvas_transform.affine_inverse();

    // 2. 预处理光源（更新光照缓冲区）
    _update_lights_to_buffer(p_light_list, p_directional_light_list);

    // 3. 更新画布状态缓冲区（变换、模式等）
    _update_canvas_state_buffer(p_to_render_target, p_canvas_transform);

    // 4. 遍历项目链表
    Item *ci = p_item_list;
    while (ci) {
        // Canvas Group 处理
        if (ci->canvas_group_owner != nullptr) {
            // 在 Canvas Group 开始前渲染已收集的项目
            _render_batch_items(to_render_target, item_count,
                              canvas_transform_inverse, p_light_list,
                              r_sdf_used, false, r_render_info);
            item_count = 0;

            // 特殊处理 Canvas Group
            // ...
        }

        // 收集项目
        items[item_count++] = ci;

        // 如果缓冲区满或项目链表结束，渲染批处理
        if (!ci->next || item_count == MAX_RENDER_ITEMS - 1) {
            _render_batch_items(to_render_target, item_count,
                              canvas_transform_inverse, p_light_list,
                              r_sdf_used, canvas_group_owner != nullptr,
                              r_render_info);
            item_count = 0;
        }

        ci = ci->next;
    }
}
```

#### 第二步：批处理记录 (`_render_batch_items`)

```cpp
void RendererCanvasRenderRD::_render_batch_items(
    RenderTarget p_to_render_target,
    int p_item_count,
    const Transform2D &p_canvas_transform_inverse,
    Light *p_lights,
    bool &r_sdf_used,
    bool p_to_backbuffer,
    RenderingMethod::RenderInfo *r_render_info)
{
    // 1. 创建批处理
    bool batch_broken = false;
    Batch *current_batch = _new_batch(batch_broken);

    // 2. 迭代项目
    for (int i = 0; i < p_item_count; i++) {
        const Item *ci = items[i];

        // 2.1 检查剪辑变化
        if (ci->final_clip_owner != current_batch->clip) {
            current_batch = _new_batch(batch_broken);
            current_batch->clip = ci->final_clip_owner;
        }

        // 2.2 获取材质
        RID material = ci->material_owner == nullptr ?
                       ci->material : ci->material_owner->material;
        CanvasMaterialData *material_data =
            material_storage->material_get_data(material);

        // 2.3 检查材质变化
        if (material != current_batch->material) {
            current_batch = _new_batch(batch_broken);
            current_batch->material = material;
            current_batch->material_data = material_data;
        }

        // 2.4 记录项目命令
        _record_item_commands(ci, p_to_render_target, base_transform,
                            current_clip, p_lights, batch_broken,
                            r_sdf_used, current_batch);
    }

    // 3. 执行渲染
    _render_batches(p_to_render_target, p_canvas_transform_inverse,
                   p_lights, r_sdf_used, p_to_backbuffer, r_render_info);
}
```

#### 第三步：命令记录 (`_record_item_commands`)

```cpp
void RendererCanvasRenderRD::_record_item_commands(
    const Item *p_item,
    RenderTarget p_render_target,
    const Transform2D &p_base_transform,
    Item *p_clip,
    Light *p_lights,
    bool &r_batch_broken,
    bool &r_sdf_used,
    Batch *p_batch)
{
    const Item::Command *c = p_item->commands;

    while (c) {
        switch (c->type) {
            case Item::Command::TYPE_RECT: {
                const Item::CommandRect *rect =
                    (const Item::CommandRect *)c;
                _record_rect_command(rect, p_item, p_batch);
                break;
            }
            case Item::Command::TYPE_NINEPATCH: {
                const Item::CommandNinePatch *np =
                    (const Item::CommandNinePatch *)c;
                _record_ninepatch_command(np, p_item, p_batch);
                break;
            }
            case Item::Command::TYPE_POLYGON: {
                const Item::CommandPolygon *poly =
                    (const Item::CommandPolygon *)c;
                _record_polygon_command(poly, p_item, p_batch);
                break;
            }
            case Item::Command::TYPE_PRIMITIVE: {
                const Item::CommandPrimitive *prim =
                    (const Item::CommandPrimitive *)c;
                _record_primitive_command(prim, p_item, p_batch);
                break;
            }
            // ... 其他命令类型
        }
        c = c->next;
    }
}
```

#### 第四步：实例数据生成与渲染

```cpp
// 填充 InstanceData
void _add_instance_to_batch(
    Batch *p_batch,
    const Item *p_item,
    const Transform2D &p_transform,
    const Color &p_modulation,
    const Rect2 &p_dst_rect,
    const Rect2 &p_src_rect)
{
    // 获取或分配实例缓冲区
    if (state.instance_data_index >= state.max_instances_per_buffer) {
        // 分配新缓冲区
        RID new_buffer = RD::get_singleton()->storage_buffer_create(
            state.max_instance_buffer_size);
        state.instance_buffers.push_back(new_buffer);
        state.instance_data = nullptr;
        state.instance_data_index = 0;
    }

    // 获取 InstanceData 指针
    if (!state.instance_data) {
        state.instance_data = (InstanceData *)RD::get_singleton()
            ->buffer_get_data(state.instance_buffers[state.current_buffer])
            .ptrw();
    }

    InstanceData &idata = state.instance_data[state.instance_data_index];

    // 填充变换（2x3 矩阵）
    Transform2D final_xform = p_transform;
    _update_transform_2d_to_mat2x3(final_xform, idata.world);

    // 填充矩形信息
    idata.dst_rect[0] = p_dst_rect.position.x;
    idata.dst_rect[1] = p_dst_rect.position.y;
    idata.dst_rect[2] = p_dst_rect.size.x;
    idata.dst_rect[3] = p_dst_rect.size.y;

    // 填充源矩形（UV）
    idata.src_rect[0] = p_src_rect.position.x;
    idata.src_rect[1] = p_src_rect.position.y;
    idata.src_rect[2] = p_src_rect.size.x;
    idata.src_rect[3] = p_src_rect.size.y;

    // 填充调制颜色
    idata.modulation[0] = p_modulation.r;
    idata.modulation[1] = p_modulation.g;
    idata.modulation[2] = p_modulation.b;
    idata.modulation[3] = p_modulation.a;

    // 填充标志位
    idata.flags = 0;
    if (/* 使用裁剪 */) {
        idata.flags |= INSTANCE_FLAGS_CLIP_RECT_UV;
    }
    if (/* 使用 MSDF */) {
        idata.flags |= INSTANCE_FLAGS_NINEPACH_DRAW_CENTER;
    }

    // 填充光源
    int light_count = 0;
    Light *light = p_lights;
    while (light && light_count < MAX_LIGHTS_PER_ITEM) {
        idata.lights[light_count] = light->render_index_cache;
        light_count++;
        light = light->next_ptr;
    }
    idata.flags |= light_count << INSTANCE_FLAGS_LIGHT_COUNT_SHIFT;

    // 递增索引
    state.instance_data_index++;
    p_batch->instance_count++;
}

// 执行 Draw Call
void _render_batches(
    RenderTarget p_to_render_target,
    const Transform2D &p_canvas_transform_inverse,
    Light *p_lights,
    bool &r_sdf_used,
    bool p_to_backbuffer,
    RenderingMethod::RenderInfo *r_render_info)
{
    RD::DrawListID draw_list = RD::get_singleton()
        ->draw_list_begin(framebuffer);

    for (Batch &batch : state.canvas_instance_batches) {
        // 绑定材质 uniform set
        RD::get_singleton()->draw_list_bind_uniform_set(
            draw_list, batch.material_data->uniform_set,
            MATERIAL_UNIFORM_SET);

        // 绑定纹理 uniform set（批处理缓存）
        RID tex_uniform_set = _get_or_create_texture_uniform_set(
            batch.tex_info);
        RD::get_singleton()->draw_list_bind_uniform_set(
            draw_list, tex_uniform_set, BATCH_UNIFORM_SET);

        // 绑定实例缓冲区
        RD::get_singleton()->draw_list_bind_vertex_buffer(
            draw_list, 0, batch.instance_buffer, 0);

        // 设置 Push Constant
        PushConstant pc = batch.push_constant();
        RD::get_singleton()->draw_list_set_push_constant(
            draw_list, &pc, sizeof(PushConstant));

        // Draw Call（实例化）
        if (batch.instance_count > 0) {
            // 选择着色器变体
            RID pipeline = _get_pipeline(batch.shader_variant,
                                        batch.render_primitive);

            RD::get_singleton()->draw_list_bind_render_pipeline(
                draw_list, pipeline);

            RD::get_singleton()->draw_list_draw(
                draw_list,
                false,  // indexed
                batch.instance_count);  // instance_count

            if (r_render_info) {
                r_render_info->draw_call_count++;
                r_render_info->instance_count += batch.instance_count;
            }
        }
    }

    RD::get_singleton()->draw_list_end();
}
```

---

## 不同渲染器的批处理实现

### 1. RenderingDevice（Vulkan/D3D12 后端）- `renderer_canvas_render_rd.cpp`

**优势：**
- ✅ 实例化渲染（Instanced Rendering）
- ✅ 动态统一缓冲区（UMA）
- ✅ 推送常数优化
- ✅ 三重缓冲（Triple Buffering）
- ✅ Pipeline 缓存

**关键优化：**

```cpp
// 1. 多实例缓冲区（避免大分配）
state.instance_buffers._get(current_buffer);  // Ring Buffer
state.max_instances_per_buffer =
    GLOBAL_GET("rendering/2d/batching/item_buffer_size");

// 2. Uniform Set 缓存（LRU）
typedef LRUCache<RIDSetKey, RID> RIDCache;
RIDCache rid_set_to_uniform_set;  // 缓存纹理 uniform set
uint32_t cache_size = GLOBAL_GET("rendering/2d/batching/uniform_set_cache_size");

// 3. Pipeline 缓存
PipelineHashMapRD<PipelineKey, CanvasShaderData, ...> pipeline_hash_map;

// 4. Push Constant（小数据高效）
struct PushConstant {
    ShaderSpecialization shader_specialization;
    uint32_t specular_shininess;
    uint32_t batch_flags;
    float msdf[2];
    float color_texture_pixel_size[2];
};
```

**配置参数：**
```
rendering/2d/batching/uniform_set_cache_size = 8192
rendering/2d/batching/item_buffer_size = 16384
```

### 2. GLES3 渲染器 - `drivers/gles3/rasterizer_canvas_gles3.cpp`

**特点：**
- 使用 Vertex Buffer Object (VBO) 进行实例化
- 依赖 GL_ARB_instanced_arrays 扩展
- 受限于 OpenGL 最大制服块大小（64 KB）
- 更简单的状态管理

**批处理方式：**
```cpp
// GLES3 中的实例化
glBindVertexArray(quad_vertex_array);
glBindBuffer(GL_ARRAY_BUFFER, instance_buffer);

// 动态缓冲区更新
glBufferSubData(GL_COPY_WRITE_BUFFER, offset, size, instance_data);

// 实例化绘制
glDrawElementsInstanced(GL_TRIANGLES, index_count,
                       GL_UNSIGNED_SHORT, nullptr, instance_count);
```

### 3. 兼容性渲染器 - `renderer_rd/forward_mobile/` 和 `forward_clustered/`

**Mobile 渲染器特性：**
- 简化的光照管线
- 降低内存带宽占用
- Tile-Based Deferred (TBD) 优化
- 减少 Overdraw

**Forward+ 渲染器特性：**
- 聚类光照（Clustered Lighting）
- 高效的多光源支持
- 适合桌面端

---

## Mobile 渲染器批处理优化

### 当前状态分析

**Mobile 渲染器 (`forward_mobile/render_forward_mobile.cpp`) 存在的问题：**

1. **UI 渲染性能瓶颈：**
   - 场景和 UI 共享同一渲染管线
   - UI 项目没有专门的批处理优化
   - 频繁的状态切换导致过多 Draw Call

2. **影响因素：**
   - 大量 UI 元素时，Draw Call 数量激增
   - 内存带宽不足（移动设备）
   - GPU 指令缓冲区限制

### 优化方案：Mobile 2D UI 专用批处理

#### 方案 1：在 Mobile 渲染器中增加 UI 批处理通道

**文件修改：** `servers/rendering/renderer_rd/forward_mobile/render_forward_mobile.cpp`

```cpp
class RenderForwardMobile : public RendererSceneRenderRD {
private:
    struct UI_BatchState {
        LocalVector<UI_Batch> ui_batches;
        LocalVector<InstanceData> ui_instance_data;
        RID ui_instance_buffer;
        RID ui_framebuffer;
        uint32_t ui_draw_call_count = 0;
    };

    UI_BatchState ui_batch_state;

    // UI 特定配置
    static const uint32_t UI_MAX_INSTANCES = 4096;  // 相对 3D 较小
    static const uint32_t UI_BATCH_TIMEOUT_MS = 2;  // 及时更新

public:
    void _prepare_ui_batch_rendering() {
        // 1. 分离 UI 层
        uint32_t ui_layer_mask = 0xFFFFFFFF;  // 配置哪些层是 UI

        // 2. 预分配缓冲区
        if (ui_batch_state.ui_instance_buffer.is_null()) {
            ui_batch_state.ui_instance_buffer =
                RD::get_singleton()->storage_buffer_create(
                    UI_MAX_INSTANCES * sizeof(InstanceData));
        }

        // 3. 收集 UI 项目到专用队列
        _collect_ui_items(p_cull_result, ui_layer_mask);

        // 4. 创建优化的批处理
        _create_ui_batches();
    }

    void _collect_ui_items(RenderDataRD *p_render_data,
                          uint32_t p_layer_mask) {
        ui_batch_state.ui_batches.clear();
        ui_batch_state.ui_instance_data.clear();

        for (GeometryInstance *gi : p_render_data->instances) {
            if (!(gi->layer_mask & p_layer_mask)) continue;

            // 检查是否为 UI 材质
            if (!_is_ui_material(gi->material)) continue;

            // 收集实例数据
            InstanceData idata = _create_instance_data_from_geometry(gi);
            ui_batch_state.ui_instance_data.push_back(idata);
        }
    }

    void _create_ui_batches() {
        // 按材质和纹理分组
        HashMap<TextureState, LocalVector<uint32_t>> texture_groups;

        for (uint32_t i = 0; i < ui_batch_state.ui_instance_data.size(); i++) {
            InstanceData &idata = ui_batch_state.ui_instance_data[i];
            TextureState state = _get_texture_state_from_instance(idata);
            texture_groups[state].push_back(i);
        }

        // 为每个纹理组创建批处理
        for (auto &group : texture_groups) {
            UI_Batch batch;
            batch.texture_state = group.key;
            batch.start = group.value[0];
            batch.instance_count = group.value.size();
            ui_batch_state.ui_batches.push_back(batch);
        }
    }

    void _render_ui_batches(RD::DrawListID p_draw_list) {
        // 上传实例数据到 GPU
        RD::get_singleton()->buffer_update(
            ui_batch_state.ui_instance_buffer, 0,
            ui_batch_state.ui_instance_data.size() * sizeof(InstanceData),
            ui_batch_state.ui_instance_data.ptr());

        // 绑定 UI 专用管线
        RID ui_pipeline = _get_ui_pipeline();
        RD::get_singleton()->draw_list_bind_render_pipeline(
            p_draw_list, ui_pipeline);

        // 绑定实例缓冲区
        RD::get_singleton()->draw_list_bind_vertex_buffer(
            p_draw_list, 0, ui_batch_state.ui_instance_buffer, 0);

        // 执行批处理
        for (const UI_Batch &batch : ui_batch_state.ui_batches) {
            // 更新纹理采样器
            _update_ui_texture_set(batch.texture_state);

            // Draw Call
            RD::get_singleton()->draw_list_draw(
                p_draw_list, false, batch.instance_count);

            ui_batch_state.ui_draw_call_count++;
        }
    }
};
```

#### 方案 2：UI 批处理的着色器变体

**文件修改：** `servers/rendering/renderer_rd/shaders/scene_forward_mobile.glsl`

```glsl
#version 450

// UI 渲染优化的着色器

#ifdef UI_BATCH_VARIANT

layout(location = 0) in VS_OUTPUT {
    vec2 uv;
    vec4 color;
    flat uint material_flags;
} vs_out;

layout(set = 0, binding = 0) uniform CameraData {
    mat4 projection;
    mat4 view;
    vec2 screen_size;
} camera;

layout(set = 1, binding = 0) uniform sampler2D ui_atlases[16];

void main() {
    // 高效的 UI 采样和混合
    uint atlas_index = (vs_out.material_flags >> 0) & 0xF;
    uint blend_mode = (vs_out.material_flags >> 4) & 0x3;

    vec4 color = vs_out.color;
    vec4 tex_color = texture(ui_atlases[atlas_index], vs_out.uv);

    // 预乘 alpha（针对移动设备优化）
    if (blend_mode == 0) { // Alpha blend
        color = vec4(
            mix(tex_color.rgb, color.rgb, tex_color.a),
            max(tex_color.a, color.a)
        );
    } else if (blend_mode == 1) { // Additive
        color = tex_color + color;
    } else if (blend_mode == 2) { // Multiply
        color = tex_color * color;
    }

    FragColor = color;
}

#endif // UI_BATCH_VARIANT
```

#### 方案 3：配置优化参数

```ini
# project.godot

[rendering/2d/mobile]
# UI 批处理参数
ui_batching_enabled = true
ui_max_instances_per_buffer = 4096
ui_batch_timeout_ms = 2

# Mobile 特定优化
tile_size = 128
max_lights_per_cluster = 8
use_depth_prepass = false
```

---

## Forward+ 渲染器批处理优化

### 当前状态分析

**Forward+ 渲染器 (`forward_clustered/render_forward_clustered.cpp`) 特性：**
- 聚类光照（Clustered Rendering）
- 每个集群包含光源列表
- 适合多光源场景
- 相对 Mobile 更消耗性能

### UI 批处理融合方案

#### 方案：集群感知的 UI 批处理

**文件修改：** `servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp`

```cpp
class RenderForwardClustered : public RendererSceneRenderRD {
private:
    struct ClusteredUIBatch {
        // 聚类信息
        uint32_t cluster_index;
        LocalVector<uint32_t> light_indices;

        // 批处理信息
        uint32_t instance_start;
        uint32_t instance_count;
        TextureState texture_state;
        RID material;

        // 性能跟踪
        float avg_screen_size;
        uint32_t frame_count;
    };

    LocalVector<ClusteredUIBatch> clustered_ui_batches;
    HashMap<uint32_t, LocalVector<ClusteredUIBatch*>> cluster_to_batches;

    // 聚类 UI 着色器
    RID clustered_ui_shader;

public:
    void _prepare_clustered_ui_batches(RenderDataRD *p_render_data) {
        // 1. 重新聚类 UI 项目
        cluster_to_batches.clear();
        clustered_ui_batches.clear();

        for (GeometryInstance *gi : p_render_data->ui_instances) {
            // 计算 UI 元素所在的集群
            uint32_t cluster_idx = _compute_ui_cluster_index(gi);

            // 获取影响该集群的光源
            LocalVector<uint32_t> affecting_lights =
                cluster_render_data[cluster_idx].lights;

            // 创建或更新批处理
            ClusteredUIBatch *batch = _get_or_create_ui_batch(
                gi, cluster_idx, affecting_lights);

            cluster_to_batches[cluster_idx].push_back(batch);
        }

        // 2. 按集群顺序排列批处理（改进缓存局部性）
        _optimize_batch_order_by_cluster();
    }

    uint32_t _compute_ui_cluster_index(GeometryInstance *p_instance) {
        // UI 项目使用屏幕空间聚类
        Vector3 screen_pos = camera_projection.xform(
            camera_transform.xform_inv(p_instance->transform.origin));

        // 投影到聚类网格
        uint32_t cluster_x = clamp((uint32_t)(screen_pos.x / cluster_width),
                                   0u, CLUSTER_COUNT_X - 1);
        uint32_t cluster_y = clamp((uint32_t)(screen_pos.y / cluster_height),
                                   0u, CLUSTER_COUNT_Y - 1);
        uint32_t cluster_z = 0;  // UI 在最前面

        return cluster_z * CLUSTER_COUNT_X * CLUSTER_COUNT_Y +
               cluster_y * CLUSTER_COUNT_X + cluster_x;
    }

    void _render_clustered_ui_batches(RD::DrawListID p_draw_list) {
        // 按集群渲染
        for (auto &entry : cluster_to_batches) {
            uint32_t cluster_idx = entry.key;
            LocalVector<ClusteredUIBatch*> &batches = entry.value;

            // 设置聚类光源数据
            uint32_t *light_indices = cluster_render_data[cluster_idx]
                .light_index_buffer;
            uint32_t light_count = cluster_render_data[cluster_idx]
                .light_count;

            // 更新 Light Cluster 缓冲区
            RD::get_singleton()->buffer_update(
                cluster_render_data[cluster_idx].light_indices_buffer, 0,
                light_count * sizeof(uint32_t), light_indices);

            // 绑定聚类着色器
            RID pipeline = _get_clustered_ui_pipeline();
            RD::get_singleton()->draw_list_bind_render_pipeline(
                p_draw_list, pipeline);

            // 执行聚类中的所有批处理
            for (ClusteredUIBatch *batch : batches) {
                _render_ui_batch(p_draw_list, batch, cluster_idx);
            }
        }
    }

    void _render_ui_batch(RD::DrawListID p_draw_list,
                         ClusteredUIBatch *p_batch,
                         uint32_t p_cluster_idx) {
        // Push Constant（包含聚类信息）
        struct ClusteredUIPushConstant {
            uint32_t cluster_index;
            uint32_t light_count;
            uint32_t material_flags;
            uint32_t pad;
            vec4 tint;  // UI 色调
        } pc;

        pc.cluster_index = p_cluster_idx;
        pc.light_count = cluster_render_data[p_cluster_idx].light_count;
        pc.material_flags = p_batch->texture_state.hash();

        RD::get_singleton()->draw_list_set_push_constant(
            p_draw_list, &pc, sizeof(ClusteredUIPushConstant));

        // Draw Call
        RD::get_singleton()->draw_list_draw(
            p_draw_list, false, p_batch->instance_count);
    }
};
```

#### Forward+ 聚类 UI 着色器

**文件：** `servers/rendering/renderer_rd/forward_clustered/ui_forward_clustered.glsl`

```glsl
#version 450

// Forward+ 聚类 UI 渲染

#define USE_CLUSTERS
#include "cluster_common.glsl"

layout(push_constant, std430) uniform PushConstant {
    uint cluster_index;
    uint light_count;
    uint material_flags;
    uint pad;
    vec4 tint;
} push_constant;

layout(set = 0, binding = 0) uniform CameraData { ... } camera;
layout(set = 0, binding = 1) buffer LightBuffer { ... } lights;
layout(set = 0, binding = 2) buffer ClusterBuffer { ... } clusters;

layout(set = 1, binding = 0) uniform sampler2D ui_texture;

layout(location = 0) out vec4 FragColor;

void main() {
    vec4 color = texture(ui_texture, uv) * push_constant.tint;

    // 获取集群光源列表
    uint cluster_idx = push_constant.cluster_index;
    uint light_start = clusters[cluster_idx].light_start;
    uint light_count = min(push_constant.light_count, 16u);

    vec3 lighting = vec3(0.0);

    // 应用聚类光源（对 UI 通常需要少量光照）
    for (uint i = 0; i < light_count; i++) {
        uint light_idx = lights_buffer.indices[light_start + i];
        Light light = lights[light_idx];

        // 简化的 UI 光照计算
        vec3 light_dir = normalize(light.position - world_pos);
        lighting += light.color * max(0.0, dot(normal, light_dir));
    }

    color.rgb *= (vec3(0.1) + lighting);  // 添加环境光
    FragColor = color;
}
```

---

## UI 渲染加速方案总结

### 方案对比表

| 方案 | 兼容性 | 性能 | 实现复杂度 | 适用场景 |
|------|--------|------|-----------|---------|
| **RD 基础批处理** | ✅ 通用 | 中等 | 低 | 标准 UI |
| **Mobile 分离批处理** | ✅ Mobile | 高 | 中 | 移动游戏 UI |
| **Forward+ 聚类感知** | ✅ 桌面 | 高 | 高 | 大型多光源场景 |
| **GLES3 VBO 实例化** | ✅ 低端设备 | 低 | 低 | 低端设备 UI |

### 优化检查清单

- [ ] 1. 启用 2D 批处理
  ```ini
  rendering/2d/batching/uniform_set_cache_size = 8192
  rendering/2d/batching/item_buffer_size = 16384
  ```

- [ ] 2. UI 材质优化
  ```cpp
  // 合并纹理为 Atlas
  canvas_texture_set_diffuse_texture(canvas_texture, atlas_texture);
  ```

- [ ] 3. 减少状态切换
  ```cpp
  // 按纹理/材质排序 UI 元素
  _sort_ui_items_by_texture();
  ```

- [ ] 4. 启用 Mobile 特定优化
  ```ini
  rendering/2d/mobile/ui_batching_enabled = true
  ```

- [ ] 5. 监测性能
  ```cpp
  // 在帧中输出渲染信息
  print_line("Draw Calls: ", render_info.draw_call_count);
  print_line("UI Batches: ", ui_batch_count);
  ```

### 预期性能提升

| 场景 | 优化前 Draw Calls | 优化后 Draw Calls | 性能提升 |
|------|------------------|------------------|---------|
| 100 个 UI 元素 | 100+ | 10-20 | 5-10x |
| 1000 个 UI 元素 | 1000+ | 50-100 | 10-20x |
| 复杂 UI + 3D | 500+ | 100-150 | 3-5x |

---

## 结论

Godot 的 2D UI 渲染批处理系统已经相当优化，但在移动和大规模场景中仍可进一步改进。通过实施 Mobile 专用批处理和 Forward+ 聚类感知渲染，可显著提升 UI 渲染性能。关键在于减少 Draw Call 数量并提高 GPU 内存带宽利用率。
