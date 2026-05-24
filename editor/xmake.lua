add_moduledirs("../xmake")
target("editor")
    set_kind("binary")

	on_config(function (target,option)
		import("builder.editor")("/home/sgnh")
	end)
    -- Include 路径
    add_includedirs(".")
	add_files("**.cpp")
    add_defines("EDITOR_ENABLED", "TOOLS_ENABLED")
    --add_deps("core", "servers", "scene", "main")

    set_targetdir("$(builddir)/lib")

target_end()
