-- ========================================================================
-- 功能开关选项
-- ========================================================================


option("disable_overrides", {default = false, description = "Disable project settings overrides (override.cfg)",category = "Features"})
option("disable_path_overrides", {default = true, description = "Disable CLI arguments to override project path/main pack/scene and run scripts",category = "Features"})
option("disable_advanced_gui", {default = false, description = "Disable advanced GUI nodes and behaviors",category = "Features"})
option("disable_physics_2d", {default = false, description = "Disable 2D physics",category = "Features"})
option("disable_navigation_2d", {default = false, description = "Disable 2D navigation features",category = "Features"})
option("disable_3d", {default = true, description = "Disable all 3d features and nodes",category = "Features"})
option("disable_physics_3d")
	set_default(false)
	add_deps("disable_3d")
	set_description("Disable 3D physics features and nodes")
	set_category("features")
	after_check(function (option)
		if option:dep("disable_3d"):enabled() then
			option:enable(true)
		end
	end)
option("disable_navigation_3d")
	set_default(false)
	add_deps("disable_3d")
	set_description("Disable 3D navigation features and nodes")
	set_category("features")
	after_check(function (option)
		if option:dep("disable_3d"):enabled() then
			option:enable(true)
		end
	end)
option("disable_xr")
	set_default(false)
	set_description("Disable XR nodes and server")
	add_deps("disable_3d")
	set_category("features")
	after_check(function (option)
		if option:dep("disable_3d"):enabled() then
			option:enable(true)
		end
	end)

-- ========================================================================
-- 图形驱动选项
-- ========================================================================

option("vulkan", {default = true, description = "Enable Vulkan rendering driver"})
option("opengl3", {default = true, description = "Enable OpenGL/GLES3 rendering driver"})
option("d3d12", {default = false, description = "Enable Direct3D 12 rendering driver"})
option("metal", {default = false, description = "Enable Metal rendering driver (macOS/iOS only)"})
option("use_volk", {default = true, description = "Use volk library to load Vulkan loader dynamically"})
-- ========================================================================
-- 音频驱动选项
-- ========================================================================
option("xaudio2", {default = false, description = "Enable XAudio2 audio driver"})

-- ========================================================================
-- 输入和无障碍选项
-- ========================================================================

option("sdl", {default = true, description = "Enable SDL3 input driver"})
option("accesskit", {default = true, description = "Use AccessKit C SDK"})

-- ========================================================================
-- 编译器选项
-- ========================================================================

option("use_static_cpp", {default = false, description = "Link C++ runtime statically"})
option("ccache", {default = false, description = "Use ccache for compilation caching"})
option("scu_build", {default = false, description = "Use single compilation unit build"})

-- ========================================================================
-- 第三方库选项
-- ========================================================================

option("builtin_zlib", {default = true, description = "Use built-in zlib library",category = "builtin"})
option("builtin_brotli", {default = true, description = "Use built-in Brotli library",category = "builtin"})
option("builtin_clipper2", {default = true, description = "Use built-in Clipper2 library",category = "builtin"})
option("builtin_zstd", {default = true, description = "Use built-in Zstd library",category = "builtin"})
option("builtin_certs", {default = true, description = "Use built-in SSL certificates bundles",category = "builtin"})
option("builtin_freetype", {default = true, description = "Use built-in FreeType library",category = "builtin"})
option("builtin_msdfgen", {default = true, description = "Use built-in MSDFgen library",category = "builtin"})
option("builtin_glslang", {default = true, description = "Use built-in glslang library",category = "builtin"})
option("builtin_graphite", {default = true, description = "Use built-in Graphite library",category = "builtin"})
option("builtin_harfbuzz", {default = true, description = "Use built-in HarfBuzz library",category = "builtin"})
option("builtin_icu4c", {default = true, description = "Use built-in ICU library",category = "builtin"})
option("builtin_libjpeg_turbo", {default = true, description = "Use built-in libjpeg-turbo library",category = "builtin"})
option("builtin_libpng", {default = true, description = "Use built-in libpng library",category = "builtin"})
option("builtin_libwebp", {default = true, description = "Use built-in libwebp library",category = "builtin"})
option("builtin_mbedtls", {default = true, description = "Use built-in mbedTLS library",category = "builtin"})
option("builtin_openxr", {default = true, description = "Use built-in OpenXR library",category = "builtin"})
option("builtin_pcre2", {default = true, description = "Use built-in PCRE2 library",category = "builtin"})

-- ========================================================================
-- 其他选项
-- ========================================================================

option("threads", {default = true, description = "Enable threading support"})
option("deprecated", {default = true, description = "Enable compatibility code for deprecated and removed features"})
option("minizip", {default = true, description = "Enable ZIP archive support using minizip"})
option("brotli", {default = true, description = "Enable Brotli for decompression and WOFF2 fonts support"})
option("engine_update_check", {default = true, description = "Enable engine update checks in the Project Manager"})
option("strict_checks", {default = false, description = "Enforce stricter checks (debug option)"})
option("use_precise_math_checks", {default = false, description = "Math checks use very precise epsilon (debug option)"})
option("limit_transitive_includes", {default = true, description = "Attempt to limit transitive includes in system headers"})
option("no_editor_splash", {default = false, description = "Don't use the custom splash screen for the editor"})
option("double_precision", {default = false, description = "Enable double precision math for physics and other calculations (where applicable)"})
-- ========================================================================
-- 动态模块选项（从 modules 目录自动生成）
-- ========================================================================
-- 直接在全局作用域定义，但用 is_plat 控制是否生效

if os.host() == "linux" then
    option("use_sowrap", {default = true, description = "Dynamically load system libraries", category = "linuxbsd"})
    option("alsa", {default = true, description = "Use ALSA", category = "linuxbsd"})
    option("pulseaudio", {default = true, description = "Use PulseAudio", category = "linuxbsd"})
    option("dbus", {default = true, description = "Use D-Bus to handle screensaver and portal desktop settings", category = "linuxbsd"})
    option("speechd", {default = true, description = "Use Speech Dispatcher for Text-to-Speech support", category = "linuxbsd"})
    option("fontconfig", {default = true, description = "Use fontconfig for system fonts support", category = "linuxbsd"})
    option("udev", {default = true, description = "Use udev for gamepad connection callbacks", category = "linuxbsd"})
    option("x11", {default = true, description = "Enable X11 display", category = "linuxbsd"})
    option("wayland", {default = true, description = "Enable Wayland display", category = "linuxbsd"})
    option("libdecor", {default = true, description = "Enable libdecor support", category = "linuxbsd"})
    option("touch", {default = true, description = "Enable touch events", category = "linuxbsd"})
    option("execinfo", {default = false, description = "Use libexecinfo on systems where glibc is not available", category = "linuxbsd"})
elseif os.host() == "windows" then
	-- MSVC 相关
	option("silence_msvc", {default = true, description = "Silence MSVC's cl/link stdout bloat, redirecting any errors to stderr.", category = "windows"})

	-- ANGLE 相关
	option("angle_libs", {default = "", description = "Path to the ANGLE static libraries", category = "windows"})

	-- Direct3D 12 相关
	option("mesa_libs", {
		default = path.join(os.getenv("D3D12_DEPS_FOLDER") or "", "mesa"),
		description = "Path to the MESA/NIR static libraries (required for D3D12)",
		category = "windows"
	})

	option("agility_sdk_path", {
		default = path.join(os.getenv("D3D12_DEPS_FOLDER") or "", "agility_sdk"),
		description = "Path to the Agility SDK distribution (optional for D3D12)",
		category = "windows"
	})

	option("agility_sdk_multiarch", {
		default = false,
		description = "Whether the Agility SDK DLLs will be stored in arch-specific subdirectories",
		category = "windows"
	})

	option("use_pix", {
		default = false,
		description = "Use PIX (Performance tuning and debugging for DirectX 12) runtime",
		category = "windows"
	})

	option("pix_path", {
		default = path.join(os.getenv("D3D12_DEPS_FOLDER") or "", "pix"),
		description = "Path to the PIX runtime distribution (optional for D3D12)",
		category = "windows"
	})
end

local modules_dir = path.join(os.projectdir(), "modules")
if os.isdir(modules_dir) then
    local subdirs = os.dirs(path.join(modules_dir, "*"))
    for _, subdir in ipairs(subdirs) do
        local scsub_file = path.join(subdir, "SCsub")
        if os.isfile(scsub_file) then
            local module_name = path.basename(subdir)

			local enabled = false
			if module_name == "regex" then
				enabled = true
			end
            option("module_" .. module_name, {
                default = enabled,
                description = "Enable module: " .. module_name,
				category = "Modules",
            })
        end
    end
end

function platform_linuxbsd_configure()
	add_includedirs("platform/linuxbsd")

	if is_arch("x86_64") then
		add_cflags("-msse4.2","-mpopcnt",{order = 0})
		add_cxxflags("-msse4.2","-mpopcnt",{order = 0})
	elseif is_arch("x86_32") then
		add_cflags("-msse2", "-mfpmath=sse", "-mstackrealign")
		add_cxxflags("-msse2", "-mfpmath=sse", "-mstackrealign")
	end

	add_defines("GODOT_LINUX")
end

function platform_macos_configure()
	add_includedirs("platform/macos")
	add_defines("GODOT_MACOS")
end

function platform_windows_configure()
	add_includedirs("platform/windows")
	add_defines("GODOT_WINDOWS")
end

function global_config()


	if is_plat("linux","bsd","openbsd","freebsd","netbsd") then
		platform_linuxbsd_configure()
	elseif is_plat("macos") then
		platform_macos_configure()
	elseif is_plat("windows") then
		platform_windows_configure()
	end

	add_defines("TOOLS_ENABLED")

	if is_mode("debug") then
		add_defines("DEBUG_ENABLED")
		add_defines("DEV_ENABLED")
	elseif is_mode("release") then
		add_defines("NDEBUG")
		add_defines("RELEASE_ENABLED")
		set_config("use_static_cpp", true)
	end

	if not os.isfile("../main/splash_editor.png") then
		set_config("no_editor_splash", true)
	end

	if has_config("no_editor_splash") then
		add_defines("NO_EDITOR_SPLASH")
	end

	if has_config("disable_3d") then
		add_defines("_DISABLE_3D")
	end

	if not has_config("deprecated") then
		add_defines("DISABLE_DEPRECATED")
	end

	if has_config("double_precision") then
		add_defines("REAL_T_IS_DOUBLE")
	end

	if has_config("strict_checks") then
		add_defines("STRICT_CHECKS")
	end

	if has_config("use_precise_math_checks") then
		add_defines("PRECISE_MATH_CHECKS")
	end

	if has_config("disable_advanced_gui") then
		add_defines("ADVANCED_GUI_DISABLED")
	end
	if has_config("disable_physics_2d") then
		add_defines("PHYSICS_2D_DISABLED")
	end
	if has_config("disable_physics_3d") then
		add_defines("PHYSICS_3D_DISABLED")
	end
	if has_config("disable_navigation_2d") then
		add_defines("NAVIGATION_2D_DISABLED")
	end
	if has_config("disable_navigation_3d") then
		add_defines("NAVIGATION_3D_DISABLED")
	end
	if has_config("disable_xr") then
		add_defines("XR_DISABLED")
	end
	if has_config("limit_transitive_includes") then
		add_defines("LIMIT_TRANSITIVE_INCLUDES")
	end

	if has_config("minizip") then
		add_defines("MINIZIP_ENABLED")
	end
	if has_config("brotli") then
		add_defines("BROTLI_ENABLED")
	end
	if not has_config("disable_overrides") then
		add_defines("OVERRIDES_ENABLED")
	end

	if not has_config("disable_path_overrides") then
		add_defines("PATH_OVERRIDES_ENABLED")
	end

	if has_config("threads") then
		add_defines("THREADS_ENABLED")
	end
end

