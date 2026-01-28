target("servers")
    set_kind("static")

    -- Include 路径
    add_includedirs(".")
    add_includedirs("..", {public = true})

    -- ========================================================================
    -- 音频服务器
    -- ========================================================================

    add_files(
        "audio/**.cpp",
        "audio/*.cpp"
    )
    add_includedirs("audio", {public = true})

    -- ========================================================================
    -- 物理服务器 2D
    -- ========================================================================

    if not get_config("disable_physics_2d") then
        add_files(
            "physics_2d/**.cpp",
            "physics_2d/*.cpp"
        )
        add_includedirs("physics_2d", {public = true})
        add_defines("PHYSICS_2D_ENABLED")
    end

    -- ========================================================================
    -- 物理服务器 3D
    -- ========================================================================

    if not get_config("disable_physics_3d") then
        add_files(
            "physics_3d/**.cpp",
            "physics_3d/*.cpp"
        )
        add_includedirs("physics_3d", {public = true})
        add_defines("PHYSICS_3D_ENABLED")
    end

    -- ========================================================================
    -- 渲染服务器
    -- ========================================================================

    add_files(
        "rendering/**.cpp",
        "rendering/*.cpp"
    )
    add_includedirs("rendering", {public = true})

    -- ========================================================================
    -- 导航服务器 2D/3D
    -- ========================================================================

    if not get_config("disable_navigation_2d") then
        add_files(
            "navigation_2d/**.cpp",
            "navigation_3d/*.cpp"
        )
        add_includedirs("navigation_2d", {public = true})
		add_includedirs("navigation_3d", {public = true})
    end

    -- ========================================================================
    -- XR 服务器
    -- ========================================================================

    if not get_config("disable_xr") then
        add_files(
            "xr/**.cpp",
            "xr/*.cpp"
        )
        add_includedirs("xr", {public = true})
        add_defines("XR_ENABLED")
    end

    -- ========================================================================
    -- 主服务器文件
    -- ========================================================================

    add_files(
        "*.cpp"
    )

    -- ========================================================================
    -- 编译定义
    -- ========================================================================

    add_defines("SERVERS_ENABLED")

    if not get_config("disable_physics_2d") then
        add_defines("PHYSICS_2D_ENABLED")
    end

    if not get_config("disable_physics_3d") then
        add_defines("PHYSICS_3D_ENABLED")
    end

    -- ========================================================================
    -- 依赖
    -- ========================================================================

    add_deps("core")

    set_targetdir("$(buildir)/lib")

target_end()
