--!strict

type GitHeaderModule = {
	sync_header: (string, { show_header: boolean? }?) -> (),
	clear_header: () -> (),
}

local git_header_cache: GitHeaderModule? = nil

local function git_header(): GitHeaderModule
	if not git_header_cache then
		git_header_cache = (require :: any)("../git-shared/header") :: GitHeaderModule
	end
	return git_header_cache :: GitHeaderModule
end

type PluginLocales = {
	en: { [string]: string },
	de: { [string]: string },
}

type PluginCommandContext = {
	projectId: string?,
	elementId: string?,
}

local plugin = {
	lazy = true,
	cmd = { "show_settings" },
	name = "Git Enrichment",
	description = "Enriches your workspace with branch info, git pull actions, settings forms, and file/task status decorations.",
	version = "1.0.1",
	category = "utility",
	locales = {
		en = {
			name = "Git Enrichment",
			description = "Enriches your workspace with branch info, git pull actions, settings forms, and file/task status decorations.",
			["command.show_settings"] = "Git Enrichment: Configure Settings",
			settings_saved = "Settings saved successfully!",
		},
		de = {
			name = "Git-Erweiterung",
			description = "Erweitert den Arbeitsbereich um Branch-Infos, Git-Pull-Aktionen, Einstellungsformulare sowie Datei- und Task-Status-Markierungen.",
			["command.show_settings"] = "Git-Erweiterung: Einstellungen konfigurieren",
			settings_saved = "Einstellungen erfolgreich gespeichert!",
		},
	},
	config = {
		{
			key = "show_header",
			type = "boolean",
			label = "Show in Project Header",
			description = "If enabled, displays the current Git branch and status in the project detail header.",
			default = true,
		},
		{
			key = "decorate_files",
			type = "boolean",
			label = "Decorate Files",
			description = "Enable status icons next to modified, added, and untracked files in the file tree.",
			default = true,
		},
	},
	commands = {
		{ id = "show_settings", title = "Git Enrichment: Configure Settings", scope = "global" },
	},
}

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

local function sync_header(project_id: string)
	git_header().sync_header(project_id, {
		show_header = vault.settings.get("show_header") ~= "false",
	})
end

function plugin.get_decorations(project_id: string, tab_id: string, element_ids: { string })
	local decs = {}

	if tab_id == "files" then
		local decorate = vault.settings.get("decorate_files") ~= "false"
		if not decorate then
			return decs
		end

		local res = vault.git.run(project_id, { "status", "--porcelain" })
		if not res.success then
			return decs
		end

		local status_map = {}
		for line in res.stdout:gmatch("[^\r\n]+") do
			if #line >= 4 then
				local code = line:sub(1, 2)
				local file_path = line:sub(4)
				if file_path:sub(1, 1) == '"' and file_path:sub(-1) == '"' then
					file_path = file_path:sub(2, -2)
				end

				local icon, color, label, tooltip
				if code == " M" or code == "M " then
					icon = "mdi--pencil"
					color = "#eab308"
					label = "M"
					tooltip = "Modified file"
				elseif code == "??" then
					icon = "mdi--plus"
					color = "#22c55e"
					label = "U"
					tooltip = "Untracked file"
				elseif code == " A" or code == "A " then
					icon = "mdi--plus"
					color = "#22c55e"
					label = "A"
					tooltip = "Added to index"
				end

				if label then
					status_map[file_path] = {
						before = {
							{
								icon = icon,
								color = color,
								tooltip = tooltip,
							},
						},
						after = {
							{
								label = label,
								color = color == "#eab308" and "bg-yellow-500/10 text-yellow-600 border-yellow-500/25"
									or "bg-green-500/10 text-green-600 border-green-500/25",
								tooltip = tooltip,
							},
						},
					}
				end
			end
		end

		for _, el_id in ipairs(element_ids) do
			if status_map[el_id] then
				decs[el_id] = status_map[el_id]
			end
		end
	elseif tab_id == "tasks" then
		for _, el_id in ipairs(element_ids) do
			local lower_id = el_id:lower()
			if lower_id:find("git") or lower_id:find("pull") or lower_id:find("push") or lower_id:find("sync") then
				decs[el_id] = {
					before = {
						{
							icon = "mdi--git",
							color = "#f05032",
							tooltip = "Executes a Git-related command",
						},
					},
				}
			end
		end
	end

	return decs
end

function plugin.execute(command_id: string, context: PluginCommandContext?)
	local locale = vault.i18n.get_locale()
	local project_id = context and context.projectId or vault.projects.get_active()

	if command_id == "show_settings" then
		local current_header = vault.settings.get("show_header") ~= "false"
		local current_dec = vault.settings.get("decorate_files") ~= "false"
		local res = vault.ui.show_form({
			title = "Git Enrichment Settings",
			fields = {
				{
					id = "show_header",
					label = "Show Branch and Status in Project Header",
					fieldType = "boolean",
					defaultValue = current_header,
					required = false,
				},
				{
					id = "decorate_files",
					label = "Decorate Files in File Tree",
					fieldType = "boolean",
					defaultValue = current_dec,
					required = false,
				},
				{
					id = "verification_check",
					label = "Verification check (regex pattern match test)",
					fieldType = "text",
					placeholder = "Type something starting with 'Git'...",
					pattern = "^Git.*",
					validationMessage = "Validation Error: Must start with 'Git'",
				},
			},
		})
		if res then
			vault.settings.set("show_header", tostring(res.show_header))
			vault.settings.set("decorate_files", tostring(res.decorate_files))
			vault.notification.success(t(locale, "settings_saved"))
			if project_id and project_id ~= "" then
				sync_header(project_id)
				local payload = vault.json.stringify({ projectId = project_id, changeType = "git" })
				vault.event.publish("project:changed", payload)
			end
		end
	elseif command_id == "init" then
		if project_id and project_id ~= "" then
			sync_header(project_id)
		end
	elseif command_id == "project_focus" then
		if project_id and project_id ~= "" then
			sync_header(project_id)
		else
			git_header().clear_header()
		end
	end
end

return plugin
