--!strict

type PluginLocales = {
	en: { [string]: string },
	de: { [string]: string },
}

type SearchResult = {
	projectId: string,
	path: string,
	line: number,
	text: string,
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
	cmd = { "search_all" },
	dependencies = { "telescope" },
	name = "Live Grep",
	description = "Search text across all files in all library projects.",
	version = "1.0.1",
	category = "utility",
	locales = {
		en = {
			name = "Live Grep",
			description = "Search text across all files in all library projects.",
			["command.search_all"] = "Live Grep",
			dialog_title = "Live Grep",
			dialog_placeholder = "Enter search term...",
			cancel_msg = "Search cancelled or empty query.",
			searching_msg = "Searching all projects for: {query}",
			scanning_msg = "Scanning project: {name} ({path})",
			no_projects_title = "Live Grep",
			no_projects_label = "No projects in library.",
			no_projects_detail = "Add library locations first.",
			no_matches_title = "Live Grep: '{query}'",
			no_matches_label = "No matches found.",
			no_matches_detail = "No files match the term '{query}'.",
			results_title = "Live Grep: '{query}' ({count} matches)",
		},
		de = {
			name = "Live Grep",
			description = "Textsuche in allen Dateien aller Bibliotheksprojekte.",
			["command.search_all"] = "Live Grep",
			dialog_title = "Live Grep",
			dialog_placeholder = "Suchbegriff eingeben...",
			cancel_msg = "Suche abgebrochen oder leere Anfrage.",
			searching_msg = "Suche in allen Projekten nach: {query}",
			scanning_msg = "Scanne Projekt: {name} ({path})",
			no_projects_title = "Live Grep",
			no_projects_label = "Keine Projekte in der Bibliothek.",
			no_projects_detail = "Füge zuerst Bibliotheksordner hinzu.",
			no_matches_title = "Live Grep: '{query}'",
			no_matches_label = "Keine Treffer gefunden.",
			no_matches_detail = "Keine Dateien entsprechen dem Begriff '{query}'.",
			results_title = "Live Grep: '{query}' ({count} Treffer)",
		},
	},
	commands = {
		{
			id = "search_all",
			title = "Live Grep",
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
	if command_id == "search_all" then
		local telescope = (vault :: any).plugin.require("telescope") :: TelescopeExports
		local locale = vault.i18n.get_locale()

		local query = vault.ui.show_input_box({
			title = t(locale, "dialog_title"),
			placeholder = t(locale, "dialog_placeholder"),
		})

		if not query or query == "" then
			vault.log.info(t(locale, "cancel_msg"))
			return
		end

		vault.log.info(t(locale, "searching_msg", { query = query }))

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

		local lower_query = query:lower()
		local results: { SearchResult } = {}
		for _, project in ipairs(projects) do
			vault.log.info(t(locale, "scanning_msg", { name = project.name, path = project.path }))
			telescope.walk_files(project, function(projectId, _projectName, filePath, _relativePath)
				local ok, content = pcall(vault.fs.read_file, filePath)
				if ok and content then
					local lower_content = content:lower()
					if lower_content:find(lower_query, 1, true) then
						local line_no = 1
						for line in content:gmatch("([^\r\n]*)") do
							if line:lower():find(lower_query, 1, true) then
								table.insert(results, {
									projectId = projectId,
									path = filePath,
									line = line_no,
									text = line:gsub("^%s+", ""),
								})
							end
							line_no = line_no + 1
						end
					end
				end
			end)
		end

		if #results == 0 then
			telescope.pick_index({
				title = t(locale, "no_matches_title", { query = query }),
				items = {
					{
						id = "no_matches",
						label = t(locale, "no_matches_label"),
						detail = t(locale, "no_matches_detail", { query = query }),
					},
				},
			})
			return
		end

		local items: { QuickPickItem } = {}
		for i, res in ipairs(results) do
			table.insert(items, {
				id = tostring(i),
				label = get_basename(res.path) .. ":" .. tostring(res.line),
				detail = res.text,
				icon = "mdi--file-find-outline",
			})
		end

		local selected = telescope.pick_index({
			title = t(locale, "results_title", { query = query, count = tostring(#results) }),
			items = items,
		})

		if selected then
			local idx = tonumber(selected)
			if idx and results[idx] then
				local res = results[idx]
				vault.ui.open_project_file(res.projectId, res.path, res.line)
			end
		end
	end
end

return plugin
