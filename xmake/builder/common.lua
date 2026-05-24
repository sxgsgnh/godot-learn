
local function generate_copyright_header(filename)
    local MARGIN = 70
    local base = filename:match("([^\\/]+)$") or filename
    base = base:sub(1, MARGIN)
    base = base .. string.rep(" ", math.max(0, MARGIN - #base))
    local TEMPLATE = [[
/**************************************************************************/
/*  %s*/
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/
]]
    return string.format(TEMPLATE, base)
end

-- Trim helper
local function trim(s)
    if not s then return "" end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- write_fn: function(writer) or function() -> string
-- guard: true/false/nil (nil = infer from extension .h/.hh/.hpp/.hxx/.inc)
function build_sources_file(path, header, content)
    -- prepare buffer for writer
    local f = io.open(path, "w")
    if not f then
        error("Failed to open generated file for writing: " .. tostring(path))
    end

    -- write copyright and generated notice
    f:write(generate_copyright_header(path))
    f:write("\n/* THIS FILE IS GENERATED. EDITS WILL BE LOST. */\n\n")

    -- decide guard
    if header then
        f:write("#pragma once\n\n")
    end

	local content_to_write = ""

    if type(content) == "function" then
        content(f)
		content_to_write = nil  -- content is written directly by the function
    elseif type(content) == "table" then
        local strings = {}
        for i, item in ipairs(content) do
            strings[i] = tostring(item)
        end
        content_to_write = table.concat(strings, "")  -- 第二个参数为空字符串，表示直接连接
    else
        content_to_write = tostring(content)
    end

	if content_to_write then
    	content_to_write = trim(content_to_write)
    	if content_to_write == "" then
        	f:write("/* NO CONTENT */\n")
    	else
        	f:write(content_to_write)
        	f:write("\n")
		end
    end
    f:close()
end

function to_escaped_cstring(str)
    -- 转义双引号、反斜杠等特殊字符
    str = str:gsub('\\', '\\\\')
    str = str:gsub('"', '\\"')
    str = str:gsub('\n', '\\n')
    str = str:gsub('\r', '\\r')
    str = str:gsub('\t', '\\t')
    return str
end

function to_raw_cstring(content)
    if type(content) == "table" then
        -- 如果是 table，按行处理
        local lines = {}
        for _, line in ipairs(content) do
            table.insert(lines, '"' .. to_escaped_cstring(line) .. '"')
        end
        return table.concat(lines, "\n")
    else
        -- 如果是字符串
        return '"' .. to_escaped_cstring(content) .. '"'
    end
end

function is_table_empty(t)
    if not t then return true end
    for _ in pairs(t) do
        return false
    end
    return true
end

function get_git_info()
    local git_hash = ""
    local git_timestamp = 0

    -- 获取 git hash
	local hash_handle = os.iorun('git rev-parse HEAD')
    if hash_handle then
        git_hash = hash_handle:match("^%s*(.-)%s*$") or ""
	else
		print("Failed to get git hash")
		git_hash = ""
		git_timestamp = 0
    end

    -- 获取 git timestamp
    if git_hash ~= "" then
        local ts_handle = os.iorun('git log -1 --pretty=format:"%ct" ' .. git_hash)
        if ts_handle then
            git_timestamp = tonumber(ts_handle:match("^%s*(.-)%s*$")) or 0
        end
    end
    return {
        git_hash = git_hash,
        git_timestamp = git_timestamp
    }
end


function format_buffer(buffer, indent)
    -- 将二进制数据格式化为 C 数组格式
    indent = indent or 0
    local indent_str = string.rep("\t", indent)
    local lines = {}
    local line_parts = {}
    local count = 0

    for i = 1, #buffer do
        table.insert(line_parts, string.format("0x%02x", string.byte(buffer, i)))
        count = count + 1
        if count == 12 then
            table.insert(lines, indent_str .. table.concat(line_parts, ", "))
            line_parts = {}
            count = 0
        else
            table.insert(line_parts, ", ")
        end
    end

    if #line_parts > 0 then
        -- 移除最后一个多余的 ", "
        if line_parts[#line_parts] == ", " then
            table.remove(line_parts)
        end
        table.insert(lines, indent_str .. table.concat(line_parts))
    end

    return table.concat(lines, ",\n")
end

function compress_buffer(buffer)
    -- 使用 zlib 压缩（需要 lua-zlib 或外部命令）
    -- 如果没有压缩库，返回原始数据
    -- 这里使用外部 gzip 命令作为备选
    if not os.isexec("gzip") then
        return buffer
    end

    local temp_file = os.tmpfile()
    if not temp_file then
        return buffer
    end

    temp_file:write(buffer)
    temp_file:flush()
    local temp_path = temp_file:name()

    os.run("gzip -c %s > %s.gz", temp_path, temp_path)
    local compressed = get_buffer(temp_path .. ".gz")

    os.rm(temp_path)
    os.rm(temp_path .. ".gz")

    return compressed ~= "" and compressed or buffer
end

function hash(buffer)
    -- 计算字符串哈希（简单实现，生产环境建议使用 xxhash 或 md5）
    local h = 0
    for i = 1, #buffer do
        h = (h * 31 + string.byte(buffer, i)) % 0xFFFFFFFF
    end
    return string.format("%08x", h)
end

function format_buffer(str)
	import("core.base.bytes")
	local ss = {}
	local startpos = 2

	local bytedata = bytes(str)
	for i = 1, bytedata:size() do
		local res = string.format("%d, ", bytedata[i])
		table.insert(ss, res)
		startpos = startpos + #res
		if startpos >= 120 then
			table.insert(ss,"\n\t")
			startpos = 2
		end
	end
	return table.concat(ss,"")
end
