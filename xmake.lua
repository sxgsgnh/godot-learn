add_rules("mode.debug", "mode.release", "mode.releasedbg")
--set_policy("build.ccache", true)
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
set_warnings("none")
set_defaultmode("debug")
set_exceptions("no-cxx")
includes("./xmake/options.lua")
global_config()



--includes("xmake/zlib/xmake.lua")
--includes("modules/xmake.lua")
--includes("main/xmake.lua")
--includes("core/xmake.lua")
includes("platform/xmake.lua")
--includes("editor/xmake.lua")
-- ============================================================================
-- 主目标定义
-- ============================================================================
target("godot")
    set_kind("binary")
    set_default(true)
    -- Include目录
    add_includedirs(".")
    -- ========================================================================
    -- 子项目包含和依赖链
    -- ========================================================================
    -- Core 模块（基础库）

--[[
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
]]
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
    set_filename("godot" )

target_end()
