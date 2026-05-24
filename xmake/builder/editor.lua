-- xmake.lua
-- 文档数据、导出器注册、翻译文件等构建辅助函数
local mod = import("common")
import("core.project.project")

-- 1. 文档数据类路径构建器
function doc_data_class_path_builder(output_file,opt)

	local basedir = os.projectdir()

	local result = {}
	for _, dir in ipairs(os.dirs(os.projectdir() .. "/platform/*")	) do
		local platform = path.new(dir):basename()
		for _, entry in ipairs(os.files(dir .. "/doc_classes/*.xml")) do
			local doc = path.new(entry):basename()
			result[doc] = "platform/" .. platform .. "/doc_classes"
		end
	end

	for _, dir in ipairs(os.dirs(os.projectdir() .. "/modules/*")	) do
		local module_name = path.new(dir):basename()

		if os.exists(dir .. "/SCsub") then
			local option = project.option("module_" .. module_name)
			if option:enabled() then
				for _, entry in ipairs(os.files(dir .. "/doc_classes/*.xml")) do
					local doc = path.new(entry):basename()
					result[doc] = "modules/" .. module_name .. "/doc_classes"
				end
			end
		end
	end
	local buffer = {}

	for k, v in table.orderpairs(result) do
		table.insert(buffer, string.format('\t{"%s", "%s"},', k, v))
	end
    local content = string.format([[
struct _DocDataClassPath {{
	const char *name;
	const char *path;
}};

inline constexpr int _doc_data_class_path_count = %d;
inline constexpr _DocDataClassPath _doc_data_class_paths[%d] = {
%s
	{nullptr, nullptr},
};
]], #buffer, #buffer + 1, table.concat(buffer, "\n"))

	mod.build_sources_file(output_file, true, content)
end

-- 2. 导出器注册构建器
function register_exporters_builder(output_file)
    local platforms = {"android","ios","linuxbsd","macos","visionos","web","windows"}

    local exp_inc_lines = {}
    local exp_reg_lines = {}
    local exp_type_lines = {}

    for _, p in ipairs(platforms) do
        table.insert(exp_inc_lines, string.format('#include "platform/%s/export/export.h"', p))
        table.insert(exp_reg_lines, string.format("register_%s_exporter();", p))
        table.insert(exp_type_lines, string.format("register_%s_exporter_types();", p))
    end

    local content = string.format([[
#include "register_exporters.h"

%s

void register_exporters() {
	%s
}

void register_exporter_types() {
	%s
}
]], table.concat(exp_inc_lines, "\n"), table.concat(exp_reg_lines, "\n\t"), table.concat(exp_type_lines, "\n\t"))

   mod.build_sources_file(output_file, false, content)
end

-- 3. 文档头文件生成器
function make_doc_header(output_file)
	import("core.base.bytes")

	local docs = os.files(os.projectdir() .. "/doc/classes/*.xml")

	for _, dir in ipairs(os.dirs(os.projectdir() .. "/platform/*")	) do
		local platform = path.new(dir):basename()
		for _, entry in ipairs(os.files(dir .. "/doc_classes/*.xml")) do
			table.insert(docs, entry)
		end
	end

	for _, dir in ipairs(os.dirs(os.projectdir() .. "/modules/*")	) do
		if os.exists(dir .. "/SCsub") then
			local option = project.option("module_" .. path.new(dir):basename())
			if option:enabled() then
				for _, entry in ipairs(os.files(dir .. "/doc_classes/*.xml")) do
					table.insert(docs, entry)
				end
			end
		end
	end

	local hash = function(str)
		local hash = 0
		for i = 1, #str do
			hash = (hash * 31 + string.byte(str, i)) % 2^32
		end
		return hash
	end

	local buffer = ""
	local buffer_size = 0
	for k,v in table.orderpairs(docs) do
		local data = io.readfile(v)
		buffer = buffer .. data
		buffer_size = buffer_size + #data
	end
	import("zlib")
	comp_buffer = zlib.compress(buffer,9)

    local content = string.format([[
inline constexpr const char *_doc_data_hash = "%s";
inline constexpr int _doc_data_compressed_size = %d;
inline constexpr int _doc_data_uncompressed_size = %d;
inline constexpr const unsigned char _doc_data_compressed[] = {
	%s
};
]], hash(buffer) , #comp_buffer, buffer_size, mod.format_buffer(comp_buffer))

	mod.build_sources_file(output_file, true, content)
end

-- 4. 翻译文件生成器
function make_translations(output_path,target_cpp,source)
	import("zlib")
	import("lib.detect")
	local category = path.basename(target_cpp):split("_")[1]
	local base = path.directory(target_cpp)
    local target_h =path.join(base,path.basename(target_cpp)..".h")
	print(target_h,target_cpp)
    -- 排序源文件
    local sorted_sources = {}
    for _, src in ipairs(os.files(source)) do
        table.insert(sorted_sources, src)
    end
    table.sort(sorted_sources, function(a, b)
        local name_a = path.basename(a):gsub("%.po$", "")
        local name_b = path.basename(b):gsub("%.po$", "")
        return name_a < name_b
    end)

	local msgfmt = detect.find_program("msgfmt")
    local xl_names = {}
    local cpp_content = {}
	local buffer = ""

    for _, src_path in ipairs(sorted_sources) do
        local name = path.basename(src_path):gsub("%.po$", "")
		if msgfmt and name ~= category then
			local tmpfile = os.tmpfile()
			os.run(msgfmt .." " ..src_path .. " --no-hash -o " .. tmpfile)
			buffer = io.readfile(tmpfile,{encoding = "utf8"})
			print(name .. ".mo")
		else
			print(name .. ".po")
			buffer = io.readfile(src_path,{encoding = "utf8"})
			if name == category then
            	name = "source"
        	end
		end

        local decomp_size = #buffer
        local compressed = zlib.compress(buffer,9)

        table.insert(cpp_content, string.format([[
inline constexpr const unsigned char _%s_translation_%s_compressed[] = {
	%s
};
]], category, name, mod.format_buffer(compressed)))

        table.insert(xl_names, {name, #compressed, decomp_size})
    end

    -- 生成 .cpp 文件
    table.insert(cpp_content, string.format([[
#include "%s"

const EditorTranslationList _%s_translations[] = {
]], target_h, category))

    for _, x in ipairs(xl_names) do
        table.insert(cpp_content, string.format('\t{ "%s", %d, %d, _%s_translation_%s_compressed },\n',
            x[1], x[2], x[3], category, x[1]))
    end

    table.insert(cpp_content, [[
	{ nullptr, 0, 0, nullptr },
};
]])
	mod.build_sources_file(output_path.."/"..target_cpp, false, cpp_content)

    -- 生成 .h 文件
    local h_content = string.format([[
#ifndef EDITOR_TRANSLATION_LIST
#define EDITOR_TRANSLATION_LIST

struct EditorTranslationList {
	const char* lang;
	int comp_size;
	int uncomp_size;
	const unsigned char* data;
};

#endif // EDITOR_TRANSLATION_LIST

extern const EditorTranslationList _%s_translations[];
]], category)
	mod.build_sources_file(output_path.."/"..target_h, true, h_content)
end

function make_all_translations(output_path)
	local translation_targets = {
        ["editor/translations/editor_translations.gen.cpp"]= "/editor/translations/editor/*.po",
        ["editor/translations/property_translations.gen.cpp"]= "/editor/translations/properties/*.po",
        ["editor/translations/doc_translations.gen.cpp"]= "/doc/translations/*",
        ["editor/translations/extractable_translations.gen.cpp"]= "/editor/translations/extractable/*.po",
    }

	for target_cpp, sources in table.orderpairs(translation_targets) do
		make_translations(output_path,target_cpp, os.projectdir() .. sources)
	end
end

function main(output_path)
	make_all_translations("/home/sgnh/")
	--make_doc_header(output_path.. "/doc_classes.gen.h")
	--register_exporters_builder(output_path .. "/export.cpp")
	--doc_data_class_path_builder("/home/sgnh/test.h")
	--get_doc_path()
end
