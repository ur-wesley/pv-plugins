--!strict

local locales = (require :: any)("./locales")
local i18n = (require :: any)("./i18n")
local projects = (require :: any)("./projects")
local footer = (require :: any)("./footer")
local header = (require :: any)("./header")
local commits = (require :: any)("./commits")
local branches = (require :: any)("./branches")
local sync = (require :: any)("./sync")
local decorations = (require :: any)("./decorations")
local settings = (require :: any)("./settings")

type PluginCommandContext = {
	projectId: string?,
	elementId: string?,
}

local plugin = {
	lazy = true,
	cmd = { "view_commits", "switch_branch", "pull", "push", "show_settings" },
	event = { "project_focus" },
	name = "Git",
	description = "Git integration with commits, branches, sync, header widgets, and file decorations.",
	version = "2.0.0",
	category = "utility",
	locales = locales,
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

local translate = i18n.create(locales)
local t = translate.t

local function sync_header(project_id: string)
	header.sync(project_id, {
		show_header = vault.settings.get("show_header") ~= "false",
	})
end

local function on_focus(project_id: string?, locale: string)
	footer.update(project_id, t, locale)
	if project_id and project_id ~= "" then
		sync_header(project_id)
	else
		header.clear()
	end
	local is_viewing_commits = vault.settings.get("is_viewing_commits") == "true"
	if is_viewing_commits then
		commits.refresh(project_id, locale, t, false)
	end
end

function plugin.get_decorations(project_id: string, tab_id: string, element_ids: { string })
	return decorations.for_elements(project_id, tab_id, element_ids)
end

function plugin.execute(command_id: string, context: PluginCommandContext?)
	local locale = vault.i18n.get_locale()

	if command_id == "init" or command_id == "project_focus" or command_id == "project_state_changed" then
		on_focus(projects.resolve_focus_id(context), locale)
		return
	end

	if command_id == "markdown_dialog_closed" then
		vault.settings.set("is_viewing_commits", "false")
		return
	end

	if command_id == "show_settings" then
		local project_id = projects.resolve_active_id(context)
		settings.show(project_id, locale, t)
		return
	end

	if command_id == "switch_branch" then
		local project_id = projects.resolve_active_id(context)
		if not project_id or project_id == "" then
			vault.notification.error(t(locale, "no_active_project"))
			return
		end
		local is_viewing_commits = vault.settings.get("is_viewing_commits") == "true"
		branches.switch(project_id, locale, t, is_viewing_commits)
		return
	end

	if command_id == "view_commits" then
		local project_id = projects.resolve_active_id(context)
		if not project_id or project_id == "" then
			vault.notification.error(t(locale, "no_active_project"))
			return
		end
		vault.settings.set("is_viewing_commits", "true")
		commits.refresh(project_id, locale, t, true)
		return
	end

	if command_id == "pull" or command_id == "push" then
		local project_id = projects.resolve_active_id(context)
		if not project_id or project_id == "" then
			vault.notification.error(t(locale, "no_active_project"))
			return
		end
		if command_id == "pull" then
			sync.run(project_id, locale, t, { "pull" }, "pull", "pull_success", "pull_error")
		else
			sync.run(project_id, locale, t, { "push" }, "push", "push_success", "push_error")
		end
	end
end

return plugin
