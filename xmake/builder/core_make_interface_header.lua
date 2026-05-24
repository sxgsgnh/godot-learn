-- 基础类型列表
local mod = import("common")
--include("builder/common.lua")

local BASE_TYPES = {
    "void",
    "int8_t",
    "uint8_t",
    "int16_t",
    "uint16_t",
    "int32_t",
    "uint32_t",
    "int64_t",
    "uint64_t",
    "size_t",
    "char",
    "char16_t",
    "char32_t",
    "wchar_t",
    "float",
    "double",
}

-- 未知类型错误类
local UnknownTypeError = function(unknown, parent, item)
    local msg
    if item then
        msg = string.format("Unknown type '%s' for '%s' used in '%s'", unknown, item, parent)
    else
        msg = string.format("Unknown type '%s' used in '%s'", unknown, parent)
    end
    return msg
end

-- 获取基础类型名称（去除 const 和指针）
local function base_type_name(type_name)
    if type_name:find("^const ") then
        type_name = type_name:sub(7)
    end
    if type_name:find("%*$") then
        type_name = type_name:sub(1, -2)
    end
    return type_name
end

-- 格式化类型和名称
local function format_type_and_name(type_str, name)
    local ret = type_str
    if ret:sub(-1) == "*" then
        ret = ret:sub(1, -2) .. " *"
    end
    if name then
        if ret:sub(-1) == "*" then
            ret = ret .. name
        else
            ret = ret .. " " .. name
        end
    end
    return ret
end

-- 检查类型是否有效
local function is_valid_type(type_str, valid_data_types)
    if type_str == "void" or type_str == "const void" then
        return false
    end
    return valid_data_types[base_type_name(type_str)] ~= nil
end

-- 检查类型定义中的类型引用
local function check_type(kind, type_def, valid_data_types)
    if kind == "alias" then
        if not is_valid_type(type_def["type"], valid_data_types) then
            error(UnknownTypeError(type_def["type"], type_def["name"]))
        end
    elseif kind == "struct" then
        for _, member in ipairs(type_def["members"]) do
            if not is_valid_type(member["type"], valid_data_types) then
                error(UnknownTypeError(member["type"], type_def["name"], member["name"]))
            end
        end
    elseif kind == "function" then
        for _, arg in ipairs(type_def["arguments"]) do
            if not is_valid_type(arg["type"], valid_data_types) then
                error(UnknownTypeError(arg["type"], type_def["name"], arg.get("name")))
            end
        end
        if type_def["return_value"] then
            if not is_valid_type(type_def["return_value"]["type"], valid_data_types) then
                error(UnknownTypeError(type_def["return_value"]["type"], type_def["name"]))
            end
        end
    end
end

-- 检查允许的键
local function check_allowed_keys(data, required, optional)
    optional = optional or {}
    for k, _ in pairs(data) do
        local found = false
        for _, allowed in ipairs(required) do
            if k == allowed then found = true; break end
        end
        if not found then
            for _, allowed in ipairs(optional) do
                if k == allowed then found = true; break end
            end
        end
        if not found then
            error(string.format("Found unknown key '%s'", k))
        end
    end
    for _, r in ipairs(required) do
        if data[r] == nil then
            error(string.format("Missing required key '%s'", r))
        end
    end
end

-- 生成弃用消息
local function make_deprecated_message(data)
    local parts = {
        string.format("Deprecated in Godot %s.", data["since"]),
        data["message"] or "",
        data["replace_with"] and string.format("Use `%s` instead.", data["replace_with"]) or "",
    }
    local result = {}
    for _, p in ipairs(parts) do
        if p ~= "" then
            table.insert(result, p)
        end
    end
    return table.concat(result, " ")
end

-- 生成弃用注释
local function make_deprecated_comment_for_type(type_def)
    if not type_def["deprecated"] then
        return ""
    end
    local message = make_deprecated_message(type_def["deprecated"])
    return string.format(" /* %s */", message)
end

-- 写入文档注释
local function write_doc(file, doc, indent)
    indent = indent or ""
    if #doc == 1 then
        file:write(string.format("%s/* %s */\n", indent, doc[1]))
        return
    end

    local first = true
    for _, line in ipairs(doc) do
        if first then
            file:write(indent .. "/*")
            first = false
        else
            file:write(indent .. " *")
        end
        if line ~= "" then
            file:write(" " .. line)
        end
        file:write("\n")
    end
    file:write(indent .. " */\n")
end

-- 写入简单类型（handle, alias）
local function write_simple_type(file, type_def)
    local line = string.format("typedef %s;%s\n",
        format_type_and_name(type_def["type"], type_def["name"]),
        make_deprecated_comment_for_type(type_def))
    file:write(line)
end

-- 写入枚举类型
local function write_enum_type(file, enum_def)
    file:write("typedef enum {\n")
    for _, value in ipairs(enum_def["values"]) do
        check_allowed_keys(value, {"name", "value"}, {"description", "deprecated"})
        if value["description"] then
            write_doc(file, value["description"], "\t")
        end
        file:write(string.format("\t%s = %d,\n", value["name"], value["value"]))
    end
    file:write(string.format("} %s;%s\n\n", enum_def["name"], make_deprecated_comment_for_type(enum_def)))
end

-- 生成参数列表文本
local function make_args_text(args)
    local combined = {}
    for _, arg in ipairs(args) do
        check_allowed_keys(arg, {"type"}, {"name", "description"})
        table.insert(combined, format_type_and_name(arg["type"], arg["name"]))
    end
    return table.concat(combined, ", ")
end

-- 写入函数类型
local function write_function_type(file, fn_def)
    local args_text = fn_def["arguments"] and make_args_text(fn_def["arguments"]) or ""
    local name_and_args = string.format("(*%s)(%s)", fn_def["name"], args_text)
    local return_type = fn_def["return_value"] and fn_def["return_value"]["type"] or "void"
    file:write(string.format("typedef %s;%s\n",
        format_type_and_name(return_type, name_and_args),
        make_deprecated_comment_for_type(fn_def)))
end

-- 写入结构体类型
local function write_struct_type(file, struct_def)
    file:write("typedef struct {\n")
    for _, member in ipairs(struct_def["members"]) do
        check_allowed_keys(member, {"name", "type"}, {"description"})
        if member["description"] then
            write_doc(file, member["description"], "\t")
        end
        file:write(string.format("\t%s;\n", format_type_and_name(member["type"], member["name"])))
    end
    file:write(string.format("} %s;%s\n\n", struct_def["name"], make_deprecated_comment_for_type(struct_def)))
end

-- 写入接口函数
local function write_interface(file, interface_def)
    -- 构建文档
    local doc = {
        string.format("@name %s", interface_def["name"]),
        string.format("@since %s", interface_def["since"]),
    }

    if interface_def["deprecated"] then
        doc[#doc+1] = string.format("@deprecated %s", make_deprecated_message(interface_def["deprecated"]))
    end

    table.insert(doc, "")
    table.insert(doc, interface_def["description"][1])

    if #interface_def["description"] > 1 then
        table.insert(doc, "")
        for i = 2, #interface_def["description"] do
            table.insert(doc, interface_def["description"][i])
        end
    end

    if interface_def["arguments"] then
        table.insert(doc, "")
        for _, arg in ipairs(interface_def["arguments"]) do
            if not arg["description"] then
                error(string.format("Interface function %s is missing docs for %s argument",
                    interface_def["name"], arg["name"]))
            end
            local arg_doc = table.concat(arg["description"], " ")
            table.insert(doc, string.format("@param %s %s", arg["name"], arg_doc))
        end
    end

    if interface_def["return_value"] then
        if not interface_def["return_value"]["description"] then
            error(string.format("Interface function %s is missing docs for return value", interface_def["name"]))
        end
        local ret_doc = table.concat(interface_def["return_value"]["description"], " ")
        table.insert(doc, "")
        table.insert(doc, string.format("@return %s", ret_doc))
    end

    if interface_def["see"] then
        table.insert(doc, "")
        for _, see in ipairs(interface_def["see"]) do
            table.insert(doc, string.format("@see %s", see))
        end
    end

    -- 写入文档注释
    file:write("/**\n")
    for _, d in ipairs(doc) do
        if d ~= "" then
            file:write(string.format(" * %s\n", d))
        else
            file:write(" *\n")
        end
    end
    file:write(" */\n")

    -- 写入函数声明
    local fn = {}
    for k, v in pairs(interface_def) do
        if k ~= "deprecated" then
            fn[k] = v
        end
    end
    -- 转换函数名：将 snake_case 转换为 PascalCase 并添加前缀
    local words = {}
    for w in string.gmatch(interface_def["name"], "[^_]+") do
        table.insert(words, w:sub(1,1):upper() .. w:sub(2))
    end
    fn["name"] = "GDExtensionInterface" .. table.concat(words)
    write_function_type(file, fn)
    file:write("\n")
end

-- 主函数
function make_interface_header(output_path, source)
	local json = import("core.base.json")
    local buffer = io.readfile(source)  -- 假设有 io.readfile 函数
    local data = json.decode(buffer)      -- 假设有 json.decode 函数，返回带顺序的表


    -- 注意：Xmake Lua 中没有直接的 OrderedDict，但可以保留原始顺序
    -- 如果需要检查格式化，可以序列化回 JSON 比较

    check_allowed_keys(data, {"_copyright", "$schema", "format_version", "types", "interface"}, {})

    local valid_data_types = {}
    for _, type_name in ipairs(BASE_TYPES) do
        valid_data_types[type_name] = true
    end

	mod.build_sources_file(output_path, true,function(outfile)
		outfile:write([[
#ifndef __cplusplus
#include <stddef.h>
#include <stdint.h>

typedef uint32_t char32_t;
typedef uint16_t char16_t;
#else
#include <cstddef>
#include <cstdint>

extern "C" {
#endif

]])

		local handles = {}
		local type_replacements = {}

		for _, type_def in ipairs(data["types"]) do
			local kind = type_def["kind"]

			check_type(kind, type_def, valid_data_types)
			valid_data_types[type_def["name"]] = type_def

			if type_def["deprecated"] then
				check_allowed_keys(type_def["deprecated"], {"since"}, {"message", "replace_with"})
				if type_def["deprecated"]["replace_with"] then
					table.insert(type_replacements, {type_def["name"], type_def["deprecated"]["replace_with"]})
				end
			end

			if type_def["description"] then
				write_doc(outfile, type_def["description"])
			end

			if kind == "handle" then
				check_allowed_keys(type_def, {"name", "kind"}, {"is_const", "is_uninitialized", "parent", "description", "deprecated"})
				if type_def["parent"] then
					local parent_found = false
					for _, h in ipairs(handles) do
						if h == type_def["parent"] then
							parent_found = true
							break
						end
					end
					if not parent_found then
						error(UnknownTypeError(type_def["parent"], type_def["name"]))
					end
				end
				type_def["type"] = (type_def.is_const or false) and "const void*" or "void*"
				write_simple_type(outfile, type_def)
				table.insert(handles, type_def["name"])
			elseif kind == "alias" then
				check_allowed_keys(type_def, {"name", "kind", "type"}, {"description", "deprecated"})
				write_simple_type(outfile, type_def)
			elseif kind == "enum" then
				check_allowed_keys(type_def, {"name", "kind", "values"}, {"is_bitfield", "description", "deprecated"})
				write_enum_type(outfile, type_def)
			elseif kind == "function" then
				check_allowed_keys(type_def, {"name", "kind", "arguments"}, {"return_value", "description", "deprecated"})
				write_function_type(outfile, type_def)
			elseif kind == "struct" then
				check_allowed_keys(type_def, {"name", "kind", "members"}, {"description", "deprecated"})
				write_struct_type(outfile, type_def)
			else
				error(string.format("Unknown kind of type: %s", kind))
			end
		end

		-- 检查类型替换
		for _, repl in ipairs(type_replacements) do
			local type_name, replace_with = repl[1], repl[2]
			if not valid_data_types[replace_with] then
				error(string.format("Unknown type '%s' used as replacement for '%s'", replace_with, type_name))
			end
			local replacement = valid_data_types[replace_with]
			if type(replacement) == "table" and replacement["deprecated"] then
				error(string.format("Cannot use '%s' as replacement for '%s' because it's deprecated too", replace_with, type_name))
			end
		end

		local interface_replacements = {}
		local valid_interfaces = {}

		for _, interface_def in ipairs(data["interface"]) do
			check_type("function", interface_def, valid_data_types)
			check_allowed_keys(interface_def, {"name", "arguments", "since", "description"}, {"return_value", "see", "legacy_type_name", "deprecated"})
			valid_interfaces[interface_def["name"]] = interface_def

			if interface_def["deprecated"] then
				check_allowed_keys(interface_def["deprecated"], {"since"}, {"message", "replace_with"})
				if interface_def["deprecated"]["replace_with"] then
					table.insert(interface_replacements, {interface_def["name"], interface_def["deprecated"]["replace_with"]})
				end
			end

			write_interface(outfile, interface_def)
		end

		-- 检查接口替换
		for _, repl in ipairs(interface_replacements) do
			local func_name, replace_with = repl[1], repl[2]
			if not valid_interfaces[replace_with] then
				error(string.format("Unknown interface function '%s' used as replacement for '%s'", replace_with, func_name))
			end
			local replacement = valid_interfaces[replace_with]
			if replacement["deprecated"] then
				error(string.format("Cannot use '%s' as replacement for '%s' because it's deprecated too", replace_with, func_name))
			end
		end

		outfile:write([[
#ifdef __cplusplus
}
#endif
]])

	end)
end


function main(base_path)
	make_interface_header(base_path .. "/extension/1gdextension_interface.gen.h",base_path.. "/extension/gdextension_interface.json")
end
