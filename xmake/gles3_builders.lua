-- xmake.lua
-- 这个脚本用于从 GLSL 着色器文件生成 C++ 头文件

-- 定义 GLES3HeaderStruct 的 Lua 表示
function new_gles3_header_struct()
    return {
        vertex_lines = {},
        fragment_lines = {},
        uniforms = {},
        fbos = {},
        texunits = {},
        texunit_names = {},
        ubos = {},
        ubo_names = {},
        feedbacks = {},
        vertex_included_files = {},
        fragment_included_files = {},
        reading = "",
        line_offset = 0,
        vertex_offset = 0,
        fragment_offset = 0,
        variant_defines = {},
        variant_names = {},
        specialization_names = {},
        specialization_values = {}
    }
end

-- 递归包含文件
function include_file_in_gles3_header(filename, header_data, depth)
    depth = depth or 0
    local fs = io.open(filename, "r")
    if not fs then
        return nil
    end

    local line = fs:read()

    while line do
        -- 处理 variant modes
        if string.find(line, "=") and header_data.reading == "" then
            local eqpos = string.find(line, "=")
            local defname = string.upper(string.sub(line, 1, eqpos - 1):match("^%s*(.-)%s*$"))
            local define = string.sub(line, eqpos + 1):match("^%s*(.-)%s*$")
            table.insert(header_data.variant_names, defname)
            table.insert(header_data.variant_defines, define)
            line = fs:read()
            header_data.line_offset = header_data.line_offset + 1
            header_data.vertex_offset = header_data.line_offset
            goto continue
        end

        -- 处理 specializations
        if string.find(line, "=") and header_data.reading == "specializations" then
            local eqpos = string.find(line, "=")
            local specname = string.sub(line, 1, eqpos - 1):match("^%s*(.-)%s*$")
            local specvalue = string.sub(line, eqpos + 1):match("^%s*(.-)%s*$")
            table.insert(header_data.specialization_names, specname)
            table.insert(header_data.specialization_values, specvalue)
            line = fs:read()
            header_data.line_offset = header_data.line_offset + 1
            header_data.vertex_offset = header_data.line_offset
            goto continue
        end

        -- 跳过 modes 标记
        if string.find(line, "#%[modes%]") then
            line = fs:read()
            header_data.line_offset = header_data.line_offset + 1
            header_data.vertex_offset = header_data.line_offset
            goto continue
        end

        -- 开始 specializations 块
        if string.find(line, "#%[specializations%]") then
            header_data.reading = "specializations"
            line = fs:read()
            header_data.line_offset = header_data.line_offset + 1
            header_data.vertex_offset = header_data.line_offset
            goto continue
        end

        -- 开始 vertex 块
        if string.find(line, "#%[vertex%]") then
            header_data.reading = "vertex"
            line = fs:read()
            header_data.line_offset = header_data.line_offset + 1
            header_data.vertex_offset = header_data.line_offset
            goto continue
        end

        -- 开始 fragment 块
        if string.find(line, "#%[fragment%]") then
            header_data.reading = "fragment"
            line = fs:read()
            header_data.line_offset = header_data.line_offset + 1
            header_data.fragment_offset = header_data.line_offset
            goto continue
        end

        -- 处理 #include
        while string.find(line, "#include ") do
            local start_pos = string.find(line, "#include ")
            local after_include = string.sub(line, start_pos + 9):match("^%s*(.-)%s*$")
            local includeline = string.sub(after_include, 2, -2)  -- 去掉引号

            local included_file = path.join(path.directory(filename), includeline)
            included_file = path.absolute(included_file)

            if header_data.reading == "vertex" then
                if not table.contains(header_data.vertex_included_files, included_file) then
                    table.insert(header_data.vertex_included_files, included_file)
                    if include_file_in_gles3_header(included_file, header_data, depth + 1) == nil then
                        print(string.format('In file "%s": #include "%s" could not be found!', filename, includeline))
                    end
                end
            elseif header_data.reading == "fragment" then
                if not table.contains(header_data.fragment_included_files, included_file) then
                    table.insert(header_data.fragment_included_files, included_file)
                    if include_file_in_gles3_header(included_file, header_data, depth + 1) == nil then
                        print(string.format('In file "%s": #include "%s" could not be found!', filename, includeline))
                    end
                end
            end

            line = fs:read()
            if not line then break end
        end

        -- 处理 texture unit
        if string.find(line, "uniform") and string.find(string.lower(line), "texunit:") then
            local texunitstr = string.match(line, ":(.-)$"):match("^%s*(.-)%s*$")
            local texunit = texunitstr == "auto" and "-1" or tostring(tonumber(texunitstr))

            local comment_pos = string.find(string.lower(line), "//")
            local uline = line
            if comment_pos then
                uline = string.sub(line, 1, comment_pos - 1)
            end
            uline = string.gsub(uline, "uniform", "")
            uline = string.gsub(uline, "highp", "")
            uline = string.gsub(uline, ";", "")

            local lines = string.split(uline, ",")
            for _, x in ipairs(lines) do
                x = x:match("^%s*(.-)%s*$")
                x = string.match(x, "%S+$")  -- 获取最后一个单词
                local bracket_pos = string.find(x, "%[")
                if bracket_pos then
                    x = string.sub(x, 1, bracket_pos - 1)
                end

                if not table.contains(header_data.texunit_names, x) then
                    table.insert(header_data.texunits, {x, texunit})
                    table.insert(header_data.texunit_names, x)
                end
            end

        -- 处理 UBO
        elseif string.find(line, "uniform") and string.find(string.lower(line), "ubo:") then
            local ubostr = string.match(line, ":(.-)$"):match("^%s*(.-)%s*$")
            local ubo = tostring(tonumber(ubostr))

            local comment_pos = string.find(string.lower(line), "//")
            local uline = line
            if comment_pos then
                uline = string.sub(line, 1, comment_pos - 1)
            end
            uline = string.sub(uline, string.find(uline, "uniform") + 6)
            uline = string.gsub(uline, "highp", "")
            uline = string.gsub(uline, ";", "")
            uline = string.gsub(uline, "{", "")
            uline = uline:match("^%s*(.-)%s*$")

            local lines = string.split(uline, ",")
            for _, x in ipairs(lines) do
                x = x:match("^%s*(.-)%s*$")
                x = string.match(x, "%S+$")
                local bracket_pos = string.find(x, "%[")
                if bracket_pos then
                    x = string.sub(x, 1, bracket_pos - 1)
                end

                if not table.contains(header_data.ubo_names, x) then
                    table.insert(header_data.ubos, {x, ubo})
                    table.insert(header_data.ubo_names, x)
                end
            end

        -- 处理普通 uniform
        elseif string.find(line, "uniform") and not string.find(line, "{") and string.find(line, ";") then
            local uline = string.gsub(line, "uniform", "")
            uline = string.gsub(uline, ";", "")
            local lines = string.split(uline, ",")
            for _, x in ipairs(lines) do
                x = x:match("^%s*(.-)%s*$")
                x = string.match(x, "%S+$")
                local bracket_pos = string.find(x, "%[")
                if bracket_pos then
                    x = string.sub(x, 1, bracket_pos - 1)
                end

                if not table.contains(header_data.uniforms, x) then
                    table.insert(header_data.uniforms, x)
                end
            end

        -- 处理 feedbacks (transform feedback)
        elseif (string.find(line:match("^%s*"), "out ") == 1 or string.find(line:match("^%s*"), "flat ") == 1) and string.find(line, "tfb:") then
            local uline = string.gsub(line, "flat ", "")
            uline = string.gsub(uline, "out ", "")
            uline = string.gsub(uline, "highp ", "")
            uline = string.gsub(uline, ";", "")
            uline = uline:match("^%s*(.-)%s*$")
            uline = string.match(uline, "%S.*")

            if string.find(uline, "//") then
                local parts = string.split(uline, "//")
                local name = parts[1]:match("^%s*(.-)%s*$")
                local bind = parts[2]
                if string.find(bind, "tfb:") then
                    bind = string.gsub(bind, "tfb:", "")
                    bind = bind:match("^%s*(.-)%s*$")
                    table.insert(header_data.feedbacks, {name, bind})
                end
            end
        end

        -- 清理行并添加到对应的代码块
        line = string.gsub(line, "\r", "")
        line = string.gsub(line, "\n", "")

        if header_data.reading == "vertex" then
            table.insert(header_data.vertex_lines, line)
        elseif header_data.reading == "fragment" then
            table.insert(header_data.fragment_lines, line)
        end

        line = fs:read()
        if line then
            header_data.line_offset = header_data.line_offset + 1
        end

        ::continue::
    end

    fs:close()
    return header_data
end

-- 转换为 C 字符串格式
function to_raw_cstring(lines)
    local result = {}
    for _, line in ipairs(lines) do
        -- 转义特殊字符
        line = string.gsub(line, "\\", "\\\\")
        line = string.gsub(line, '"', '\\"')
        table.insert(result, '\t"' .. line .. '\\n"')
    end
    return table.concat(result, "\n")
end

-- 辅助函数：检查表中是否包含某个值
function table.contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- 辅助函数：字符串分割
function string.split(str, delimiter)
    local result = {}
    local pattern = string.format("([^%s]+)", delimiter)
    for match in string.gmatch(str, pattern) do
        table.insert(result, match)
    end
    return result
end

-- 主构建函数
function build_gles3_header(output_filename, shader_file)
    local header_data = new_gles3_header_struct()
    include_file_in_gles3_header(shader_file, header_data, 0)

    -- 生成类名
    local base_name = path.basename(shader_file):gsub("%.glsl$", "")
    local out_file_class = base_name:gsub("_", ""):gsub("%.", ""):gsub("^%l", string.upper) .. "ShaderGLES3"

    -- 计算默认的 specialization 值
    local defspec = 0
    for index, spec_value in ipairs(header_data.specialization_values) do
        local upper_val = string.upper(spec_value:match("^%s*(.-)%s*$"))
        if upper_val == "TRUE" or upper_val == "1" then
            defspec = defspec | (1 << (index - 1))
        end
    end

    -- 生成默认 variant
    local defvariant = ""
    if #header_data.variant_names == 0 then
        defvariant = " = DEFAULT"
    end

    -- 构建输出文件内容
    local output_content = {}

    table.insert(output_content, [[
#include "drivers/gles3/shader_gles3.h"

class ]] .. out_file_class .. [[ : public ShaderGLES3 {
public:
]])

    -- 输出 uniforms 枚举
    if #header_data.uniforms > 0 then
        local uniforms = {}
        for _, uniform in ipairs(header_data.uniforms) do
            table.insert(uniforms, string.upper(uniform))
        end
        table.insert(output_content, "\tenum Uniforms {\n\t\t" .. table.concat(uniforms, ",\n\t\t") .. ",\n\t};\n\n")
    end

    -- 输出 variants 枚举
    local variant_names = {}
    for _, name in ipairs(header_data.variant_names) do
        table.insert(variant_names, name)
    end
    if #variant_names == 0 then
        variant_names = {"DEFAULT"}
    end
    table.insert(output_content, "\tenum ShaderVariant {\n\t\t" .. table.concat(variant_names, ",\n\t\t") .. ",\n\t};\n\n")

    -- 输出 specializations 枚举
    if #header_data.specialization_names > 0 then
        local specs = {}
        for index, name in ipairs(header_data.specialization_names) do
            table.insert(specs, string.upper(name) .. " = " .. (1 << (index - 1)))
        end
        table.insert(output_content, "\tenum Specializations {\n\t\t" .. table.concat(specs, ",\n\t\t") .. ",\n\t};\n\n")
    end

    -- 输出 version_bind_shader 方法
    table.insert(output_content, string.format([[
	_FORCE_INLINE_ bool version_bind_shader(RID p_version, ShaderVariant p_variant%s, uint64_t p_specialization = %d) {
		return _version_bind_shader(p_version, p_variant, p_specialization);
	}

]], defvariant, defspec))

    -- 输出 uniform 相关方法
    if #header_data.uniforms > 0 then
        table.insert(output_content, string.format([[
	_FORCE_INLINE_ int version_get_uniform(Uniforms p_uniform, RID p_version, ShaderVariant p_variant%s, uint64_t p_specialization = %d) {
		return _version_get_uniform(p_uniform, p_version, p_variant, p_specialization);
	}

	/* clang-format off */
#define TRY_GET_UNIFORM(var_name) int var_name = version_get_uniform(p_uniform, p_version, p_variant, p_specialization); if (var_name < 0) return
	/* clang-format on */

]], defvariant, defspec))

        -- 生成各种类型的 set_uniform 重载
        local uniform_types = {
            {type="float", gl_func="glUniform1f", args={"p_value"}},
            {type="double", gl_func="glUniform1f", args={"p_value"}},
            {type="uint8_t", gl_func="glUniform1ui", args={"p_value"}},
            {type="int8_t", gl_func="glUniform1i", args={"p_value"}},
            {type="uint16_t", gl_func="glUniform1ui", args={"p_value"}},
            {type="int16_t", gl_func="glUniform1i", args={"p_value"}},
            {type="uint32_t", gl_func="glUniform1ui", args={"p_value"}},
            {type="int32_t", gl_func="glUniform1i", args={"p_value"}},
            {type="const Color &", gl_func="glUniform4fv", args={"p_color", "col"}, extra="\t\tGLfloat col[4] = { p_color.r, p_color.g, p_color.b, p_color.a };"},
            {type="const Vector2 &", gl_func="glUniform2fv", args={"p_vec2", "vec2"}, extra="\t\tGLfloat vec2[2] = { float(p_vec2.x), float(p_vec2.y) };"},
            {type="const Size2i &", gl_func="glUniform2iv", args={"p_vec2", "vec2"}, extra="\t\tGLint vec2[2] = { GLint(p_vec2.x), GLint(p_vec2.y) };"},
            {type="const Vector3 &", gl_func="glUniform3fv", args={"p_vec3", "vec3"}, extra="\t\tGLfloat vec3[3] = { float(p_vec3.x), float(p_vec3.y), float(p_vec3.z) };"},
            {type="const Vector4 &", gl_func="glUniform4fv", args={"p_vec4", "vec4"}, extra="\t\tGLfloat vec4[4] = { float(p_vec4.x), float(p_vec4.y), float(p_vec4.z), float(p_vec4.w) };"},
            {type="float", gl_func="glUniform2f", args={"p_a", "p_b"}, name_suffix="_2f"},
            {type="float", gl_func="glUniform3f", args={"p_a", "p_b", "p_c"}, name_suffix="_3f"},
            {type="float", gl_func="glUniform4f", args={"p_a", "p_b", "p_c", "p_d"}, name_suffix="_4f"},
            {type="const Transform3D &", gl_func="glUniformMatrix4fv", args={"p_transform", "matrix"}, extra="\t\tconst Transform3D &tr = p_transform;\n\n\t\tGLfloat matrix[16] = {\n\t\t\t(GLfloat)tr.basis.rows[0][0],\n\t\t\t(GLfloat)tr.basis.rows[1][0],\n\t\t\t(GLfloat)tr.basis.rows[2][0],\n\t\t\t(GLfloat)0,\n\t\t\t(GLfloat)tr.basis.rows[0][1],\n\t\t\t(GLfloat)tr.basis.rows[1][1],\n\t\t\t(GLfloat)tr.basis.rows[2][1],\n\t\t\t(GLfloat)0,\n\t\t\t(GLfloat)tr.basis.rows[0][2],\n\t\t\t(GLfloat)tr.basis.rows[1][2],\n\t\t\t(GLfloat)tr.basis.rows[2][2],\n\t\t\t(GLfloat)0,\n\t\t\t(GLfloat)tr.origin.x,\n\t\t\t(GLfloat)tr.origin.y,\n\t\t\t(GLfloat)tr.origin.z,\n\t\t\t(GLfloat)1\n\t\t};"},
            {type="const Transform2D &", gl_func="glUniformMatrix4fv", args={"p_transform", "matrix"}, extra="\t\tconst Transform2D &tr = p_transform;\n\n\t\tGLfloat matrix[16] = {\n\t\t\t(GLfloat)tr.columns[0][0],\n\t\t\t(GLfloat)tr.columns[0][1],\n\t\t\t(GLfloat)0,\n\t\t\t(GLfloat)0,\n\t\t\t(GLfloat)tr.columns[1][0],\n\t\t\t(GLfloat)tr.columns[1][1],\n\t\t\t(GLfloat)0,\n\t\t\t(GLfloat)0,\n\t\t\t(GLfloat)0,\n\t\t\t(GLfloat)0,\n\t\t\t(GLfloat)1,\n\t\t\t(GLfloat)0,\n\t\t\t(GLfloat)tr.columns[2][0],\n\t\t\t(GLfloat)tr.columns[2][1],\n\t\t\t(GLfloat)0,\n\t\t\t(GLfloat)1\n\t\t};"},
            {type="const Projection &", gl_func="glUniformMatrix4fv", args={"p_matrix", "matrix"}, extra="\t\tGLfloat matrix[16];\n\n\t\tfor (int i = 0; i < 4; i++) {\n\t\t\tfor (int j = 0; j < 4; j++) {\n\t\t\t\tmatrix[i * 4 + j] = p_matrix.columns[i][j];\n\t\t\t}\n\t\t}"},
        }

        for _, ut in ipairs(uniform_types) do
            local method_name = "version_set_uniform"
            if ut.name_suffix then
                method_name = method_name .. ut.name_suffix
            end

            local args_list = {"Uniforms p_uniform"}
            local call_args = {}

            if ut.type == "float" and not ut.name_suffix then
                table.insert(args_list, "float p_value")
                table.insert(call_args, "p_value")
            elseif ut.type == "double" then
                table.insert(args_list, "double p_value")
                table.insert(call_args, "p_value")
            elseif ut.type == "const Color &" then
                table.insert(args_list, "const Color &p_color")
                table.insert(call_args, "1, col")
            elseif ut.type == "const Vector2 &" then
                table.insert(args_list, "const Vector2 &p_vec2")
                table.insert(call_args, "1, vec2")
            elseif ut.type == "const Size2i &" then
                table.insert(args_list, "const Size2i &p_vec2")
                table.insert(call_args, "1, vec2")
            elseif ut.type == "const Vector3 &" then
                table.insert(args_list, "const Vector3 &p_vec3")
                table.insert(call_args, "1, vec3")
            elseif ut.type == "const Vector4 &" then
                table.insert(args_list, "const Vector4 &p_vec4")
                table.insert(call_args, "1, vec4")
            elseif ut.type == "float" and ut.name_suffix == "_2f" then
                table.insert(args_list, "float p_a, float p_b")
                table.insert(call_args, "p_a, p_b")
            elseif ut.type == "float" and ut.name_suffix == "_3f" then
                table.insert(args_list, "float p_a, float p_b, float p_c")
                table.insert(call_args, "p_a, p_b, p_c")
            elseif ut.type == "float" and ut.name_suffix == "_4f" then
                table.insert(args_list, "float p_a, float p_b, float p_c, float p_d")
                table.insert(call_args, "p_a, p_b, p_c, p_d")
            elseif ut.type == "const Transform3D &" then
                table.insert(args_list, "const Transform3D &p_transform")
                table.insert(call_args, "1, false, matrix")
            elseif ut.type == "const Transform2D &" then
                table.insert(args_list, "const Transform2D &p_transform")
                table.insert(call_args, "1, false, matrix")
            elseif ut.type == "const Projection &" then
                table.insert(args_list, "const Projection &p_matrix")
                table.insert(call_args, "1, false, matrix")
            else
                table.insert(args_list, ut.type .. " p_value")
                table.insert(call_args, "p_value")
            end

            table.insert(args_list, "RID p_version")
            table.insert(args_list, "ShaderVariant p_variant" .. defvariant)
            table.insert(args_list, "uint64_t p_specialization = " .. defspec)

            table.insert(output_content, string.format([[
	_FORCE_INLINE_ void %s(%s) {
		TRY_GET_UNIFORM(uniform_location);
%s
		glUniform%s(%s);
	}

]], method_name, table.concat(args_list, ", "), ut.extra or "", ut.gl_func, table.concat(call_args, ", ")))
        end

        table.insert(output_content, [[
#undef TRY_GET_UNIFORM

]])
    end

    -- 输出 _init 方法
    table.insert(output_content, [[
protected:
	virtual void _init() override {
]])

    -- uniforms 字符串数组
    if #header_data.uniforms > 0 then
        local uniform_strings = {}
        for _, uniform in ipairs(header_data.uniforms) do
            table.insert(uniform_strings, '"' .. uniform .. '"')
        end
        table.insert(output_content, "\t\tstatic const char *_uniform_strings[] = {\n\t\t\t" .. table.concat(uniform_strings, ",\n\t\t\t") .. "\n\t\t};\n")
    else
        table.insert(output_content, "\t\tstatic const char **_uniform_strings = nullptr;\n")
    end

    -- variant defines
    local variant_count = #header_data.variant_defines
    if variant_count > 0 then
        local variant_defines = {}
        for _, define in ipairs(header_data.variant_defines) do
            table.insert(variant_defines, '"' .. define .. '"')
        end
        table.insert(output_content, "\t\tstatic const char *_variant_defines[] = {\n\t\t\t" .. table.concat(variant_defines, ",\n\t\t\t") .. ",\n\t\t};\n")
    else
        variant_count = 1
        table.insert(output_content, '\t\tstatic const char **_variant_defines[] = {" "};\n')
    end

    -- texture units
    if #header_data.texunits > 0 then
        local texunit_pairs = {}
        for _, pair in ipairs(header_data.texunits) do
            table.insert(texunit_pairs, '{ "' .. pair[1] .. '", ' .. pair[2] .. ' }')
        end
        table.insert(output_content, "\t\tstatic TexUnitPair _texunit_pairs[] = {\n\t\t\t" .. table.concat(texunit_pairs, ",\n\t\t\t") .. ",\n\t\t};\n")
    else
        table.insert(output_content, "\t\tstatic TexUnitPair *_texunit_pairs = nullptr;\n")
    end

    -- UBOs
    if #header_data.ubos > 0 then
        local ubo_pairs = {}
        for _, pair in ipairs(header_data.ubos) do
            table.insert(ubo_pairs, '{ "' .. pair[1] .. '", ' .. pair[2] .. ' }')
        end
        table.insert(output_content, "\t\tstatic UBOPair _ubo_pairs[] = {\n\t\t\t" .. table.concat(ubo_pairs, ",\n\t\t\t") .. ",\n\t\t};\n")
    else
        table.insert(output_content, "\t\tstatic UBOPair *_ubo_pairs = nullptr;\n")
    end

    -- specializations
    if #header_data.specialization_names > 0 then
        local spec_pairs = {}
        for index, name in ipairs(header_data.specialization_names) do
            local value = "false"
            local spec_value = header_data.specialization_values[index]:match("^%s*(.-)%s*$")
            if string.upper(spec_value) == "TRUE" or spec_value == "1" then
                value = "true"
            end
            table.insert(spec_pairs, '{ "' .. name .. '", ' .. value .. ' }')
        end
        table.insert(output_content, "\t\tstatic Specialization _spec_pairs[] = {\n\t\t\t" .. table.concat(spec_pairs, ",\n\t\t\t") .. ",\n\t\t};\n")
    else
        table.insert(output_content, "\t\tstatic Specialization *_spec_pairs = nullptr;\n")
    end

    -- feedbacks
    if #header_data.feedbacks > 0 then
        local feedbacks = {}
        for _, fb in ipairs(header_data.feedbacks) do
            local spec_bit = 0
            local spec_name = fb[2]
            for index, name in ipairs(header_data.specialization_names) do
                if name == spec_name then
                    spec_bit = 1 << (index - 1)
                    break
                end
            end
            table.insert(feedbacks, '{ "' .. fb[1] .. '", ' .. spec_bit .. ' }')
        end
        table.insert(output_content, "\t\tstatic const Feedback _feedbacks[] = {\n\t\t\t" .. table.concat(feedbacks, ",\n\t\t\t") .. ",\n\t\t};\n")
    else
        table.insert(output_content, "\t\tstatic const Feedback *_feedbacks = nullptr;\n")
    end

    -- vertex 和 fragment 代码
    table.insert(output_content, string.format([[
		static const char _vertex_code[] = {
%s
		};

		static const char _fragment_code[] = {
%s
		};

		_setup(_vertex_code, _fragment_code, "%s",
				%d, _uniform_strings, %d, _ubo_pairs,
				%d, _feedbacks, %d, _texunit_pairs,
				%d, _spec_pairs, %d, _variant_defines);
	}
};
]], to_raw_cstring(header_data.vertex_lines), to_raw_cstring(header_data.fragment_lines),
    out_file_class, #header_data.uniforms, #header_data.ubos,
    #header_data.feedbacks, #header_data.texunits,
    #header_data.specialization_names, variant_count))

    -- 写入文件
    local out_file = io.open(output_filename, "w")
    if out_file then
        out_file:write(table.concat(output_content))
        out_file:close()
        print("Generated: " .. output_filename)
    else
        print("Failed to write: " .. output_filename)
    end
end

-- xmake 构建规则
rule("gles3_shader")
    set_extensions(".glsl")
    on_build(function (target, sourcefile)
        local output = sourcefile .. ".gen.h"
        build_gles3_header(output, sourcefile)
    end)

-- 在项目中启用此规则
-- target("your_target")
--     add_rules("gles3_shader")
--     add_files("path/to/*.glsl")
