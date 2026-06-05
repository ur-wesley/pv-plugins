--!strict

type PluginLocales = {
	en: { [string]: string },
	de: { [string]: string },
}

type TodoItem = {
	projectId: string,
	projectName: string,
	path: string,
	line: number,
	text: string,
	type: string,
}

type QuickPickItem = {
	id: string,
	label: string,
	detail: string?,
	icon: string?,
}

type PluginCommandContext = {
	projectId: string?,
}

type VaultProject = {
	id: string,
	name: string,
	path: string,
}

type TelescopeExports = {
	pick_index: (options: { title: string, items: { QuickPickItem } }) -> string?,
	list_projects: () -> { VaultProject }?,
	walk_files: (
		project: VaultProject,
		visitor: (projectId: string, projectName: string, filePath: string, relativePath: string) -> ()
	) -> (),
}

local plugin = {
	lazy = true,
	cmd = { "scan_todos" },
	dependencies = { "telescope" },
	name = "TODO Scanner",
	description = "Find and navigate to TODOs, FIXMEs, BUGs, and HACKs across all workspace projects.",
	version = "1.0.1",
	category = "utility",
	locales = {
		en = {
			name = "TODO Scanner",
			description = "Find and navigate to TODOs, FIXMEs, BUGs, and HACKs across all workspace projects.",
			["command.scan_todos"] = "Scan Workspaces for TODOs",
			scanning_start = "Scanning library projects...",
			no_projects = "No active projects found in library. Add some repositories first.",
			no_todos = "No TODOs or bookmarks found in your projects.",
			dialog_title = "TODOs ({count} items found)",
			cancel_msg = "Scan cancelled.",
		},
		de = {
			name = "TODO-Scanner",
			description = "TODOs, FIXMEs, BUGs und HACKs in allen Workspace-Projekten finden und ansteuern.",
			["command.scan_todos"] = "Workspace nach TODOs durchsuchen",
			scanning_start = "Scanne Bibliotheks-Projekte...",
			no_projects = "Keine aktiven Projekte in der Bibliothek gefunden. Fügen Sie zuerst Repositories hinzu.",
			no_todos = "Keine TODOs oder Lesezeichen in Ihren Projekten gefunden.",
			dialog_title = "TODOs ({count} Einträge gefunden)",
			cancel_msg = "Suche abgebrochen.",
		},
	},
	commands = {
		{
			id = "scan_todos",
			title = "Scan Workspaces for TODOs",
			scope = "global",
		},
	},
}

local function get_basename(path: string): string
	local name = path:match("([^/\\]+)$")
	return name or path
end

local function translate(locales: PluginLocales, locale: string, key: string, args: { [string]: string }?): string
	local dict: { [string]: string } = if locale == "de" then locales.de else locales.en
	local str = dict[key] or key
	if args then
		for k, v in pairs(args) do
			str = str:gsub("{" .. k .. "}", tostring(v))
		end
	end
	return str
end

local function t(locale: string, key: string, args: { [string]: string }?): string
	return translate(plugin.locales :: PluginLocales, locale, key, args)
end

function plugin.execute(command_id: string, context: PluginCommandContext?)
	local locale = vault.i18n.get_locale()

	if command_id == "scan_todos" then
		local telescope = (vault :: any).plugin.require("telescope") :: TelescopeExports
		vault.log.info(t(locale, "scanning_start"))

		local projects = telescope.list_projects()

		if not projects or #projects == 0 then
			vault.notification.error(t(locale, "no_projects"))
			return
		end

		local results: { TodoItem } = {}
		for _, project in ipairs(projects) do
			telescope.walk_files(project, function(projectId, projectName, filePath, _relativePath)
				local ok, content = pcall(vault.fs.read_file, filePath)
				if ok and content then
					local line_no = 1
					for line in content:gmatch("([^\r\n]*)") do
						local matched_type = nil
						if line:find("TODO:") then
							matched_type = "TODO"
						elseif line:find("FIXME:") then
							matched_type = "FIXME"
						elseif line:find("BUG:") then
							matched_type = "BUG"
						elseif line:find("HACK:") then
							matched_type = "HACK"
						end

						if matched_type then
							table.insert(results, {
								projectId = projectId,
								projectName = projectName,
								path = filePath,
								line = line_no,
								text = line:gsub("^%s+", ""),
								type = matched_type,
							})
						end
						line_no = line_no + 1
					end
				end
			end)
		end

		if #results == 0 then
			vault.notification.info(t(locale, "no_todos"))
			return
		end

		local items: { QuickPickItem } = {}
		for i, res in ipairs(results) do
			local icon = "mdi--bookmark-outline"
			if res.type == "BUG" then
				icon = "mdi--bug-outline"
			elseif res.type == "FIXME" then
				icon = "mdi--alert-circle-outline"
			elseif res.type == "HACK" then
				icon = "mdi--fire"
			end

			table.insert(items, {
				id = tostring(i),
				label = string.format("[%s] %s:%d", res.type, get_basename(res.path), res.line),
				detail = string.format("%s » %s", res.projectName, res.text),
				icon = icon,
			})
		end

		local selected = telescope.pick_index({
			title = t(locale, "dialog_title", { count = tostring(#results) }),
			items = items,
		})

		if selected then
			local idx = tonumber(selected)
			if idx and results[idx] then
				local res = results[idx]
				vault.ui.open_project_file(res.projectId, res.path, res.line)
			end
		else
			vault.log.info(t(locale, "cancel_msg"))
		end
	end
end

return plugin
