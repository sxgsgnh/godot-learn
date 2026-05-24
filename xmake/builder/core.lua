local mod = import("common")

script_call = [[ScriptInstance *_script_instance = ((Object *)(this))->get_script_instance();\
		if (_script_instance) {\
			Callable::CallError ce;\
			$CALLSIARGS\
			$CALLSIBEGIN_script_instance->callp(_gdvirtual_##$VARNAME##_sn, $CALLSIARGPASS, ce);\
			if (ce.error == Callable::CallError::CALL_OK) {\
				$CALLSIRET\
				return true;\
			}\
		}]]

script_has_method = [[ScriptInstance *_script_instance = ((Object *)(this))->get_script_instance();\
		if (_script_instance && _script_instance->has_method(_gdvirtual_##$VARNAME##_sn)) {\
			return true;\
		}]]

proto = [[#define GDVIRTUAL$VER($ALIAS $RET m_name $ARG)\
	mutable void *_gdvirtual_##$VARNAME = nullptr;\
	_FORCE_INLINE_ bool _gdvirtual_##$VARNAME##_call($CALLARGS) $CONST {\
		static const StringName _gdvirtual_##$VARNAME##_sn = StringName(#m_name, true);\
		$SCRIPTCALL\
		if (_get_extension()) {\
			if (unlikely(!_gdvirtual_##$VARNAME)) {\
			    _gdvirtual_init_method_ptr(_gdvirtual_##$VARNAME##_get_method_info().get_compatibility_hash(), _gdvirtual_##$VARNAME, _gdvirtual_##$VARNAME##_sn, $COMPAT);\
			}\
			if (_gdvirtual_##$VARNAME != reinterpret_cast<void*>(_INVALID_GDVIRTUAL_FUNC_ADDR)) {\
				$CALLPTRARGS\
				$CALLPTRRETDEF\
				if (_get_extension()->call_virtual_with_data) {\
					_get_extension()->call_virtual_with_data(_get_extension_instance(), &_gdvirtual_##$VARNAME##_sn, _gdvirtual_##$VARNAME, $CALLPTRARGPASS, $CALLPTRRETPASS);\
					$CALLPTRRET\
				} else {\
					((GDExtensionClassCallVirtual)_gdvirtual_##$VARNAME)(_get_extension_instance(), $CALLPTRARGPASS, $CALLPTRRETPASS);\
					$CALLPTRRET\
				}\
				return true;\
			}\
		}\
		$REQCHECK\
		$RVOID\
		return false;\
	}\
	_FORCE_INLINE_ bool _gdvirtual_##$VARNAME##_overridden() const {\
		static const StringName _gdvirtual_##$VARNAME##_sn = StringName(#m_name, true);\
		$SCRIPTHASMETHOD\
		if (_get_extension()) {\
			if (unlikely(!_gdvirtual_##$VARNAME)) {\
			    _gdvirtual_init_method_ptr(_gdvirtual_##$VARNAME##_get_method_info().get_compatibility_hash(), _gdvirtual_##$VARNAME, _gdvirtual_##$VARNAME##_sn, $COMPAT);\
			}\
			if (_gdvirtual_##$VARNAME != reinterpret_cast<void*>(_INVALID_GDVIRTUAL_FUNC_ADDR)) {\
				return true;\
			}\
		}\
		return false;\
	}\
	_FORCE_INLINE_ static MethodInfo _gdvirtual_##$VARNAME##_get_method_info() {\
		MethodInfo method_info;\
		method_info.name = #m_name;\
		method_info.flags = $METHOD_FLAGS;\
		$FILL_METHOD_INFO\
		return method_info;\
	}

]]

function generate_version(argcount, const, has_return, required, compat)
    local s = proto
    if compat then
        s = s:gsub("$SCRIPTCALL", "")
        s = s:gsub("$SCRIPTHASMETHOD", "")
    else
        s = s:gsub("$SCRIPTCALL", script_call)
        s = s:gsub("$SCRIPTHASMETHOD", script_has_method)
    end

    local sproto = tostring(argcount)
    local method_info = ""
    local method_flags = "METHOD_FLAG_VIRTUAL"

    if has_return then
        sproto = sproto .. "R"
        s = s:gsub("$RET", "m_ret,")
        s = s:gsub("$RVOID", "(void)r_ret;")
        s = s:gsub("$CALLPTRRETDEF", "PtrToArg<m_ret>::EncodeT ret;")
        method_info = method_info .. "method_info.return_val = GetTypeInfo<m_ret>::get_class_info();\\\n"
        method_info = method_info .. "\t\tmethod_info.return_val_metadata = GetTypeInfo<m_ret>::METADATA;"
    else
        s = s:gsub("$RET ", "")
        s = s:gsub("\t\t$RVOID\\\n", "")
        s = s:gsub("\t\t\t$CALLPTRRETDEF\\\n", "")
    end

    if const then
        sproto = sproto .. "C"
        method_flags = method_flags .. " | METHOD_FLAG_CONST"
        s = s:gsub("$CONST", "const")
    else
        s = s:gsub("$CONST ", "")
    end

    if required then
        sproto = sproto .. "_REQUIRED"
        method_flags = method_flags .. " | METHOD_FLAG_VIRTUAL_REQUIRED"
        s = s:gsub(
            "$REQCHECK",
            'ERR_PRINT_ONCE("Required virtual method " + get_class() + "::" + #m_name + " must be overridden before calling.");')
    else
        s = s:gsub("\t\t$REQCHECK\\\n", "")
    end

   if compat then
        sproto = sproto .. "_COMPAT"
        s = s:gsub("$COMPAT", "true")
        s = s:gsub("$ALIAS", "m_alias,")
        s = s:gsub("$VARNAME", "m_alias")
    else
        s = s:gsub("$COMPAT", "false")
        s = s:gsub("$ALIAS ", "")
        s = s:gsub("$VARNAME", "m_name")
    end

    s = s:gsub("$METHOD_FLAGS", method_flags)
    s = s:gsub("$VER", sproto)
    local argtext = ""
    local callargtext = ""
    local callsiargs = ""
    local callsiargptrs = ""
    local callptrargsptr = ""

    if argcount > 0 then
        argtext = ", "
        callsiargs = "Variant vargs[" .. argcount .. "] = { "
        callsiargptrs = "\t\t\tconst Variant *vargptrs[" .. argcount .. "] = { "
        callptrargsptr = "\t\t\t\tGDExtensionConstTypePtr argptrs[" .. argcount .. "] = { "

        if method_info ~= "" then
            method_info = method_info .. "\\\n\t\t"
        end

        -- 修复：正确构建类型列表
        local type_names = {}
        for i = 1, argcount do
            type_names[i] = "m_type" .. i
        end
        method_info = method_info .. "_gdvirtual_set_method_info_args<" .. table.concat(type_names, ", ") .. ">(method_info);"
    end

	local callptrargs = ""
	for i = 0, argcount - 1 do
		if i > 0 then
			argtext = argtext .. ", "
			callargtext = callargtext .. ", "
			callsiargs = callsiargs .. ", "
			callsiargptrs = callsiargptrs .. ", "
			callptrargs = callptrargs .. "\t\t\t"
			callptrargsptr = callptrargsptr .. ", "
		end
		argtext = argtext .. string.format("m_type%d", i + 1)
		callargtext = callargtext .. string.format("m_type%d arg%d", i + 1, i + 1)
		callsiargs = callsiargs .. string.format("VariantInternal::make(arg%d)", i + 1)
		callsiargptrs = callsiargptrs .. string.format("&vargs[%d]", i)
		callptrargs = callptrargs .. string.format("PtrToArg<m_type%d>::EncodeT argval%d; PtrToArg<m_type%d>::encode(arg%d, &argval%d);\\\n", i + 1, i + 1, i + 1, i + 1, i + 1)
		callptrargsptr = callptrargsptr .. string.format("&argval%d", i + 1)
	end
	if argcount > 0 then
		callsiargs = callsiargs .. " };\\\n"
		callsiargptrs = callsiargptrs .. " };"
		s = string.gsub(s, "$CALLSIARGS", callsiargs .. callsiargptrs)
		s = string.gsub(s, "$CALLSIARGPASS", string.format("(const Variant **)vargptrs, %d", argcount))
		callptrargsptr = callptrargsptr .. " };"
		s = string.gsub(s, "$CALLPTRARGS", callptrargs .. callptrargsptr)
		s = string.gsub(s, "$CALLPTRARGPASS", "reinterpret_cast<GDExtensionConstTypePtr *>(argptrs)")
	else
		s = string.gsub(s, "\t\t\t$CALLSIARGS\\\n", "")
		s = string.gsub(s, "$CALLSIARGPASS", "nullptr, 0")
		s = string.gsub(s, "\t\t\t$CALLPTRARGS\\\n", "")
		s = string.gsub(s, "$CALLPTRARGPASS", "nullptr")
	end

	if has_return then
		if argcount > 0 then
			callargtext = callargtext .. ", "
		end
		callargtext = callargtext .. "m_ret &r_ret"
		s = string.gsub(s, "$CALLSIBEGIN", "Variant ret = ")
		s = string.gsub(s, "$CALLSIRET", "r_ret = VariantCaster<m_ret>::cast(ret);")
		s = string.gsub(s, "$CALLPTRRETPASS", "&ret")
		s = string.gsub(s, "$CALLPTRRET", "r_ret = (m_ret)ret;")
	else
		s = string.gsub(s, "$CALLSIBEGIN", "")
		s = string.gsub(s, "\t\t\t\t$CALLSIRET\\\n", "")
		s = string.gsub(s, "$CALLPTRRETPASS", "nullptr")
		s = string.gsub(s, "\t\t\t\t$CALLPTRRET\\\n", "")
	end

	s = string.gsub(s, " $ARG", argtext)
	s = string.gsub(s, "$CALLARGS", callargtext)

	if method_info ~= "" then
		s = string.gsub(s, "$FILL_METHOD_INFO", method_info)
	else
		s = string.gsub(s, "\t\t$FILL_METHOD_INFO\\\n", "")
	end

	return s
end

local function make_virtuals(output_path)
	local max_versions = 12

    local txt = [[/* THIS FILE IS GENERATED DO NOT EDIT */
#pragma once

#include "core/object/script_instance.h"

inline constexpr uintptr_t _INVALID_GDVIRTUAL_FUNC_ADDR = static_cast<uintptr_t>(-1);

template <typename... Args>
void _gdvirtual_set_method_info_args(MethodInfo &p_method_info) {
	p_method_info.arguments = { GetTypeInfo<Args>::get_class_info()... };
	p_method_info.arguments_metadata = { GetTypeInfo<Args>::METADATA... };
}

]]

	   for i = 0, max_versions do
        txt = txt .. "/* " .. i .. " Arguments */\n\n"
        txt = txt .. generate_version(i, false, false,false,false)
        txt = txt .. generate_version(i, false, true,false,false)
        txt = txt .. generate_version(i, true, false,false,false)
        txt = txt .. generate_version(i, true, true,false,false)
        txt = txt .. generate_version(i, false, false, true,false)
        txt = txt .. generate_version(i, false, true, true,false)
        txt = txt .. generate_version(i, true, false, true,false)
        txt = txt .. generate_version(i, true, true, true,false)
        txt = txt .. generate_version(i, false, false, false, true)
        txt = txt .. generate_version(i, false, true, false, true)
        txt = txt .. generate_version(i, true, false, false, true)
        txt = txt .. generate_version(i, true, true, false, true)
    end

	io.writefile(output_path, txt)
end

proto_mod = [[

#define MODBIND$VER($RETTYPE m_name$ARG) \
virtual $RETVAL _##m_name($FUNCARGS) $CONST; \
_FORCE_INLINE_ virtual $RETVAL m_name($FUNCARGS) $CONST override { \
    $RETX _##m_name($CALLARGS);\
}
]]

function generate_mod_version(argcount, const, returns)
    const = const or false
    returns = returns or false

    local s = proto_mod
    local sproto = tostring(argcount)

    if returns then
        sproto = sproto .. "R"
        s = s:gsub("$RETTYPE", "m_ret, ")
        s = s:gsub("$RETVAL", "m_ret")
        s = s:gsub("$RETX", "return")
    else
        s = s:gsub("$RETTYPE", "")
        s = s:gsub("$RETVAL", "void")
        s = s:gsub("$RETX", "")
    end

    if const then
        sproto = sproto .. "C"
        s = s:gsub("$CONST", "const")
    else
        s = s:gsub("$CONST", "")
    end

    s = s:gsub("$VER", sproto)
    local argtext = ""
    local funcargs = ""
    local callargs = ""

    for i = 1, argcount do
        if i > 1 then
            funcargs = funcargs .. ", "
            callargs = callargs .. ", "
        end

        argtext = argtext .. ", m_type" .. tostring(i + 1)
        funcargs = funcargs .. "m_type" .. tostring(i + 1) .. " arg" .. tostring(i + 1)
        callargs = callargs .. "arg" .. tostring(i + 1)
    end

    if argcount > 0 then
        s = s:gsub("$ARG", argtext)
        s = s:gsub("$FUNCARGS", funcargs)
        s = s:gsub("$CALLARGS", callargs)
    else
        s = s:gsub("$ARG", "")
        s = s:gsub("$FUNCARGS", funcargs)
        s = s:gsub("$CALLARGS", callargs)
    end

    return s
end

proto_ex = [[

#define EXBIND$VER($RETTYPE m_name$ARG) \
GDVIRTUAL$VER_REQUIRED($RETTYPE_##m_name$ARG)\
virtual $RETVAL m_name($FUNCARGS) $CONST override { \
    $RETPRE\
    GDVIRTUAL_CALL(_##m_name$CALLARGS$RETREF);\
    $RETPOST\
}
]]

local function generate_ex_version(argcount, const, returns)
    const = const or false
    returns = returns or false

    local s = proto_ex
    local sproto = tostring(argcount)

    if returns then
        sproto = sproto .. "R"
        s = s:gsub("$RETTYPE", "m_ret, ")
        s = s:gsub("$RETVAL", "m_ret")
        s = s:gsub("$RETPRE", "m_ret ret; ZeroInitializer<m_ret>::initialize(ret);\\\n")
        s = s:gsub("$RETPOST", "return ret;\\\n")
    else
        s = s:gsub("$RETTYPE", "")
        s = s:gsub("$RETVAL", "void")
        s = s:gsub("$RETPRE", "")
        s = s:gsub("$RETPOST", "return;")
    end

    if const then
        sproto = sproto .. "C"
        s = s:gsub("$CONST", "const")
    else
        s = s:gsub("$CONST", "")
    end

    s = s:gsub("$VER", sproto)
    local argtext = ""
    local funcargs = ""
    local callargs = ""

    for i = 1, argcount do
        if i > 1 then
            funcargs = funcargs .. ", "
        end

        argtext = argtext .. ", m_type" .. tostring(i + 1)
        funcargs = funcargs .. "m_type" .. tostring(i + 1) .. " arg" .. tostring(i + 1)
        callargs = callargs .. ", arg" .. tostring(i + 1)
    end

    if argcount > 0 then
        s = s:gsub("$ARG", argtext)
        s = s:gsub("$FUNCARGS", funcargs)
        s = s:gsub("$CALLARGS", callargs)
    else
        s = s:gsub("$ARG", "")
        s = s:gsub("$FUNCARGS", funcargs)
        s = s:gsub("$CALLARGS", callargs)
    end

    if returns then
        s = s:gsub("$RETREF", ", ret")
    else
        s = s:gsub("$RETREF", "")
    end

    return s
end

local function make_wrappers(output_path)
    local max_versions = 12
    local txt = "#pragma once"

    for i = 0, max_versions do
        txt = txt .. "\n/* Extension Wrapper " .. tostring(i) .. " Arguments */\n"
        txt = txt .. generate_ex_version(i, false, false)
        txt = txt .. generate_ex_version(i, false, true)
        txt = txt .. generate_ex_version(i, true, false)
        txt = txt .. generate_ex_version(i, true, true)
    end

    for i = 0, max_versions do
        txt = txt .. "\n/* Module Wrapper " .. tostring(i) .. " Arguments */\n"
        txt = txt .. generate_mod_version(i, false, false)
        txt = txt .. generate_mod_version(i, false, true)
        txt = txt .. generate_mod_version(i, true, false)
        txt = txt .. generate_mod_version(i, true, true)
    end
	io.writefile(output_path, txt)
end

-- 生成 disabled_classes.gen.h
local function make_disabled_classes(output_path, disabled_classes)
	print(output_path)
	mod.build_sources_file(output_path, true,"")
end


-- 生成 version_generated.gen.h（version_info: table）
local function make_version_info(output_path)
	local version_info = {
		short_name = "godot",
		name = "Godot Engine",
		major = 4,
		minor = 6,
		patch = 0,
		status = "rc",
		module_config = "",
		website = "https://godotengine.org",
		docs = "latest"
	}

    local tpl = {}
    tpl[#tpl+1] = string.format('#define GODOT_VERSION_SHORT_NAME "%s"\n', version_info.short_name or "")
    tpl[#tpl+1] = string.format('#define GODOT_VERSION_NAME "%s"\n', version_info.name or "")
    tpl[#tpl+1] = string.format('#define GODOT_VERSION_MAJOR %d\n', tonumber(version_info.major) or 0)
    tpl[#tpl+1] = string.format('#define GODOT_VERSION_MINOR %d\n', tonumber(version_info.minor) or 0)
    tpl[#tpl+1] = string.format('#define GODOT_VERSION_PATCH %d\n', tonumber(version_info.patch) or 0)
    tpl[#tpl+1] = string.format('#define GODOT_VERSION_STATUS "%s"\n', version_info.status or "")
    tpl[#tpl+1] = string.format('#define GODOT_VERSION_BUILD "%s"\n', version_info.build or "")
    tpl[#tpl+1] = string.format('#define GODOT_VERSION_MODULE_CONFIG "%s"\n', version_info.module_config or "")
    tpl[#tpl+1] = string.format('#define GODOT_VERSION_WEBSITE "%s"\n', version_info.website or "")
    tpl[#tpl+1] = string.format('#define GODOT_VERSION_DOCS_BRANCH "%s"\n', version_info.docs_branch or "")
    tpl[#tpl+1] = '#define GODOT_VERSION_DOCS_URL "https://docs.godotengine.org/en/" GODOT_VERSION_DOCS_BRANCH\n'
	mod.build_sources_file(output_path, true, table.concat(tpl, ""))
end


local function make_authors_header(output_path, authors_md)
	print(output_path)
	print(authors_md)
    local SECTIONS = {
        ["Project Founders"] = "AUTHORS_FOUNDERS",
        ["Lead Developer"] = "AUTHORS_LEAD_DEVELOPERS",
        ["Project Manager"] = "AUTHORS_PROJECT_MANAGERS",
        ["Developers"] = "AUTHORS_DEVELOPERS",
    }

    -- 读取源文件内容
    local source_file = authors_md
    local content = io.open(source_file, "r"):read("*a")
    local reading = false

    -- 打开目标文件写入
	mod.build_sources_file(output_path, true,function(file)
		local function close_section()
			file:write('\tnullptr,\n};\n\n')
		end

		-- 逐行处理
		for line in content:gmatch("[^\r\n]+") do
			if line:match("^    ") and reading then
				-- 处理缩进行（作者名称）
				local escaped = mod.to_escaped_cstring(line:match("^%s*(.-)%s*$"))
				file:write('\t"' .. escaped .. '",\n')
			elseif line:match("^## ") then
				-- 处理标题行
				if reading then
					close_section()
					reading = false
				end
				local section_name = line:sub(4):match("^%s*(.-)%s*$")
				local section_var = SECTIONS[section_name]
				if section_var then
					file:write("inline constexpr const char *" .. section_var .. "[] = {\n")
					reading = true
				end
			end
		end

		-- 关闭最后一个section
		if reading then
			close_section()
		end
	end)
end

local function make_donors_header(output_path, donors_md)
    local SECTIONS = {
        ["Patrons"] = "DONORS_PATRONS",
        ["Platinum sponsors"] = "DONORS_SPONSORS_PLATINUM",
        ["Gold sponsors"] = "DONORS_SPONSORS_GOLD",
        ["Silver sponsors"] = "DONORS_SPONSORS_SILVER",
        ["Diamond members"] = "DONORS_MEMBERS_DIAMOND",
        ["Titanium members"] = "DONORS_MEMBERS_TITANIUM",
        ["Platinum members"] = "DONORS_MEMBERS_PLATINUM",
        ["Gold members"] = "DONORS_MEMBERS_GOLD",
    }
    -- 读取源文件内容
    local source_file = donors_md
    local file_content = io.open(source_file, "r"):read("*a")
    local reading = false

	mod.build_sources_file(output_path, true,function(file)
		local function close_section()
			file:write('\tnullptr,\n};\n\n')
		end

		-- 逐行处理
		for line in file_content:gmatch("[^\r\n]+") do
			if line:match("^    ") and reading then
				-- 处理缩进行（捐赠者名称）
				local escaped = mod.to_escaped_cstring(line:match("^%s*(.-)%s*$"))
				file:write('\t"' .. escaped .. '",\n')
			elseif line:match("^## ") then
				-- 处理标题行
				if reading then
					close_section()
					reading = false
				end
				local section_name = line:sub(4):match("^%s*(.-)%s*$")
				local section_var = SECTIONS[section_name]
				if section_var then
					file:write("inline constexpr const char *" .. section_var .. "[] = {\n")
					reading = true
				end
			end
		end
		-- 关闭最后一个section
		if reading then
			close_section()
		end

	end)
end

-- 生成 license.gen.h（简化版，仅嵌入 LICENSE 文本）
local function make_license_header(output_path)
    local src_copyright = os.projectdir() .. "/COPYRIGHT.txt"
    local src_license = os.projectdir() .. "/LICENSE.txt"

    -- 使用函数代替类
    function create_license_reader(license_file)
        local self = {
            license_file = license_file,
            line_num = 0,
            current = nil
        }

        function self.next_line()
            local line = self.license_file:read()
            if line then
                self.line_num = self.line_num + 1
                while line and line:find("^#") do
                    line = self.license_file:read()
                    if line then
                        self.line_num = self.line_num + 1
                    end
                end
            end
            self.current = line
            return line
        end

        function self.next_tag()
            if not self.current or not self.current:find(":") then
                return "", {}
            end

            local colon_pos = self.current:find(":")
            local tag = self.current:sub(1, colon_pos - 1)
            local line = self.current:sub(colon_pos + 1)
            local lines = {line:match("^%s*(.-)%s*$")}

            while self.next_line() and self.current and self.current:find("^ ") do
                table.insert(lines, self.current:match("^%s*(.-)%s*$"))
            end

            return tag, lines
        end

        self:next_line()
        return self
    end

    local projects = {}
    local projects_order = {}
    local license_list = {}

    -- 读取 copyright 文件
    local copyright_file = io.open(src_copyright, "r")
    if copyright_file then
        local reader = create_license_reader(copyright_file)
        local part = {}

        while reader.current do
            local tag, content = reader.next_tag()
            if tag == "Files" or tag == "Copyright" or tag == "License" then
                part[tag] = content
            elseif tag == "Comment" and not mod.is_table_empty(part) then
                -- attach non-empty part to named project
                local project_name = content[1]
                if not projects[project_name] then
                    projects[project_name] = {}
                    table.insert(projects_order, project_name)
                end
                table.insert(projects[project_name], part)
            end

            if tag == "" or not reader.current then
                -- end of a paragraph start a new part
                if part["License"] and not part["Files"] then
                    -- no Files tag in this one, so assume standalone license
                    table.insert(license_list, part["License"])
                end
                part = {}
                reader.next_line()
            end
        end
        copyright_file:close()
    end

    -- 构建 data_list
    local data_list = {}
    for _, project_name in ipairs(projects_order) do
        local project = projects[project_name]
        for _, part in ipairs(project) do
            part["file_index"] = #data_list
            for _, file in ipairs(part["Files"] or {}) do
                table.insert(data_list, file)
            end
            part["copyright_index"] = #data_list
            for _, copyright in ipairs(part["Copyright"] or {}) do
                table.insert(data_list, copyright)
            end
        end
    end

    -- 读取 license 文件
    local license_text = ""
    local license_file = io.open(src_license, "r")
    if license_file then
        license_text = license_file:read("*a")
        license_file:close()
    end

    -- 写入输出文件
	mod.build_sources_file(output_path, true,function(file)
			-- 写入 LICENSE 文本
		file:write("inline constexpr const char *GODOT_LICENSE_TEXT = {",mod.to_raw_cstring(license_text),"};\n\n")
		file:write([[
	struct ComponentCopyrightPart {
		const char *license;
		const char *const *files;
		const char *const *copyright_statements;
		int file_count;
		int copyright_count;
	};

	struct ComponentCopyright {
		const char *name;
		const ComponentCopyrightPart *parts;
		int part_count;
	};]])

			-- 写入 COPYRIGHT_INFO_DATA
		file:write("inline constexpr const char *COPYRIGHT_INFO_DATA[] = {\n")
		for _, line in ipairs(data_list) do
			file:write('\t"', mod.to_escaped_cstring(line), '",\n')
		end
		file:write("};\n\n")

			-- 写入 COPYRIGHT_PROJECT_PARTS
		file:write("inline constexpr ComponentCopyrightPart COPYRIGHT_PROJECT_PARTS[] = {\n")
		local part_index = 0
		local part_indexes = {}
		for _, project_name in ipairs(projects_order) do
			part_indexes[project_name] = part_index
			for _, part in ipairs(projects[project_name]) do
				local license_text = part["License"] and part["License"][1] or ""
				file:write('\t{ "', mod.to_escaped_cstring(license_text), '", ')
				file:write("&COPYRIGHT_INFO_DATA[", part['file_index'], "], ")
				file:write("&COPYRIGHT_INFO_DATA[", part['copyright_index'], "], ")
				file:write(#(part["Files"] or {}), ", ", #(part["Copyright"] or {}), " },\n")
				part_index = part_index + 1
			end
		end
		file:write("};\n\n")
		file:write("inline constexpr int COPYRIGHT_INFO_COUNT = ", #projects_order, ";\n\n")
		-- 写入 COPYRIGHT_INFO
		file:write("inline constexpr ComponentCopyright COPYRIGHT_INFO[] = {\n")
		for _, project_name in ipairs(projects_order) do
			file:write('\t{ "', mod.to_escaped_cstring(project_name), '", ')
			file:write("&COPYRIGHT_PROJECT_PARTS[", part_indexes[project_name], "], ")
			file:write(#projects[project_name], " },\n")
		end
		file:write("};\n\n")
		file:write("inline constexpr int LICENSE_COUNT = ", #license_list, ";\n\n")

		-- 写入 LICENSE_NAMES
		file:write("inline constexpr const char *LICENSE_NAMES[] = {\n")
		for _, license in ipairs(license_list) do
			file:write('\t"', mod.to_escaped_cstring(license[1]), '",\n')
		end
		file:write("};\n\n")
		-- 写入 LICENSE_BODIES
		file:write("inline constexpr const char *LICENSE_BODIES[] = {\n\n")
		for _, license in ipairs(license_list) do
			local to_raw = {}
			for i = 2, #license do
				local line = license[i]
				if line == "." then
					table.insert(to_raw, "")
				else
					table.insert(to_raw, line)
				end
			end
			file:write(mod.to_raw_cstring(to_raw), ",\n\n")
		end
		file:write("};\n\n")
	end)
end


local function make_certs_header(output_path)
	--os.cp(os.projectdir() .. "/xmake/certs", output_path)
	import("core.base.bytes")
	import("zlib")
	local buffer = io.readfile(os.projectdir() .. "/thirdparty/certs/ca-bundle.crt")
	local compress = zlib.compress(buffer,9)
	local str = mod.format_buffer(compress)

	mod.build_sources_file(output_path, true,function(file)
		local strdata = [[
#define BUILTIN_CERTS_ENABLED

inline constexpr int _certs_compressed_size = %d;
inline constexpr int _certs_uncompressed_size = %d;
inline constexpr unsigned char _certs_compressed[] = {
	%s
};
]]
        file:write("#define _SYSTEM_CERTS_PATH \"\"\n")
        file:write(strdata:format(#compress,#buffer,str))
	end)
end


local function make_version_hash_source(output_path)
    -- 读取源文件内容（应该是包含 git_hash 和 git_timestamp 的 Lua 表数据）
    local source_data = mod.get_git_info()
    -- 写入输出文件
	mod.build_sources_file(output_path, false,function(file)
	    file:write([[#include "core/version.h"

const char *const GODOT_VERSION_HASH = "]], source_data.git_hash or "", [[";
const uint64_t GODOT_VERSION_TIMESTAMP = ]], source_data.git_timestamp or 0, ";")
	end)
end

local function make_encryption_key(output_path)
	mod.build_sources_file(output_path, false,function(file)
		file:write([[
#include "core/config/project_settings.h"

uint8_t script_encryption_key[32] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};]])
	end)
end

local function make_profiler_builder(output_path)
	mod.build_sources_file(output_path,true,function(file)
		if os.getenv("PATH") == tracy then
			file:write("#define GODOT_USE_TRACY\n")
			if os.getenv("PATH") == "profiler_sample_callstack" then
				file:write("#define TRACY_CALLSTACK 62\n")
			end
			if os.getenv("PATH") == "profiler_track_memory" then
				file:write("#define GODOT_PROFILER_TRACK_MEMORY\n")
			end
		elseif os.getenv("PATH") == perfetto then
			file:write("#define GODOT_USE_PERFETTO\n")
		elseif os.getenv("PATH") == instruments then
			file:write("#define GODOT_USE_INSTRUMENTS\n")
			if os.getenv("PATH") == "profiler_sample_callstack" then
				file:write("#define INSTRUMENTS_SAMPLE_CALLSTACKS\n")
			end
		end
	end)
end

local function make_default_controller_mappings(output_path)

	local source = {
		os.projectdir() .. "/core/input/gamecontrollerdb.txt",
		os.projectdir() .. "/core/input/godotcontrollerdb.txt",
	}

	mod.build_sources_file(output_path, false,function(file)
    -- 写入头文件
    file:write([[
#include "core/input/default_controller_mappings.h"

#include "core/typedefs.h"

]])
    -- 确保映射有一致的顺序
    local platform_mappings = {}
    local platform_order = {}  -- 保持平台顺序

    for _, src_path in ipairs(source) do
        local src_file = io.open(src_path, "r")
        if src_file then
            -- 读取映射文件并跳过头部
            local lines = {}
            for line in src_file:lines() do
                table.insert(lines, line)
            end
            src_file:close()

            -- 跳过前两行（header）
            local mapping_file_lines = {}
            for i = 3, #lines do
                table.insert(mapping_file_lines, lines[i])
            end

            local current_platform = nil
            for _, line in ipairs(mapping_file_lines) do
                if line then
                    line = line:gsub("^%s+", ""):gsub("%s+$", "")  -- strip
                    if #line > 0 then
                        if line:sub(1, 1) == "#" then
                            current_platform = line:sub(2):gsub("^%s+", ""):gsub("%s+$", "")
                            if not platform_mappings[current_platform] then
                                platform_mappings[current_platform] = {}
                                table.insert(platform_order, current_platform)
                            end
                        elseif current_platform then
                            local line_parts = {}
                            for part in line:gmatch("([^,]*),?") do
                                if #part > 0 then
                                    table.insert(line_parts, part)
                                end
                            end
                            local guid = line_parts[1]
                            if platform_mappings[current_platform][guid] then
                                file:write(string.format(
                                    "// WARNING: DATABASE %s OVERWROTE PRIOR MAPPING: %s %s\n",
                                    tostring(src_path), current_platform, platform_mappings[current_platform][guid]
                                ))
                            end
                            platform_mappings[current_platform][guid] = line
                        end
                    end
                end
            end
        end
    end

    local PLATFORM_VARIABLES = {
        Linux = "LINUXBSD",
        Windows = "WINDOWS",
        ["Mac OS X"] = "MACOS",
        Android = "ANDROID",
        iOS = "APPLE_EMBEDDED",
        Web = "WEB",
    }

    file:write("const char *DefaultControllerMappings::mappings[] = {\n")

    for _, platform in ipairs(platform_order) do
        local mappings = platform_mappings[platform]
        local variable = PLATFORM_VARIABLES[platform]
        if variable then
            file:write(string.format("#ifdef %s_ENABLED\n", variable))
            for _, mapping in pairs(mappings) do
                file:write(string.format('\t"%s",\n', mapping))
            end
            file:write(string.format("#endif // %s_ENABLED\n", variable))
        end
    end

    file:write("\tnullptr\n};\n")
	end)
end


local function make_interface_dumper(output_path)
	os.cp(os.projectdir() .. "/xmake/dumper", output_path)
end



function main(output_path)
	make_disabled_classes(output_path .. "/1disabled_classes.gen.h")
	print("Generated core/disabled_classes.gen.h")
	make_version_info(output_path .. "/1version_generated.gen.h")
	print("Generated core/version.gen.h")
	make_authors_header(output_path .. "/1authors.gen.h", os.projectdir().."/AUTHORS.md")
	print("Generated core/authors.gen.h")
	make_donors_header(output_path .. "/1donors.gen.h", os.projectdir().."/DONORS.md")
	print("Generated core/donors.gen.h")
	make_license_header(output_path .. "/1license.gen.h")
	print("Generated core/license.gen.h")
	make_version_hash_source(output_path .. "/1version_hash.gen.cpp")
	print("Generated core/version_hash.gen.cpp")
	make_encryption_key(output_path .. "/1script_encryption_key.gen.cpp")
	print("Generated core/script_encryption_key.gen.cpp")
	make_certs_header(output_path .. "/io/1certs_compressed.gen.h")
	print("Generated core/io/certs_compressed.gen.h")
	make_wrappers(output_path .. "/extension/1ext_wrappers.gen.inc")
	print("Generated core/extension/ext_wrappers.gen.inc")
	make_interface_dumper(output_path .. "/extension/1gdextension_interface_dump.gen.h")
	print("Generated core/extension/gdextension_interface_dump.gen.h")
	make_virtuals(output_path .. "/object/1gdvirtual.gen.inc")
	print("Generated core/object/gdvirtual.gen.inc")
	--make_interface_header() is standalone file
	make_profiler_builder(output_path .. "/profiling/1profiling.gen.h")
	print("Generated core/profiling/profiling.gen.h")
	make_default_controller_mappings(output_path .. "/input/1default_controller_mappings.gen.cpp")
	print("Generated core/input/default_controller_mappings.gen.cpp")
end

