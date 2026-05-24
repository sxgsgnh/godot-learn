
if is_plat("linux") then
	includes("./linuxbsd/xmake.lua")
	load_option()
end

option("alsafffffffffffff", {default = true, description = "Use ALSA", category = "linuxbsd"})
target("platform")
	set_kind("static")
	add_defines("LIBGODOT_PLATFORM_ENABLED")
	add_includedirs(".")
	add_files("*.cpp")
