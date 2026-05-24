local mod = import("builder.common")

-- 转换为 C 字符串数组格式
function to_raw_cstring(code)
    local result = {}
    local bytes = {}

    -- 将字符串转换为字节数组
    for i = 1, #code do
        local char = string.sub(code, i, i)
        local byte = string.byte(char)
        if byte then
            table.insert(bytes, string.format("0x%02x", byte))
        end
    end

    -- 每行最多16个字节
    for i = 1, #bytes, 16 do
        local line = {}
        for j = i, math.min(i + 15, #bytes) do
            table.insert(line, bytes[j])
        end
        table.insert(result, "    " .. table.concat(line, ", ") .. ",")
    end

    -- 添加字符串结束符
    if #result > 0 then
        result[#result] = string.gsub(result[#result], ",$", "")
        table.insert(result, "    0x00")
    else
        table.insert(result, "    0x00")
    end

    return table.concat(result, "\n")
end


-- 错误打印函数
function print_error(msg)
    print("[ERROR] " .. msg)
    os.exit(1)
end

-- 辅助函数：检查表中是否包含某值
function table_contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- 将字符串数组转换为 C 字符串数组格式
function to_raw_cstring_from_lines(lines)
    local full_code = table.concat(lines, "\n")
    return to_raw_cstring(full_code)
end

-- 递归处理 RD 头文件（使用表作为数据容器）
function include_file_in_rd_header(filename, header_data, depth)
    local file = io.open(filename, "r")
    if not file then
        return nil
    end

    local lines = {}
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()

    for _, line in ipairs(lines) do
        -- 处理注释
        local comment_pos = string.find(line, "//")
        if comment_pos then
            line = string.sub(line, 1, comment_pos - 1)
        end

        -- 检查 #[vertex]
        if string.find(line, "#%[vertex%]") then
            header_data.reading = "vertex"
            header_data.line_offset = header_data.line_offset + 1
            header_data.vertex_offset = header_data.line_offset
            goto continue
        end

        -- 检查 #[fragment]
        if string.find(line, "#%[fragment%]") then
            header_data.reading = "fragment"
            header_data.line_offset = header_data.line_offset + 1
            header_data.fragment_offset = header_data.line_offset
            goto continue
        end

        -- 检查 #[compute]
        if string.find(line, "#%[compute%]") then
            header_data.reading = "compute"
            header_data.line_offset = header_data.line_offset + 1
            header_data.compute_offset = header_data.line_offset
            goto continue
        end

        -- 处理 #include
        local include_pos = string.find(line, "#include ")
        while include_pos do
            -- 提取包含的文件名
            local includeline = string.gsub(line, "#include ", "")
            includeline = string.match(includeline, '"([^"]+)"') or string.match(includeline, '<([^>]+)>')

            if not includeline then
                break
            end

            local included_file
            if string.find(includeline, "^thirdparty/") then
                included_file = path.relative(includeline, os.projectdir())
            else
                included_file = path.join(path.directory(filename), includeline)
                included_file = path.relative(included_file, os.projectdir())
            end

            -- 根据当前 reading 状态处理
            if header_data.reading == "vertex" then
                if not table_contains(header_data.vertex_included_files, included_file) then
                    table.insert(header_data.vertex_included_files, included_file)
                    local result = include_file_in_rd_header(included_file, header_data, depth + 1)
                    if not result then
                        print_error(string.format('In file "%s": #include "%s" could not be found!', filename, includeline))
                    end
                end
            elseif header_data.reading == "fragment" then
                if not table_contains(header_data.fragment_included_files, included_file) then
                    table.insert(header_data.fragment_included_files, included_file)
                    local result = include_file_in_rd_header(included_file, header_data, depth + 1)
                    if not result then
                        print_error(string.format('In file "%s": #include "%s" could not be found!', filename, includeline))
                    end
                end
            elseif header_data.reading == "compute" then
                if not table_contains(header_data.compute_included_files, included_file) then
                    table.insert(header_data.compute_included_files, included_file)
                    local result = include_file_in_rd_header(included_file, header_data, depth + 1)
                    if not result then
                        print_error(string.format('In file "%s": #include "%s" could not be found!', filename, includeline))
                    end
                end
            end

            include_pos = string.find(line, "#include ", include_pos + 1)
        end

        -- 清理行并添加到对应的 lines 数组
        line = string.gsub(line, "\r", "")
        line = string.gsub(line, "\n", "")

        if header_data.reading == "vertex" then
            table.insert(header_data.vertex_lines, line)
        elseif header_data.reading == "fragment" then
            table.insert(header_data.fragment_lines, line)
        elseif header_data.reading == "compute" then
            table.insert(header_data.compute_lines, line)
        end

        header_data.line_offset = header_data.line_offset + 1

        ::continue::
    end

    return header_data
end

-- 创建 RD 头数据结构
function create_rd_header_data()
    return {
        vertex_lines = {},
        fragment_lines = {},
        compute_lines = {},
        vertex_included_files = {},
        fragment_included_files = {},
        compute_included_files = {},
        reading = "",
        line_offset = 0,
        vertex_offset = 0,
        fragment_offset = 0,
        compute_offset = 0
    }
end

-- 构建 RD 头文件
function build_rd_header(filename, shader)
    local header_data = create_rd_header_data()
    include_file_in_rd_header(shader, header_data, 0)

    -- 生成类名
    local basename = path.basename(shader)
    local class_name = string.gsub(basename, "%.glsl$", "")
    class_name = string.gsub(class_name, "_", "")
    class_name = string.gsub(class_name, "%.", "")
    class_name = class_name:sub(1, 1):upper() .. class_name:sub(2)
    class_name = class_name .. "ShaderRD"

    local content_lines = {}
    table.insert(content_lines, [[
#include "servers/rendering/renderer_rd/shader_rd.h"

class ]] .. class_name .. [[ : public ShaderRD {
public:
    ]] .. class_name .. [[() {
]])

    if #header_data.compute_lines > 0 then
        table.insert(content_lines, [[
        static const char *_vertex_code = nullptr;
        static const char *_fragment_code = nullptr;
        static const char _compute_code[] = {
]] .. to_raw_cstring_from_lines(header_data.compute_lines) .. [[
        };
]])
    else
        table.insert(content_lines, [[
        static const char _vertex_code[] = {
]] .. to_raw_cstring_from_lines(header_data.vertex_lines) .. [[
        };
        static const char _fragment_code[] = {
]] .. to_raw_cstring_from_lines(header_data.fragment_lines) .. [[
        };
        static const char *_compute_code = nullptr;
]])
    end

    table.insert(content_lines, [[
        setup(_vertex_code, _fragment_code, _compute_code, "]] .. class_name .. [[");
    }
};
]])

    -- 写入文件
	mod.build_sources_file(filename, true,function(file)
	    file:write(table.concat(content_lines))
	end)
end

-- 主构建函数
function build_rd_headers(target, source_files)
    for _, src in ipairs(source_files) do
        local src_str = tostring(src)
        local output_file = src_str .. ".gen.h"
        build_rd_header(output_file, src_str)
    end
end

-- 获取目录下所有 GLSL 文件
function get_glsl_files(directory)
    local files = {}
    for _, file in ipairs(os.files(path.join(directory, "*.glsl"))) do
        table.insert(files, file)
    end
    return files
end


-- 辅助函数：读取文件内容并处理 #include
function include_file_in_raw_header(filename, header_data, depth)
    local file = io.open(filename, "r")
    if not file then
        return
    end

    local lines = {}
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()

    for _, line in ipairs(lines) do
        local include_pos = string.find(line, "#include ")
        while include_pos do
            -- 提取包含的文件名
            local includeline = string.gsub(line, "#include ", "")
            includeline = string.sub(includeline, 2, -2) -- 去掉引号
            includeline = string.gsub(includeline, "^%s*(.-)%s*$", "%1") -- trim

            local included_file = path.join(path.directory(filename), includeline)
            included_file = path.relative(included_file, os.projectdir())

            include_file_in_raw_header(included_file, header_data, depth + 1)

            include_pos = string.find(line, "#include ", include_pos + 1)
        end

        header_data.code = header_data.code .. line .. "\n"
    end
end

-- 构建原始头文件
function build_raw_header(filename, shader)
    local header_data = { code = "" }
    include_file_in_raw_header(shader, header_data, 0)

    -- 生成变量名
    local basename = path.basename(shader)
    local varname = string.gsub(basename, "%.glsl$", "_shader_glsl")

    local content = string.format([[
static const char %s[] = {
%s
};
]], varname, to_raw_cstring(header_data.code))

    -- 写入文件
	mod.build_sources_file(filename, false,function(file)
	    file:write(content)
	end)
end

-- 主构建函数（对应原来的 build_raw_headers）
function build_raw_headers(target, source_files)
    import("core.base.option")

    for _, src in ipairs(source_files) do
        local src_str = tostring(src)
        local output_file = src_str .. ".gen.h"
        build_raw_header(output_file, src_str)
    end
end
