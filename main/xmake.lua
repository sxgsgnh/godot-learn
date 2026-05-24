add_moduledirs("../xmake")

target("main")
    set_kind("static")

    -- Include 路径
    add_includedirs(".")
    set_targetdir("$(builddir)/lib")
    add_files("*.cpp")
    --add_deps("core", "servers", "scene")
	on_config(function (tar)
		import("builder.main").make_main_gen_code("/home/sgnh")
	end)
target_end()
