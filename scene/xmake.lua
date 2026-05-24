target("scene")
    set_kind("static")
    -- Include 路径
    add_includedirs(".")
    add_files("*.cpp","animation/*cpp","audio/*.cpp","debugger/*.cpp","gui/*.cpp","main/*.cpp"
	"2d/*.cpp","resources/*.cpp","theme/*.cpp")

	if not has_config("disable_physics_2d")then
		add_files("2d/physics/**.cpp")
	end
	if not has_config("disable_navigation_2d")then
		add_files("2d/navigation/*.cpp")
	end

	if not has_config("disable_3d")then
		add_files("3d/*.cpp")
		if not has_config("disable_physics_3d")then
			add_files("3d/physics/**.cpp")
		end
		if not has_config("disable_navigation_3d")then
			add_files("3d/navigation/*.cpp")
		end
		if not has_config("disable_xr")then
			add_files("3d/xr/*.cpp")
		end
	end


    set_targetdir("$(builddir)/lib")

target_end()
