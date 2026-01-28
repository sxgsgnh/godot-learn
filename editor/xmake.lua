target("editor")
    set_kind("static")

    -- Include 路径
    add_includedirs(".")
    add_includedirs("..", {public = true})

    -- ========================================================================
    -- 编辑器模块源文件
    -- ========================================================================

    add_files(
        "*.cpp",
        "editor_*.cpp",
        "inspector/*.cpp",
        "plugins/*.cpp",
        "fileserver/*.cpp",
        "debugger/*.cpp",
        "import/*.cpp",
        "project_converter/*.cpp"
    )

    -- ========================================================================
    -- 编译定义
    -- ========================================================================

    add_defines("EDITOR_ENABLED", "TOOLS_ENABLED")

    -- ========================================================================
    -- 依赖
    -- ========================================================================

    add_deps("core", "servers", "scene", "main")

    set_targetdir("$(buildir)/lib")

target_end()
