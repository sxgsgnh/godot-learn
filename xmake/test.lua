local util = {}

function util.test()
	print("This is a test function from xmake_config.test.lua")
end

function util.add(a, b)
	return a + b
end

util.add(2, 3)  -- This will return 5


function make_default_controller_mappings(output_path)
	mod.build_sources_file(output_path,false,function(file)
		    file:write([[
#include "core/input/default_controller_mappings.h"

#include "core/typedefs.h"

]])
	local source = {"gamecontrollerdb.txt","godotcontrollerdb.txt",}
    local platform_mappings = {}
    for _, src_path in ipairs(source) do
        src_path = tostring(src_path)
        local mapping_file_lines = io.lines(src_path, "r")
        if not mapping_file_lines then
            error("Failed to open file: " .. src_path)
        end

        local current_platform = nil
        for line in mapping_file_lines do
            if not line then
                goto continue
            end

            line = line:strip()
            if string.sub(line, 1, 1) == "#" then
                current_platform = string.sub(line, 2):strip()
                if not platform_mappings[current_platform] then
                    platform_mappings[current_platform] = {}
                end
            elseif current_platform then
                local line_parts = string.split(line, ",")
                local guid = line_parts[1]
                if platform_mappings[current_platform][guid] then
                    --file:write("// WARNING: DATABASE %s OVERWROTE PRIOR MAPPING: %s %s\n":format(
                    --        src_path, current_platform, platform_mappings[current_platform][guid]))
					print("jkl")
                end
                platform_mappings[current_platform][guid] = line
                file:write("%s,\n":format(line))
            end
            ::continue::
        end
    end

    local PLATFORM_VARIABLES = {
        Linux = "LINUXBSD",
        Windows = "WINDOWS",
        Mac OS X = "MACOS",
        Android = "ANDROID",
        iOS = "APPLE_EMBEDDED",
        Web = "WEB",
    }

    file:write("const char *DefaultControllerMappings::mappings[] = {\n")
    for platform, mappings in pairs(platform_mappings) do
        local variable = PLATFORM_VARIABLES[platform]
        file:write("#ifdef " .. variable .. "\n")
        for mapping in pairs(mappings) do
            file:write("\t\"" .. mapping .. "\",\n")
        end
        file:write("#endif // " .. variable .. "\n")
    end
    file:write("\tnullptr\n};\n")
	end)
end
