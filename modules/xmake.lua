

for _, subdir in ipairs(os.dirs(os.projectdir() .. "/modules/*")) do
	local name = path.basename(subdir)
	if not get_config("module_" .. name) and os.isfile(subdir .. "/SCsub") then
		print(name)
		--includes(module)
	end
end




target("modules")
    set_kind("static")
    -- Include 路径
    add_includedirs(".")
    set_targetdir("$(builddir)/lib")
target_end()
