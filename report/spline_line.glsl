#[vertex]

layout(location = 0) in vec3 vertex_quad_pos;

// 实例数据（Storage Buffer）
layout(set = 0, binding = 0) buffer InstanceBuffer {
    struct {
        vec3 position;
        float width;
        vec3 tangent;
        uint color_packed;
        vec3 normal;
        float uv_offset;
        vec3 binormal;
        uint texture_id;
    } instances[];
};

// Camera
layout(set = 0, binding = 1) uniform CameraData {
    mat4 projection;
    mat4 view;
    vec2 screen_size;
    float line_width_scale;
} camera;

// Output
layout(location = 0) out VS_OUTPUT {
    vec3 normal;
    vec2 uv;
    vec4 color;
    vec3 world_pos;
    flat uint tex_id;
} vs_out;

void main() {
    // 获取实例数据
    uint instance_id = gl_InstanceIndex;
    vec3 pos = instances[instance_id].position;
    float width = instances[instance_id].width * camera.line_width_scale;
    vec3 tangent = normalize(instances[instance_id].tangent);
    vec3 normal = normalize(instances[instance_id].normal);
    vec3 binormal = normalize(instances[instance_id].binormal);

    // 解包颜色
    uint color_packed = instances[instance_id].color_packed;
    // 从 ABGR 解包为 RGBA
    vec4 color = vec4(
        float((color_packed >> 16) & 0xFF) / 255.0,  // R
        float((color_packed >> 8) & 0xFF) / 255.0,   // G
        float((color_packed >> 0) & 0xFF) / 255.0,   // B
        float((color_packed >> 24) & 0xFF) / 255.0   // A
    );

    // 几何扩展：从四边形模板生成线条宽度
    // vertex_quad_pos.x: [-0.5, 0.5] 用于宽度方向
    // vertex_quad_pos.y: [-0.5, 0.5] 用于沿切线方向

    vec3 offset_normal = normal * vertex_quad_pos.x * width;
    vec3 offset_tangent = tangent * vertex_quad_pos.y * 0.1;  // 段长度缩放

    // 最终位置
    vec3 world_pos = pos + offset_normal + offset_tangent;

    // 投影到剪辑空间
    gl_Position = camera.projection * camera.view * vec4(world_pos, 1.0);

    // 输出
    vs_out.normal = normal;
    vs_out.uv = vec2(
        vertex_quad_pos.x + 0.5,  // 横向 UV [0, 1]
        instances[instance_id].uv_offset  // 纵向 UV（沿着曲线）
    );
    vs_out.color = color;
    vs_out.world_pos = world_pos;
    vs_out.tex_id = instances[instance_id].texture_id;
}

#[fragment]

layout(location = 0) in VS_OUTPUT {
    vec3 normal;
    vec2 uv;
    vec4 color;
    vec3 world_pos;
    flat uint tex_id;
} fs_in;

// 纹理采样（可选）
layout(set = 1, binding = 0) uniform sampler2D line_texture;

layout(location = 0) out vec4 frag_color;

void main() {
    vec4 base_color = fs_in.color;

    // 边缘淡出（抗锯齿）
    float edge_dist = abs(fs_in.uv.x - 0.5) * 2.0;  // [0, 1]，0 在中心
    float edge_fade = smoothstep(1.0, 0.95, edge_dist);
    base_color.a *= edge_fade;

    // 可选：纹理采样
    if (fs_in.tex_id > 0u) {
        vec4 tex_color = texture(line_texture, fs_in.uv);
        base_color *= tex_color;
    }

    // 输出
    frag_color = base_color;
}
