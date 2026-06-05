--!strict

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
	cmd = { "view_commits", "switch_branch", "pull", "push", "show_settings" },
	event = { "project_focus", "startup" },
	name = "Git",
	description = "Git integration with commits, branches, sync, header widgets, and file decorations.",
	version = "2.0.0",
	category = "utility",
	locales = {
		en = {
			name = "Git",
			description = "Git integration with commits, branches, sync, header widgets, and file decorations.",
			["command.view_commits"] = "Git: View Last Commits",
			["command.switch_branch"] = "Git: Switch Branch",
			["command.pull"] = "Git: Pull Remote Changes",
			["command.push"] = "Git: Push Local Changes",
			["command.show_settings"] = "Git: Configure Settings",
			pull_success = "Git pull completed successfully!",
			pull_error = "Git pull failed: {err}",
			push_success = "Git push completed successfully!",
			push_error = "Git push failed: {err}",
			sync_running = "Running git {action}...",
			no_active_project = "Git: No active project is currently selected.",
			no_git_repo = "This project is not a Git repository.",
			error_loading = "Failed to load Git logs.",
			dirty = "dirty",
			clean = "clean",
			status_tooltip = "Branch: {branch} ({state})",
			dialog_title = "Git Commits — {name}",
			error_loading_branches = "Failed to load Git branches.",
			current_branch = "Current Branch",
			no_branches_found = "No Git branches found.",
			switch_branch_title = "Select Branch to Checkout",
			already_on_branch = "Already on branch '{branch}'.",
			switch_success = "Successfully switched to branch '{branch}'!",
			switch_error = "Failed to switch to '{branch}': {error}",
			settings_saved = "Settings saved successfully!",
			settings_title = "Git Settings",
		},
		de = {
			name = "Git",
			description = "Git-Integration mit Commits, Branches, Sync, Header-Widgets und Datei-Markierungen.",
			["command.view_commits"] = "Git: Letzte Commits anzeigen",
			["command.switch_branch"] = "Git: Branch wechseln",
			["command.pull"] = "Git: Remote-Änderungen abrufen (Pull)",
			["command.push"] = "Git: Lokale Änderungen hochladen (Push)",
			["command.show_settings"] = "Git: Einstellungen konfigurieren",
			pull_success = "Git Pull erfolgreich abgeschlossen!",
			pull_error = "Git Pull fehlgeschlagen: {err}",
			push_success = "Git Push erfolgreich abgeschlossen!",
			push_error = "Git Push fehlgeschlagen: {err}",
			sync_running = "Git {action} wird ausgeführt...",
			no_active_project = "Git: Es ist derzeit kein aktives Projekt ausgewählt.",
			no_git_repo = "Dieses Projekt ist kein Git-Repository.",
			error_loading = "Fehler beim Laden der Git-Logs.",
			dirty = "geändert",
			clean = "sauber",
			status_tooltip = "Branch: {branch} ({state})",
			dialog_title = "Git-Commits — {name}",
			error_loading_branches = "Fehler beim Laden der Git-Branches.",
			current_branch = "Aktueller Branch",
			no_branches_found = "Keine Git-Branches gefunden.",
			switch_branch_title = "Branch zum Auschecken auswählen",
			already_on_branch = "Bereits auf Branch '{branch}'.",
			switch_success = "Erfolgreich zum Branch '{branch}' gewechselt!",
			switch_error = "Fehler beim Wechseln zu '{branch}': {error}",
			settings_saved = "Einstellungen erfolgreich gespeichert!",
			settings_title = "Git-Einstellungen",
		},
	},
	config = {
		{
			key = "show_branch",
			type = "boolean",
			label = "Show Branch",
			description = "If enabled, displays the current Git branch name in the status bar footer.",
			default = true,
		},
		{
			key = "show_tag",
			type = "boolean",
			label = "Show Latest Tag",
			description = "If enabled, displays the latest tag (release version) in the status bar footer.",
			default = false,
		},
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
		{ id = "view_commits", title = "Git: View Last Commits", scope = "project" },
		{ id = "switch_branch", title = "Git: Switch Branch", scope = "project" },
		{ id = "pull", title = "Git: Pull Remote Changes", scope = "global" },
		{ id = "push", title = "Git: Push Local Changes", scope = "global" },
		{ id = "show_settings", title = "Git: Configure Settings", scope = "global" },
	},
}

local projects_mod: any = nil
local footer_mod: any = nil
local header_mod: any = nil
local commits_mod: any = nil
local branches_mod: any = nil
local sync_mod: any = nil
local decorations_mod: any = nil
local settings_mod: any = nil

local function projects()
	if not projects_mod then
		projects_mod = (require :: any)("./projects")
	end
	return projects_mod
end

local function footer()
	if not footer_mod then
		footer_mod = (require :: any)("./footer")
	end
	return footer_mod
end

local function header()
	if not header_mod then
		header_mod = (require :: any)("./header")
	end
	return header_mod
end

local function commits()
	if not commits_mod then
		commits_mod = (require :: any)("./commits")
	end
	return commits_mod
end

local function branches()
	if not branches_mod then
		branches_mod = (require :: any)("./branches")
	end
	return branches_mod
end

local function sync()
	if not sync_mod then
		sync_mod = (require :: any)("./sync")
	end
	return sync_mod
end

local function decorations()
	if not decorations_mod then
		decorations_mod = (require :: any)("./decorations")
	end
	return decorations_mod
end

local function settings()
	if not settings_mod then
		settings_mod = (require :: any)("./settings")
	end
	return settings_mod
end

local function t(locale: string, key: string, args: { [string]: string }?): string
	local locales = plugin.locales :: PluginLocales
	local dict: { [string]: string } = if locale == "de" then locales.de else locales.en
	local str = dict[key] or key
	if args then
		for k, v in pairs(args) do
			str = str:gsub("{" .. k .. "}", tostring(v))
		end
	end
	return str
end

local function sync_header(project_id: string)
	header().sync(project_id, {
		show_header = vault.settings.get("show_header") ~= "false",
	})
end

local function on_focus(project_id: string?, locale: string)
	footer().update(project_id, t, locale)
	if project_id and project_id ~= "" then
		sync_header(project_id)
	else
		header().clear()
	end
	local is_viewing_commits = vault.settings.get("is_viewing_commits") == "true"
	if is_viewing_commits then
		commits().refresh(project_id, locale, t, false)
	end
end

function plugin.get_decorations(project_id: string, tab_id: string, element_ids: { string })
	return decorations().for_elements(project_id, tab_id, element_ids)
end

function plugin.execute(command_id: string, context: PluginCommandContext?)
	local locale = vault.i18n.get_locale()
	local projects_api = projects()

	if command_id == "init" or command_id == "startup" or command_id == "project_focus" or command_id == "project_state_changed" then
		on_focus(projects_api.resolve_focus_id(context), locale)
		return
	end

	if command_id == "markdown_dialog_closed" then
		vault.settings.set("is_viewing_commits", "false")
		return
	end

	if command_id == "show_settings" then
		settings().show(projects_api.resolve_active_id(context), locale, t)
		return
	end

	if command_id == "switch_branch" then
		local project_id = projects_api.resolve_active_id(context)
		if not project_id or project_id == "" then
			vault.notification.error(t(locale, "no_active_project"))
			return
		end
		local is_viewing_commits = vault.settings.get("is_viewing_commits") == "true"
		branches().switch(project_id, locale, t, is_viewing_commits)
		return
	end

	if command_id == "view_commits" then
		local project_id = projects_api.resolve_active_id(context)
		if not project_id or project_id == "" then
			vault.notification.error(t(locale, "no_active_project"))
			return
		end
		vault.settings.set("is_viewing_commits", "true")
		commits().refresh(project_id, locale, t, true)
		return
	end

	if command_id == "pull" or command_id == "push" then
		local project_id = projects_api.resolve_active_id(context)
		if not project_id or project_id == "" then
			vault.notification.error(t(locale, "no_active_project"))
			return
		end
		if command_id == "pull" then
			sync().run(project_id, locale, t, { "pull" }, "pull", "pull_success", "pull_error")
		else
			sync().run(project_id, locale, t, { "push" }, "push", "push_success", "push_error")
		end
	end
end

return plugin
