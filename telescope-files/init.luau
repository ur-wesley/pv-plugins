--!strict

type PluginLocales = {
	en: { [string]: string },
	de: { [string]: string },
}

type FileItem = {
	projectId: string,
	projectName: string,
	path: string,
	relativePath: string,
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

local plugin = {
	lazy = true,
	cmd = { "find_files" },
	dependencies = { "telescope" },
	name = "Telescope",
	description = "Fuzzy-find files across all projects in the library.",
	version = "1.0.1",
	category = "utility",
	locales = {
		en = {
			name = "Telescope",
			description = "Fuzzy-find files across all projects in the library.",
			["command.find_files"] = "Telescope: Find Files",
			dialog_title = "Telescope: Find Files",
			dialog_placeholder = "Type to search files (e.g. src/main.rs)...",
			no_projects_title = "Telescope",
			no_projects_label = "No projects in library.",
			no_projects_detail = "Add library locations first.",
			no_files_title = "Telescope",
			no_files_label = "No files found.",
			no_files_detail = "Ensure you have projects with files inside.",
			scanning_msg = "Scanning project: {name}",
			found_files_msg = "Found {count} files across projects. Opening search...",
			cancel_msg = "Search cancelled.",
			results_title = "Telescope (showing top {count} matches for '{query}')",
			results_empty_title = "Telescope (showing top {count} files)",
		},
		de = {
			name = "Teleskop",
			description = "Fuzzy-Suche nach Dateien in allen Projekten der Bibliothek.",
			["command.find_files"] = "Teleskop: Dateien finden",
			dialog_title = "Teleskop: Dateien finden",
			dialog_placeholder = "Dateien suchen (z. B. src/main.rs)...",
			no_projects_title = "Teleskop",
			no_projects_label = "Keine Projekte in der Bibliothek.",
			no_projects_detail = "Füge zuerst Bibliotheksordner hinzu.",
			no_files_title = "Teleskop",
			no_files_label = "Keine Dateien gefunden.",
			no_files_detail = "Stelle sicher, dass du Projekte mit Dateien hast.",
			scanning_msg = "Scanne Projekt: {name}",
			found_files_msg = "{count} Dateien in Projekten gefunden. Suche wird geöffnet...",
			cancel_msg = "Suche abgebrochen.",
			results_title = "Teleskop (zeige die besten {count} Treffer für '{query}')",
			results_empty_title = "Teleskop (zeige die ersten {count} Dateien)",
		},
	},
	commands = {
		{
			id = "find_files",
			title = "Telescope: Find Files",
			scope = "global",
		},
	},
}

local function get_basename(path: string): string
	local name = path:match("([^/\\]+)$")
	return name or path
end

local function get_extension(path: string): string
	return path:match("%.([^%.]+)$") or ""
end

local extension_icons: { [string]: string } = {
	rs = "mdi--language-rust",
	js = "mdi--language-javascript",
	jsx = "mdi--language-javascript",
	ts = "mdi--language-typescript",
	tsx = "mdi--language-typescript",
	json = "mdi--json",
	luau = "mdi--language-lua",
	lua = "mdi--language-lua",
	md = "mdi--markdown",
	html = "mdi--language-html5",
	css = "mdi--language-css3",
	toml = "mdi--cog-outline",
	yaml = "mdi--file-document-outline",
	yml = "mdi--file-document-outline",
	py = "mdi--language-python",
	go = "mdi--language-go",
	sh = "mdi--console",
	bat = "mdi--console",
	ps1 = "mdi--powershell",
}

local function get_icon(path: string): string
	local ext = get_extension(path):lower()
	return extension_icons[ext] or "mdi--file-outline"
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
	if command_id == "find_files" then
		local telescope = (vault :: any).plugin.require("telescope") :: TelescopeExports
		local locale = vault.i18n.get_locale()

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

		local results: { FileItem } = {}
		for _, project in ipairs(projects) do
			vault.log.info(t(locale, "scanning_msg", { name = project.name }))
			telescope.walk_files(project, function(projectId, projectName, filePath, relativePath)
				table.insert(results, {
					projectId = projectId,
					projectName = projectName,
					path = filePath,
					relativePath = relativePath,
				})
			end)
		end

		if #results == 0 then
			telescope.pick_index({
				title = t(locale, "no_files_title"),
				items = {
					{
						id = "no_files",
						label = t(locale, "no_files_label"),
						detail = t(locale, "no_files_detail"),
					},
				},
			})
			return
		end

		local items: { QuickPickItem } = {}
		for i, res in ipairs(results) do
			table.insert(items, {
				id = tostring(i),
				label = get_basename(res.path),
				detail = "[" .. res.projectName .. "] " .. res.relativePath,
				icon = get_icon(res.path),
				filePath = res.path,
				lineNumber = 1,
			})
		end

		local selected = telescope.pick_index({
			title = t(locale, "dialog_title"),
			items = items,
			fuzzy = true,
			preview = true,
		})

		if selected then
			local idx = tonumber(selected)
			if idx and results[idx] then
				local res = results[idx]
				vault.ui.open_project_file(res.projectId, res.path, 1)
			end
		end
	end
end

return plugin
