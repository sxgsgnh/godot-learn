
local mod = import("common")

local function to_string_sequence(filepath)
	local data = io.readfile(filepath,{encoding = "binary"})
	local sdata = {}
	for i = 1, #data do
		local n = data:byte(i)
		table.insert(sdata,n)
	end
	return table.concat(sdata,", ")
end

function general_app_icon(output_path)
	local data = to_string_sequence(os.projectdir() .. "/main/app_icon.png")

	mod.build_sources_file(output_path, true,string.format([[
inline constexpr const unsigned char app_icon_png[] = {
%s
};]], data))
end

function general_splash(output_path)
	local data = to_string_sequence(os.projectdir() .. "/main/splash.png")

	mod.build_sources_file(output_path, true,string.format([[
static const Color boot_splash_bg_color = Color(0.14, 0.14, 0.14);
inline constexpr const unsigned char boot_splash_png[] = {
%s
}]], data))
end

function general_splash_editor(output_path)
	local data = to_string_sequence(os.projectdir() .. "/main/splash_editor.png")
	mod.build_sources_file(output_path, true,string.format([[
static const Color boot_splash_editor_bg_color = Color(0.125, 0.145, 0.192);
inline constexpr const unsigned char boot_splash_editor_png[] = {
%s
};]], data))
end

function make_main_gen_code(output_path)
	general_app_icon(output_path .. "/app_icon.gen.h")
	print("Generated app_icon.gen.h")
	general_splash(output_path .. "/splash.gen.h")
	print("Generated boot_splash.gen.h")
	--general_splash_editor(output_path .. "/boot_splash_editor.gen.cpp")
	--print("Generated boot_splash_editor.gen.cpp")
end


