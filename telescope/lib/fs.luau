--!strict

export type FileVisitor = (projectId: string, projectName: string, filePath: string, relativePath: string) -> ()

export type VaultProject = {
	id: string,
	name: string,
	path: string,
}

local ignored_dirs: { [string]: boolean } = {
	["node_modules"] = true,
	[".git"] = true,
	["target"] = true,
	["dist"] = true,
	[".next"] = true,
	["build"] = true,
	["bin"] = true,
	["obj"] = true,
	[".svelte-kit"] = true,
	[".nuxt"] = true,
	[".turbo"] = true,
	["vendor"] = true,
}

local function get_basename(path: string): string
	local name = path:match("([^/\\]+)$")
	return name or path
end

local function is_ignored(name: string): boolean
	return ignored_dirs[name] == true
end

local function list_dir(path: string): { string }?
	local ok, entries = pcall(vault.fs.list_dir, path)
	if ok and type(entries) == "table" then
		return entries :: { string }
	end
	return nil
end

local function to_relative_path(base_path: string, entry_path: string): string
	local rel_path = entry_path
	if entry_path:sub(1, #base_path) == base_path then
		rel_path = entry_path:sub(#base_path + 1)
		if rel_path:sub(1, 1) == "/" or rel_path:sub(1, 1) == "\\" then
			rel_path = rel_path:sub(2)
		end
	end
	local normalized, _count = rel_path:gsub("\\", "/")
	return normalized
end

local function scan_folder(
	project_id: string,
	project_name: string,
	base_path: string,
	current_dir: string,
	visitor: FileVisitor
)
	local entries = list_dir(current_dir)
	if not entries then
		return
	end

	for _, entry_path in ipairs(entries) do
		local name = get_basename(entry_path)
		if vault.fs.is_dir(entry_path) then
			if not is_ignored(name) then
				scan_folder(project_id, project_name, base_path, entry_path, visitor)
			end
		elseif vault.fs.is_file(entry_path) then
			visitor(project_id, project_name, entry_path, to_relative_path(base_path, entry_path))
		end
	end
end

local function walk_files(project: VaultProject, visitor: FileVisitor)
	scan_folder(project.id, project.name, project.path, project.path, visitor)
end

return {
	walk_files = walk_files,
	get_basename = get_basename,
}
