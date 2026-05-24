target("drivers")
    set_kind("static")
    add_includedirs(".")
    add_includedirs("..", {public = true})

    -- OS drivers
    add_files("unix/*.cpp")
    add_files("windows/*.cpp")

    -- Sound drivers
    add_files("alsa/*.cpp")
	if has_config("use_sowrap")then
		add_files("alsa/asound-so_wrap.c")
	end
    add_files("pulseaudio/*.cpp")
	if has_config("use_sowrap")then
		add_files("pulseaudio/pulse-so_wrap.c")
	end

    if is_plat("windows") then
        add_files("wasapi/*.cpp")
    end
    if get_config("xaudio2") then
        -- 这里假设支持性检查已在配置阶段处理
        add_files("xaudio2/*.cpp")
        add_defines("XAUDIO2_ENABLED")

    end

    -- Apple platform drivers
    if is_plat("macos", "ios", "visionos") then
        add_files("apple/*.cpp")
		add_files("apple/*.mm")
        add_files("coreaudio/*.cpp")
    end
    if is_plat("ios", "visionos") then
        add_files("apple_embedded/*.cpp")
		add_cxxflags("-fcxx-modules")
		add_cflags("-fmodules")
    end

    -- Accessibility
    if get_config("accesskit") and is_plat("macos", "windows", "linux") then
		add_includedirs("../thirdparty/accesskit/include")
		add_includedirs("accesskit")
		if is_plat("linux")then
			add_files("accesskit/dynwrappers/accesskit-so_wrap.c")
		end
        add_files("accesskit/*.cpp")
    end

    -- Midi drivers
    add_files("alsamidi/*.cpp")
    if is_plat("macos") then
        add_files("coremidi/*.cpp")
    end
    add_files("winmidi/*.cpp")

    -- Graphics drivers
    if get_config("vulkan") then
		add_includedirs("../thirdparty/vulkan")
		add_includedirs("../thirdparty/vulkan/include", {public = true})
		add_includedirs("../thirdparty/spirv-headers/include")
		add_includedirs("../thirdparty/re-spirv")
		if has_config("use_volk")then
			add_defines("USE_VOLK")
			add_defines("VMA_STATIC_VULKAN_FUNCTIONS=1")
			add_includedirs("../thirdparty/volk")
			add_files("../thirdparty/volk/volk.c")
		end

		if is_plat("linux","bsd")then
			if has_config("x11")then
				add_defines("VK_USE_PLATFORM_XLIB_KHR")
			if has_config("wayland")then
				add_defines("VK_USE_PLATFORM_WAYLAND_KHR")
			end
		elseif is_plat("windows") then
			add_defines("VK_USE_PLATFORM_WIN32_KHR")
		elseif is_plat("macos") then
			add_defines("VK_USE_PLATFORM_MACOS_MVK")
			add_defines("VMA_VULKAN_VERSION=1001000")
		elseif is_plat("android") then
			add_defines("VK_USE_PLATFORM_ANDROID_KHR")
			add_defines("VMA_VULKAN_VERSION=1000000")
		elseif is_plat("ios")then
			add_defines("VK_USE_PLATFORM_IOS_MVK")
		end
        add_defines("VULKAN_ENABLED")

		add_files("../thirdparty/vulkan/vk_mem_alloc.cpp")
		add_files("../thirdparty/volk/volk.c")
		add_files("../thirdparty/re-spirv/re-spirv.cpp")
    end


    if get_config("d3d12") then
        add_files("d3d12/*.cpp")
        add_defines("D3D12_ENABLED")
    end

    if get_config("opengl3") then
        if is_plat("macos","windows","linux","bsd") then
			add_includedirs("../thirdparty/glad")
			add_files("../thirdparty/glad/gl.c")
			if has_config("angle_libs")then
				add_files("../thirdparty/glad/egl.c")
			end
			add_files("./gl_context/*.cpp")
			add_defines("GLAD_ENABLED","EGL_ENABLED")
		end
		add_files("egl/*.cpp")
        add_files("gles3/*.cpp")
		add_files("gles3/storage/*.cpp")
		add_files("gles3/effects/*.cpp")
		add_files("gles3/environment/*.cpp")
    end

    if get_config("metal") then
        add_files("metal/*.cpp")
        add_defines("METAL_ENABLED")
    end

    -- Input drivers
    if get_config("sdl") and is_plat("linux", "macos", "windows") then
        if has_config("builtin_sdl")then
			add_includedirs("../thirdparty/sdl")
			add_includedirs("../thirdparty/sdl/include")
			add_includedirs("../thirdparty/sdl/include/build_config")
			add_defines("SDL_PLATFORM_PRIVATE")
			add_files("../thirdparty/sdl/*.c")
			add_files("../thirdparty/sdl/libm/*.c")
			add_files("../thirdparty/sdl/atomic/*.c")
			add_files("../thirdparty/sdl/events/*.c")
			add_files("../thirdparty/sdl/io/SDL_iostream.c")
			add_files("../thirdparty/sdl/joystick/*.c")
			add_files("../thirdparty/sdl/sensor/SDL_sensor.c")
			add_files("../thirdparty/sdl/sensor/dummy/SDL_dummysensor.c")
			add_files("../thirdparty/sdl/stdlib/*.c")
			add_files("../thirdparty/sdl/thread/SDL_thread.c")
			add_files("../thirdparty/sdl/timer/SDL_timer.c")

			--hidpi
			add_files("../thirdparty/sdl/hidapi/SDL_hidapi.c")
			add_files("../thirdparty/sdl/joystick/hidapi/*.c")

			if has_config("linux","bsd","freebsd")then
				add_includedirs("../thirdparty/sdl/core/linux")
				add_files("../thirdparty/sdl/core/linux/*.c")
				add_defines("SDL_PLATFORM_LINUX")
			elseif has_config("windows")then
				add_includedirs("../thirdparty/sdl/core/windows")
				add_files("../thirdparty/sdl/core/windows/*.c")
				add_files("../thirdparty/sdl/haptic/windows/*.c")
				add_files("../thirdparty/sdl/joystick/windows/*.c")
				add_files("../thirdparty/sdl/thread/generic/*.c")
				add_files("../thirdparty/sdl/sensor/windows/SDL_windowssensor.c")
				add_files("../thirdparty/sdl/thread/windows/*.c")
				add_files("../thirdparty/sdl/timer/windows/SDL_systimer.c")
				add_defines("SDL_PLATFORM_WINDOWS")
			elseif has_config("macos")then
				add_files("../thirdparty/sdl/core/unix/*.c")
				add_files("../thirdparty/sdl/haptic/darwin/SDL_syshaptic.c")
				add_files("../thirdparty/sdl/joystick/darwin/SDL_iokitjoystick.c")
				add_files("../thirdparty/sdl/joystick/apple/SDL_mfijoystick.m")
				add_files("../thirdparty/sdl//thread/pthread/*.c")
				add_files("../thirdparty/sdl/timer/unix/SDL_systimer.c")
				add_defines("SDL_PLATFORM_MACOS")
			end
		end
		add_files("/drivers/sdl/*.cpp")
    end

    -- Core dependencies
	if has_config("builtin_libpng")then
		add_includedirs("png")
		add_includedirs("../thirdparty/libpng")
		add_files("*.c")
		if is_arch("arm")then
			add_defines("PNG_ARM_NEON_OPT")
		elseif is_arch("x86")then
			add_defines("PNG_INTEL_SSE")
		else
			--todo: loongarch64 and ppc64
		end
	end
    add_files("png/*.cpp")

    set_targetdir("$(builddir)/lib")
target_end()
