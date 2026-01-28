target("core")
    set_kind("static")
    add_includedirs(".")
    add_includedirs("..", {public = true})

    -- =========================
    -- 第三方库
    -- =========================

    -- misc
    add_includedirs("../thirdparty/misc")
    add_files("../thirdparty/misc/*.c")
    add_files("../thirdparty/misc/*.cpp")

    -- Brotli
    if get_config("builtin_brotli") then
        add_includedirs("../thirdparty/brotli/include", {public = true})
        add_includedirs("../thirdparty/brotli")
        add_files("../thirdparty/brotli/common/*.c")
        add_files("../thirdparty/brotli/dec/*.c")
        add_defines("BROTLI_ENABLED")
    end

    -- Clipper2
    if get_config("builtin_clipper2") then
        add_includedirs("../thirdparty/clipper2/include", {public = true})
        add_files("../thirdparty/clipper2/src/*.cpp")
        add_defines("CLIPPER2_ENABLED")
    end

    -- Zlib
    if get_config("builtin_zlib") then
        add_includedirs("../thirdparty/zlib", {public = true})
        add_files("../thirdparty/zlib/*.c")
        add_defines("ZLIB_ENABLED")
    end

    -- Minizip（总是启用）
    add_includedirs("../thirdparty/minizip")
    add_files("../thirdparty/minizip/*.c")

    -- Zstd
    if get_config("builtin_zstd") then
        add_includedirs("../thirdparty/zstd", {public = true})
        add_includedirs("../thirdparty/zstd/common", {public = true})
        add_files("../thirdparty/zstd/common/*.c")
        add_files("../thirdparty/zstd/compress/*.c")
        add_files("../thirdparty/zstd/decompress/*.c")
        if get_config("arch") == "x86_64" and is_plat("windows", "linux", "macos") then
            add_files("../thirdparty/zstd/decompress/*.S")
        end
        add_defines("ZSTD_STATIC_LINKING_ONLY")
    end

    -- =========================
    -- core 源文件
    -- =========================

    add_files("*.cpp")
    add_files("config/*.cpp")
    add_files("crypto/*.cpp")
    add_files("debugger/*.cpp")
    add_files("error/*.cpp")
    add_files("extension/*.cpp")
    add_files("input/*.cpp")
    add_files("io/*.cpp")
    add_files("math/*.cpp")
    add_files("object/*.cpp")
    add_files("os/*.cpp")
    add_files("profiling/*.cpp")
    add_files("string/*.cpp")
    add_files("templates/*.cpp")
    add_files("variant/*.cpp")

    set_targetdir("$(buildir)/lib")
target_end()
