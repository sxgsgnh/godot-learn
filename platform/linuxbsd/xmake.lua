
function load_option()
	option("alsa", {default = true, description = "Use ALSA", category = "linuxbsd"})
end

target("platform")
	add_includedirs(".")
	add_files("*.cpp")

	if has_config("use_sowrap")then
		if has_config("fontconfig")then
			add_files("fontconfig-so_wrap.c")
		end
		if has_config("dbus")then
			add_files("dbus-so_wrap.c")
		end
		add_files("xkbcommon-so_wrap.c")
	end

	if has_config("speedchd") then
		add_files("ts_linux.cpp")
		if has_config("use_sowrap")then
			add_files("speedchd-so_wrap.c")
		end
	end

	if has_config("x11") then
		add_files("./x11/display_server_x11.cpp",
				  "./x11/key_mapping_x11.cpp")
		if has_config("use_sowrap")then
			add_files("x11/dynwrappers/*.c")
		end
		if has_config("vulkan") then
			add_files("./x11/rendering_context_driver_vulkan_x11.cpp")
		end
		if has_config("opengl3")then
			add_defines("GLAD_GLX_NO_X11")
			add_files("./x11/gl_manager_x11.cpp",
					  "./x11/gl_manager_x11_egl.cpp",
					  "./x11/detect_prime_x11.cpp",
					  "../../thirdparty/glad/glx.c")
		end
	end

	if has_config("wayland") then
		add_files("./wayland/detect_prime_egl.cpp",
				  "./wayland/display_server_wayland.cpp",
				  "./wayland/key_mapping_xkb.cpp",
				  "./wayland/wayland_thread.cpp",
				  "./wayland/wayland_embedder.cpp")

		if has_config("use_sowrap")then
			add_files("./wayland/dynwrappers/wayland-*.c")
			if has_config("libdecor")then
				add_files("./wayland/dynwrappers/libdecor-so_wrap.c")
			end
		end
		if has_config("vulkan") then
			add_files("./wayland/rendering_context_driver_vulkan_wayland.cpp")
		end
		if has_config("opengl3")then
			add_files("./wayland/egl_manager_wayland.cpp",
					  "./wayland/egl_manager_wayland_gles.cpp")
		end
	end
