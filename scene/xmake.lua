target("scene")
    set_kind("static")

    -- Include 路径
    add_includedirs(".")
    add_includedirs("..", {public = true})

    -- ========================================================================
    -- 场景模块源文件
    -- ========================================================================

    add_files(
        "*.cpp",
        "main/*.cpp",
        "gui/*.cpp",
        "2d/*.cpp",
        "3d/*.cpp",
        "animation/*.cpp",
        "audio/*.cpp",
        "resources/*.cpp",
        "debugger/*.cpp",
		"theme/*.cpp"
    )

    -- ========================================================================
    -- 编译定义
    -- ========================================================================

    add_defines("SCENE_ENABLED")

    -- 3D 特定定义
    if not get_config("disable_3d") then
        add_defines("_3D_ENABLED")
    end

    -- 物理特定定义
    if not get_config("disable_physics_2d") then
        add_defines("PHYSICS_2D_ENABLED")
    end

    if not get_config("disable_physics_3d") then
        add_defines("PHYSICS_3D_ENABLED")
    end

    -- ========================================================================
    -- 依赖
    -- ========================================================================

    add_deps("core", "servers")

    set_targetdir("$(buildir)/lib")

target_end()
