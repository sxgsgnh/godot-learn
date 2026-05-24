local mod = import("builder.common")


function general_version_header(output_path)
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


