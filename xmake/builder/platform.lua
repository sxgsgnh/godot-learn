-- export_icon_builder 的 Xmake 版本
function export_icon_builder(target, source, env)
    local src_path = path.join(source[1])
    local src_name = path.basename(src_path)
    local platform = path.basename(path.directory(path.directory(src_path)))
    
    -- 读取 SVG 文件内容
    local svg = io.readfile(src_path)
    
    -- 写入生成的文件
    local target_file = target[1]
    local content = string.format(
        [[
inline constexpr const char *%s_%s_svg = %s;
]],
        platform,
        src_name,
        methods.to_raw_cstring(svg)
    )
    
    io.writefile(target_file, content)
end

-- register_platform_apis_builder 的 Xmake 版本
function register_platform_apis_builder(target, source, env)
    -- 读取平台列表文件
    local platforms_file = source[1]
    local platforms = {}
    for line in io.lines(platforms_file) do
        if line:match("^%s*[^%s]") and not line:match("^%s*$") then
            table.insert(platforms, line:match("^%s*(.-)%s*$")) -- trim
        end
    end
    
    -- 生成 includes
    local api_inc = {}
    for _, p in ipairs(platforms) do
        table.insert(api_inc, string.format('#include "%s/api/api.h"', p))
    end
    
    -- 生成注册函数调用
    local api_reg = {}
    local api_unreg = {}
    for _, p in ipairs(platforms) do
        table.insert(api_reg, string.format("register_%s_api();", p))
        table.insert(api_unreg, string.format("unregister_%s_api();", p))
    end
    
    -- 写入目标文件
    local target_file = target[1]
    local content = string.format(
        [[
#include "register_platform_apis.h"

%s

void register_platform_apis() {
	%s
}

void unregister_platform_apis() {
	%s
}
]],
        table.concat(api_inc, "\n"),
        table.concat(api_reg, "\n\t"),
        table.concat(api_unreg, "\n\t")
    )
    
    io.writefile(target_file, content)
end