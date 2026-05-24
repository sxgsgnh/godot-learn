add_moduledirs("../xmake")

target("core")
    set_kind("static")
	set_default(false)
    set_targetdir("$(builddir)/lib")
    add_includedirs(".")
	add_files("**.cpp")

	--add_deps("lua_zlib")

	on_config(function (target)
		import("builder.core")(os.scriptdir())
		import("builder.core_make_interface_header")(os.scriptdir())
	end)

    add_files(
		-- C sources
		"../thirdparty/misc/fastlz.c",
		"../thirdparty/misc/r128.c",
		"../thirdparty/misc/smaz.c",
		-- C++ sources
		"../thirdparty/misc/pcg.cpp",
		"../thirdparty/misc/polypartition.cpp",
		"../thirdparty/misc/smolv.cpp")

    if has_config("brotli") and has_config("builtin_brotli") then
        add_includedirs("../thirdparty/brotli/common",
						"../thirdparty/brotli/dec",
						"../thirdparty/brotli/include")

        add_files("../thirdparty/brotli/common/*.c",
				  "../thirdparty/brotli/dec/*.c")
    end
    if get_config("builtin_clipper2") then
        add_includedirs("../thirdparty/clipper2/include", {public = true})
        add_files("../thirdparty/clipper2/src/*.cpp")
    end
    -- Zlib
    if get_config("builtin_zlib") then
        add_includedirs("../thirdparty/zlib", {public = true})
        add_files("../thirdparty/zlib/*.c")
        if is_mode("debug") then
			add_defines("ZLIB_DEBUG")
		end
    end

    -- Minizip（总是启用）
    add_includedirs("../thirdparty/minizip")
    add_files("../thirdparty/minizip/*.c")

    -- Zstd
    if get_config("builtin_zstd") then
        add_includedirs("../thirdparty/zstd",
						"../thirdparty/zstd/common",
						"../thirdparty/zstd/compress",
						"../thirdparty/zstd/decompress")
		add_files("../thirdparty/zstd/**.c")
        if get_config("arch") == "x86_64" and is_plat("windows", "linux", "macos") then
            add_files("../thirdparty/zstd/decompress/huf_decompress_amd64.S")
        end
		add_defines("ZSTD_STATIC_LINKING_ONLY")
    end


target_end()
