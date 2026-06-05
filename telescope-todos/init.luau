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
	filePath: string?,
	lineNumber: number?,
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
	pick_index: (options: {
		title: string,
		items: { QuickPickItem },
		fuzzy: boolean?,
		preview: boolean?,
	}) -> string?,
	list_projects: () -> { VaultProject }?,
	walk_files: (
		project: VaultProject,
		visitor: (projectId: string, projectName: string, filePath: string, relativePath: string) -> ()
	) -> (),
}

local MARKERS = { "TODO", "FIXME", "BUG", "HACK" }

local plugin = {
	lazy = true,
	cmd = { "scan_todos" },
	dependencies = {
		"telescope",
		{ id = "telescope", repo = "https://github.com/ur-wesley/pv-plugins", dir = "telescope" },
	},
	name = "TODO Scanner",
	description = "Find and navigate to TODOs, FIXMEs, BUGs, and HACKs across all workspace projects.",
	version = "1.0.2",
	category = "utility",
	locales = {
		en = {
			name = "TODO Scanner",
			description = "Find and navigate to TODOs, FIXMEs, BUGs, and HACKs across all workspace projects.",
			["command.scan_todos"] = "Scan Workspaces for TODOs",
			scanning_start = "Scanning library projects...",
			scanning_msg = "Scanning project: {name}",
			no_projects_title = "TODO Scanner",
			no_projects_label = "No projects in library.",
			no_projects_detail = "Add library locations first.",
			no_todos_title = "TODO Scanner",
			no_todos_label = "No TODOs found.",
			no_todos_detail = "No TODO, FIXME, BUG, or HACK markers found in your projects.",
			dialog_title = "TODOs ({count} items found)",
			cancel_msg = "Scan cancelled.",
		},
		de = {
			name = "TODO-Scanner",
			description = "TODOs, FIXMEs, BUGs und HACKs in allen Workspace-Projekten finden und ansteuern.",
			["command.scan_todos"] = "Workspace nach TODOs durchsuchen",
			scanning_start = "Scanne Bibliotheks-Projekte...",
			scanning_msg = "Scanne Projekt: {name}",
			no_projects_title = "TODO-Scanner",
			no_projects_label = "Keine Projekte in der Bibliothek.",
			no_projects_detail = "Füge zuerst Bibliotheksordner hinzu.",
			no_todos_title = "TODO-Scanner",
			no_todos_label = "Keine TODOs gefunden.",
			no_todos_detail = "Keine TODO-, FIXME-, BUG- oder HACK-Markierungen in deinen Projekten gefunden.",
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

local function match_marker(line: string): string?
	local upper = line:upper()
	for _, marker in ipairs(MARKERS) do
		local start = 1
		while true do
			local s, e = upper:find(marker, start, true)
			if s == nil or e == nil then
				break
			end
			local prev = if s > 1 then upper:sub(s - 1, s - 1) else ""
			local next_char = upper:sub(e + 1, e + 1)
			if prev:match("%w") then
				start = e + 1
				continue
			end
			if next_char == "" or next_char == ":" or next_char == " " or next_char == "\t" then
				return marker
			end
			start = e + 1
		end
	end
	return nil
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
	if command_id == "scan_todos" then
		local telescope = (vault :: any).plugin.require("telescope") :: TelescopeExports
		local locale = vault.i18n.get_locale()

		vault.log.info(t(locale, "scanning_start"))

		local projects = telescope.list_projects()

		if not projects or #projects == 0 then
			telescope.pick_index({
				title = t(locale, "no_projects_title"),
				items = {
					{
						id = "no_projects",
						label = t(locale, "no_projects_label"),
						detail = t(locale, "no_projects_detail"),
					},
				},
			})
			return
		end

		local results: { TodoItem } = {}
		for _, project in ipairs(projects) do
			vault.log.info(t(locale, "scanning_msg", { name = project.name }))
			telescope.walk_files(project, function(projectId, projectName, filePath, _relativePath)
				local ok, content = pcall(vault.fs.read_file, filePath)
				if ok and content then
					local line_no = 1
					for line in content:gmatch("([^\r\n]*)") do
						local matched_type = match_marker(line)
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
			telescope.pick_index({
				title = t(locale, "no_todos_title"),
				items = {
					{
						id = "no_todos",
						label = t(locale, "no_todos_label"),
						detail = t(locale, "no_todos_detail"),
					},
				},
			})
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
				filePath = res.path,
				lineNumber = res.line,
			})
		end

		local selected = telescope.pick_index({
			title = t(locale, "dialog_title", { count = tostring(#results) }),
			items = items,
			fuzzy = true,
			preview = true,
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
