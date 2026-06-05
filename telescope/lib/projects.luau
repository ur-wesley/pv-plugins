--!strict

export type VaultProject = {
	id: string,
	name: string,
	path: string,
}

local function parse_projects(raw: string): { VaultProject }?
	local ok, parsed = pcall(function()
		return vault.json.parse(raw)
	end)
	if ok and type(parsed) == "table" then
		return parsed :: { VaultProject }
	end
	return nil
end

local function list_projects(): { VaultProject }?
	return parse_projects(vault.projects.list())
end

return {
	list_projects = list_projects,
}
