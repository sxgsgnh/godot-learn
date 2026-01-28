-- xmake.lua - Godot Engine XMake构建文件
-- 这是根构建文件，定义了完整的构建配置

-- ============================================================================
-- 项目信息
-- ============================================================================
set_project("godot")
set_version("4.5.0")
set_description("Godot Engine - Multi-platform game engine")
set_license("MIT")


-- ============================================================================
-- 全局编译配置
-- ============================================================================
set_languages("c17", "cxx17")
set_warnings("all")
set_defaultmode("release")

-- ============================================================================
-- 选项定义
-- ============================================================================

-- 平台相关选项
option("platform", {
    default = "",
    description = "Target platform",
    values = {"windows", "linuxbsd", "macos", "android", "web"}
})

option("arch", {
    default = "auto",
    description = "Target architecture",
    values = {"x86_64", "x86_32", "arm64", "armv7"}
})

-- 构建目标选项
option("target", {
    default = "editor",
    description = "Build target",
    values = {"editor", "template_debug", "template_release"}
})

-- 优化选项
option("optimize", {
    default = "auto",
    description = "Optimization level",
    values = {"none", "speed", "speed_trace", "size", "size_extra", "debug"}
})

option("debug_symbols", {
    default = "auto",
    description = "Include debug symbols",
    type = "boolean"
})

-- 功能开关选项
option("tests", {
    default = false,
    description = "Build unit tests",
    type = "boolean"
})

option("dev_mode", {
    default = false,
    description = "Enable development mode options",
    type = "boolean"
})

option("disable_3d", {
    default = false,
    description = "Disable 3D support",
    type = "boolean"
})

option("disable_physics_3d", {
    default = false,
    description = "Disable 3D physics",
    type = "boolean"
})

option("disable_physics_2d", {
    default = false,
    description = "Disable 2D physics",
    type = "boolean"
})

-- 第三方库选项
option("builtin_zlib", {
    default = true,
    description = "Use built-in zlib",
    type = "boolean"
})

option("builtin_brotli", {
    default = true,
    description = "Use built-in Brotli",
    type = "boolean"
})

option("builtin_clipper2", {
    default = true,
    description = "Use built-in Clipper2",
    type = "boolean"
})

option("builtin_zstd", {
    default = true,
    description = "Use built-in Zstd",
    type = "boolean"
})

option("builtin_certs", {
    default = true,
    description = "Use built-in SSL certificates",
    type = "boolean"
})

option("builtin_freetype", {
    default = true,
    description = "Use built-in FreeType",
    type = "boolean"
})

-- 图形驱动选项
option("vulkan", {
    default = true,
    description = "Enable Vulkan rendering driver",
    type = "boolean"
})

option("opengl3", {
    default = true,
    description = "Enable OpenGL/GLES3 rendering driver",
    type = "boolean"
})

option("d3d12", {
    default = false,
    description = "Enable Direct3D 12 rendering driver",
    type = "boolean"
})

option("metal", {
    default = false,
    description = "Enable Metal rendering driver (macOS/iOS only)",
    type = "boolean"
})

-- 音频驱动选项
option("xaudio2", {
    default = false,
    description = "Enable XAudio2 audio driver",
    type = "boolean"
})

-- 输入驱动选项
option("sdl", {
    default = true,
    description = "Enable SDL3 input driver",
    type = "boolean"
})

-- 无障碍选项
option("accesskit", {
    default = true,
    description = "Use AccessKit C SDK",
    type = "boolean"
})

-- 编译器选项
option("use_static_cpp", {
    default = false,
    description = "Link C++ runtime statically",
    type = "boolean"
})

option("ccache", {
    default = false,
    description = "Use ccache for compilation caching",
    type = "boolean"
})

-- ============================================================================
-- 配置阶段
-- ============================================================================
on_config(function ()
    -- 平台自动检测
    local platform = get_config("platform")
    if platform == "" or platform == nil then
        local host = os.host()
        if host == "linux" then
            platform = "linuxbsd"
        elseif host == "macos" then
            platform = "macos"
        elseif host == "windows" then
            platform = "windows"
        else
            platform = "linuxbsd"
        end
        set_config("platform", platform)
        cprint("${bright cyan}Auto-detected platform: %s${reset}", platform)
    end

    -- 架构自动检测
    local arch = get_config("arch")
    if arch == "auto" or arch == "" then
        arch = os.arch()
        set_config("arch", arch)
    end

    -- 优化级别处理
    if get_config("optimize") == "auto" then
        if get_config("dev_mode") then
            set_config("optimize", "none")
        elseif get_config("target") ~= "template_release" then
            set_config("optimize", "speed_trace")
        else
            set_config("optimize", "speed")
        end
    end

    -- 调试符号处理
    if get_config("debug_symbols") == "auto" then
        if get_config("dev_mode") then
            set_config("debug_symbols", true)
        elseif get_config("target") == "template_release" then
            set_config("debug_symbols", false)
        else
            set_config("debug_symbols", true)
        end
    end

    -- 编译器配置
    if is_plat("windows") then
        set_config("vs_runtime", "dynamic")
    elseif is_plat("macos") then
        set_config("cc", "clang")
    end

    -- 平台特定编译标志
    if is_plat("windows") then
        add_defines("WINDOWS_ENABLED")
    elseif is_plat("linux") then
        add_defines("LINUX_ENABLED")
    elseif is_plat("macos") then
        add_defines("MACOS_ENABLED")
    end

    -- 编辑器特定配置
    if get_config("target") == "editor" then
        add_defines("TOOLS_ENABLED")
    end

    -- 调试功能
    if get_config("target") ~= "template_release" then
        add_defines("DEBUG_ENABLED")
    end

    -- 开发者特定功能
    if get_config("dev_mode") then
        add_defines("DEV_ENABLED")
    end

    -- 功能开关
    if not get_config("disable_3d") then
        add_defines("_3D_ENABLED")
    else
        set_config("disable_physics_3d", true)
    end

    if not get_config("disable_physics_3d") then
        add_defines("PHYSICS_3D_ENABLED")
    end

    if not get_config("disable_physics_2d") then
        add_defines("PHYSICS_2D_ENABLED")
    end

    -- 打印构建信息
    print_build_info()
end)

-- ============================================================================
-- 辅助函数
-- ============================================================================

-- 打印构建信息
function print_build_info()
    cprint("")
    cprint("${bright cyan}╔════════════════════════════════════╗${reset}")
    cprint("${bright cyan}║   Godot Engine Build Configuration   ║${reset}")
    cprint("${bright cyan}╚════════════════════════════════════╝${reset}")
    cprint("  ${cyan}Platform:${reset}      %s", get_config("platform"))
    cprint("  ${cyan}Architecture:${reset}    %s", get_config("arch"))
    cprint("  ${cyan}Target:${reset}         %s", get_config("target"))
    cprint("  ${cyan}Optimization:${reset}   %s", get_config("optimize"))
    cprint("  ${cyan}Debug Symbols:${reset}  %s", tostring(get_config("debug_symbols")))
    cprint("")
end

-- ============================================================================
-- 全局编译标志配置
-- ============================================================================

-- C++标准
if is_plat("windows") then
    add_cxxflags("/std:c++17", "/permissive-", "/Zc:__cplusplus")
    add_cflags("/std:c17")

    -- MSVC特定设置
    if not has_tool("cc", "gcc") then
        add_cxxflags("/EHsc")  -- 异常处理
    end
else
    add_cxxflags("-std=gnu++17")
    add_cflags("-std=gnu17")
end

-- 禁用异常处理（Godot不使用异常）
if is_plat("windows") then
    add_defines({"_HAS_EXCEPTIONS=0"})
else
    add_cxxflags("-fno-exceptions")
end

-- 警告设置
if is_plat("windows") then
    add_cxxflags("/W3", "/wd4100", "/wd4127", "/wd4201", "/wd4244", "/wd4245")
else
    add_cxxflags("-Wall", "-Wextra", "-Wno-unused-parameter")
    add_cxxflags("-Wshadow", "-Wno-misleading-indentation")
end

-- 优化设置
function apply_optimization()
    local opt = get_config("optimize")

    if is_plat("windows") then
        if opt == "speed" then
            add_cxxflags("/O2")
            add_ldflags("/OPT:REF")
        elseif opt == "speed_trace" then
            add_cxxflags("/O2")
        elseif opt == "size" then
            add_cxxflags("/O1")
        elseif opt == "debug" or opt == "none" then
            add_cxxflags("/Od")
        end
    else
        if opt == "speed" then
            add_cxxflags("-O3")
        elseif opt == "speed_trace" then
            add_cxxflags("-O2")
        elseif opt == "size" then
            add_cxxflags("-Os")
        elseif opt == "debug" then
            add_cxxflags("-Og")
        else
            add_cxxflags("-O0")
        end
    end
end

-- 调试符号设置
function apply_debug_symbols()
    if get_config("debug_symbols") then
        if is_plat("windows") then
            add_cxxflags("/Zi", "/FS")
            add_ldflags("/DEBUG:FULL")
        else
            add_cxxflags("-gdwarf-4")
        end
    end
end

apply_optimization()
apply_debug_symbols()

-- ============================================================================
-- 主目标定义
-- ============================================================================
target("godot")
    set_kind("binary")
    set_default(true)

    -- 基本编译定义
    add_defines("LIBGODOT_ENABLED")

    -- Include目录
    add_includedirs(".")

    -- ========================================================================
    -- 子项目包含和依赖链
    -- ========================================================================

    -- Core 模块（基础库）
    includes("core/xmake.lua")
    add_deps("core")

    -- Drivers 模块（驱动程序）
    includes("drivers/xmake.lua")
    add_deps("drivers")

    -- Servers 模块（服务器）
    includes("servers/xmake.lua")
    add_deps("servers")

    -- Scene 模块（场景系统）
    includes("scene/xmake.lua")
    add_deps("scene")

    -- Modules 模块（插件模块）
    includes("modules/xmake.lua")
    add_deps("modules")

    -- Main 模块（主程序入口）
    includes("main/xmake.lua")
    add_deps("main")

    -- Editor 模块（编辑器 - 如果构建编辑器）
    if get_config("target") == "editor" then
        includes("editor/xmake.lua")
        add_deps("editor")
    end

    -- ========================================================================
    -- 链接选项
    -- ========================================================================

    if is_plat("windows") then
        add_syslinks("kernel32", "user32", "gdi32", "winmm")
        add_syslinks("ole32", "oleaut32", "advapi32", "shell32")
    elseif is_plat("linux") then
        add_syslinks("dl", "pthread", "m", "rt")
    elseif is_plat("macos") then
        add_frameworks("Cocoa", "CoreFoundation", "Security")
        add_frameworks("IOKit", "CoreAudio", "AVFoundation")
    end

    -- 静态链接C++运行库
    if get_config("use_static_cpp") then
        if is_plat("windows") then
            add_cxxflags("/MT")
        else
            add_ldflags("-static-libstdc++")
        end
    end

    -- ========================================================================
    -- 输出配置
    -- ========================================================================

    set_filename("godot")
    set_targetdir("bin")

    -- 添加版本后缀
    local platform = get_config("platform") or "unknown"
    local target_name = get_config("target") or "editor"
    local arch = get_config("arch") or "x86_64"
    local suffix = "." .. platform .. "." .. target_name
    if get_config("dev_mode") then
        suffix = suffix .. ".dev"
    end
    suffix = suffix .. "." .. arch
    set_filename("godot" .. suffix)

target_end()

-- ============================================================================
-- 单元测试目标（如果启用）
-- ============================================================================
if get_config("tests") then
    target("godot_tests")
        set_kind("executable")

        add_files(
            "tests/*.cpp",
            "tests/*/*.cpp"
        )

        add_includedirs(".")
        add_includedirs("tests")

        add_deps("core", "drivers", "servers", "scene", "modules", "main")

        set_targetdir("bin")
        set_filename("godot_tests")
    target_end()
end

--
-- ============================================================================
-- 模式定义（便于用户快速配置）
-- ============================================================================

-- 开发模式快捷设置
--mode("dev")
--    set_config("dev_mode", true)
--    set_config("debug_symbols", true)
--  set_config("optimize", "none")
--    set_config("tests", true)

-- 发行模式快捷设置
--mode("release")
--    set_config("target", "template_release")
--    set_config("debug_symbols", false)
--    set_config("optimize", "speed")
