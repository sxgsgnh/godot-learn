target("drivers")
    set_kind("static")
    add_includedirs(".")
    add_includedirs("..", {public = true})

    -- OS drivers
    add_files("unix/*.cpp")
    add_files("windows/*.cpp")

    -- Sound drivers
    add_files("alsa/*.cpp")
    add_files("pulseaudio/*.cpp")
    if is_plat("windows") then
        add_files("wasapi/*.cpp")
        if not is_plat("windows") or is_cc("gcc") then
            add_files("backtrace/*.cpp")
        end
    end
    if get_config("xaudio2") then
        -- 这里假设支持性检查已在配置阶段处理
        add_files("xaudio2/*.cpp")
        add_defines("XAUDIO2_ENABLED")
    end

    -- Apple platform drivers
    if is_plat("macos", "ios", "visionos") then
        add_files("apple/*.cpp")
        add_files("coreaudio/*.cpp")
    end
    if is_plat("ios", "visionos") then
        add_files("apple_embedded/*.cpp")
    end

    -- Accessibility
    if get_config("accesskit") and is_plat("macos", "windows", "linux") then
        add_files("accesskit/*.cpp")
        add_defines("ACCESSKIT_ENABLED")
    end

    -- Midi drivers
    add_files("alsamidi/*.cpp")
    if is_plat("macos") then
        add_files("coremidi/*.cpp")
    end
    add_files("winmidi/*.cpp")

    -- Graphics drivers
    if get_config("vulkan") then
        add_files("vulkan/*.cpp")
        add_defines("VULKAN_ENABLED")
    end
    if get_config("d3d12") then
        add_files("d3d12/*.cpp")
        add_defines("D3D12_ENABLED")
    end
    if get_config("opengl3") then
        add_files("gl_context/*.cpp")
        add_files("gles3/*.cpp")
        add_files("egl/*.cpp")
        add_defines("OPENGL3_ENABLED")
    end
    if get_config("metal") then
        add_files("metal/*.cpp")
        add_defines("METAL_ENABLED")
    end

    -- Input drivers
    if get_config("sdl") and is_plat("linux", "macos", "windows") then
        add_files("sdl/*.cpp")
        add_defines("SDL_ENABLED")
    end

    -- Core dependencies
    add_files("png/*.cpp")

    -- 所有 drivers 目录下的 cpp
    add_files("*.cpp")

    add_defines("DRIVERS_ENABLED")

    set_targetdir("$(buildir)/lib")
    add_deps("core")
target_end()
