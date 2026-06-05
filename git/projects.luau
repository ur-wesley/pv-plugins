--!strict

export type VaultProject = {
	id: string,
	name: string,
	path: string,
}

export type PluginCommandContext = {
	projectId: string?,
	elementId: string?,
}

local function parse(raw: string): { VaultProject }?
	local ok, parsed = pcall(function()
		return vault.json.parse(raw)
	end)
	if ok and type(parsed) == "table" then
		return parsed :: { VaultProject }
	end
	return nil
end

local function resolve_focus_id(context: PluginCommandContext?): string?
	if context and context.projectId ~= nil then
		if context.projectId == "" then
			return nil
		end
		return context.projectId
	end
	return vault.projects.get_active()
end

local function resolve_active_id(context: PluginCommandContext?): string?
	local project_id = context and context.projectId
	if not project_id or project_id == "" then
		project_id = vault.projects.get_active()
	end
	return project_id
end

local function find(project_id: string): VaultProject?
	local projects = parse(vault.projects.list())
	if not projects then
		return nil
	end
	for _, project in ipairs(projects) do
		if project.id == project_id then
			return project
		end
	end
	return nil
end

local function name_for(project_id: string): string
	local project = find(project_id)
	if project then
		return project.name
	end
	return "Repository"
end

return {
	parse = parse,
	resolve_focus_id = resolve_focus_id,
	resolve_active_id = resolve_active_id,
	find = find,
	name_for = name_for,
}
