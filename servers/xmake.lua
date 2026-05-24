target("servers")
    set_kind("static")
    add_includedirs(".")
    add_files("register_server_types.cpp","audio/**.cpp","camera/*.cpp","debugger/*.cpp",
		"display/*.cpp","movie_writer/*.cpp","rendering/**.cpp","text/*.cpp")

	if not get_config("disable_physics_2d") then
        add_files("physics_2d/*.cpp")
    end
    if not get_config("disable_physics_3d") then
        add_files("physics_3d/*.cpp")
    end

	if not get_config("disable_navigation_2d") then
        add_files("navigation_2d/*.cpp")
    end
    if not get_config("disable_navigation_3d") then
        add_files("navigation_3d/*.cpp")
    end

    if not get_config("disable_xr") then
        add_files("xr/*.cpp")
    end

    set_targetdir("$(builddir)/lib")
target_end()
