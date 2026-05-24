add_rules("mode.debug", "mode.release")

target("zlib")
	add_rules("module.shared")
	add_files("zlib.c")
	add_includedirs("../../thirdparty/zlib")
	add_files("../../thirdparty/zlib/*.c")
