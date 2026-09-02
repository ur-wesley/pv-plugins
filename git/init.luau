--!strict

type PluginLocales = {
	en: { [string]: string },
	de: { [string]: string },
}

type PluginCommandContext = {
	projectId: string?,
	elementId: string?,
}

type GitCommit = {
	hash: string,
	author: string,
	email: string,
	subject: string,
	date: string,
	relativeDate: string,
}

type GitStatus = {
	branch: string,
	ahead: number,
	behind: number,
	isDirty: boolean,
	hasUpstream: boolean,
	version: string?,
}

type VaultProject = {
	id: string,
	name: string,
	path: string,
}

type VaultQuickPickItem = {
	id: string,
	label: string,
	detail: string?,
	icon: string?,
}

local locales = (require :: any)("./locales")

local plugin = {
	lazy = false,
	cmd = { "view_commits", "switch_branch", "pull", "push", "show_settings" },
	event = { "project_focus", "git_status_changed" },
	name = "Git",
	description = "Git integration with commits, branches, sync, header widgets, and file decorations.",
	version = "2.0.3",
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

local function parse_projects(raw: string): { VaultProject }?
	local ok, parsed = pcall(function()
		return vault.json.parse(raw)
	end)
	if ok and type(parsed) == "table" then
		return parsed :: { VaultProject }
	end
	return nil
end

local function parse_git_status(raw: string): GitStatus?
	local ok, parsed = pcall(function()
		return vault.json.parse(raw)
	end)
	if ok and type(parsed) == "table" then
		return parsed :: GitStatus
	end
	return nil
end

local function parse_git_commits(raw: string): { GitCommit }?
	local ok, parsed = pcall(function()
		return vault.json.parse(raw)
	end)
	if ok and type(parsed) == "table" then
		return parsed :: { GitCommit }
	end
	return nil
end

local function resolve_focus_project_id(context: PluginCommandContext?): string?
	if context and context.projectId ~= nil then
		if context.projectId == "" then
			return nil
		end
		return context.projectId
	end
	return vault.projects.get_active()
end

local function resolve_active_project_id(context: PluginCommandContext?): string?
	local project_id = context and context.projectId
	if not project_id or project_id == "" then
		project_id = vault.projects.get_active()
	end
	return project_id
end

local function find_project(project_id: string): VaultProject?
	local projects = parse_projects(vault.projects.list())
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

local function project_name_for(project_id: string): string
	local project = find_project(project_id)
	if project then
		return project.name
	end
	return "Repository"
end

local function clear_git_footer()
	pcall(vault.ui.clear_footer, "git-branch")
end

local function clear_git_header()
	vault.ui.clear_header_widget("git_branch")
	vault.ui.clear_header_widget("git_status_badge")
end

local function get_git_status(project_id: string): GitStatus?
	local ok, status_json = pcall(vault.git.get_status, project_id)
	if not ok or not status_json or status_json == "null" or status_json == "" then
		return nil
	end
	local status = parse_git_status(status_json)
	if status and status.branch then
		return status
	end
	return nil
end

local function sync_git_header(project_id: string, show_header: boolean?)
	local visible = true
	if show_header ~= nil then
		visible = show_header
	elseif vault.settings.get("show_header") == "false" then
		visible = false
	end
	if not visible then
		clear_git_header()
		return
	end

	local status = get_git_status(project_id)
	if not status then
		clear_git_header()
		return
	end

	local color = "success"
	if status.behind > 0 then
		color = "warning"
	elseif status.isDirty then
		color = "muted"
	end

	local tooltip = "Branch: " .. status.branch
	if status.ahead > 0 or status.behind > 0 then
		tooltip = tooltip .. "\nAhead: " .. tostring(status.ahead) .. ", Behind: " .. tostring(status.behind)
	end
	tooltip = tooltip .. "\nClick to run git pull\nPush is available from the command palette"

	vault.ui.set_header_widget({
		id = "git_branch",
		type = "button",
		text = status.branch,
		icon = "mdi--git",
		tooltip = tooltip,
		command = "pull",
		color = color,
	})

	vault.ui.set_header_widget({
		id = "git_status_badge",
		type = "badge",
		text = status.isDirty and "Dirty" or "Clean",
		icon = status.isDirty and "mdi--alert-circle" or "mdi--check-circle",
		color = status.isDirty and "warning" or "success",
		tooltip = status.isDirty and "Working directory has uncommitted changes"
			or "Working tree is clean.\nClick to open settings.",
		command = "show_settings",
	})
end

local function update_git_footer(project_id: string?, locale: string)
	local active_project = vault.projects.get_active()
	if not active_project or active_project == "" then
		clear_git_footer()
		return
	end

	if not project_id or project_id == "" then
		project_id = active_project
	end

	if project_id ~= active_project then
		clear_git_footer()
		return
	end

	local status = get_git_status(project_id)
	if not status then
		clear_git_footer()
		return
	end

	local ok_branch, val_branch = pcall(vault.settings.get, "show_branch")
	local ok_tag, val_tag = pcall(vault.settings.get, "show_tag")

	local show_branch = true
	if ok_branch and val_branch ~= nil then
		show_branch = val_branch ~= "false"
	end

	local show_tag = false
	if ok_tag and val_tag ~= nil then
		show_tag = val_tag == "true"
	end

	if not show_branch and not show_tag then
		clear_git_footer()
		return
	end

	local state_text = status.isDirty and t(locale, "dirty") or t(locale, "clean")
	local tooltip = t(locale, "status_tooltip", { branch = status.branch, state = state_text })

	local footer_text = "git: "
	if show_branch then
		footer_text = footer_text .. status.branch
		if status.isDirty then
			footer_text = footer_text .. "*"
		end
	end

	local version_str = if type(status.version) == "string" then status.version else nil
	if show_tag and version_str and version_str ~= "" then
		if show_branch then
			footer_text = footer_text .. " (" .. version_str .. ")"
		else
			footer_text = footer_text .. version_str
			if status.isDirty then
				footer_text = footer_text .. "*"
			end
		end
	end

	if status.ahead > 0 or status.behind > 0 then
		footer_text = footer_text .. " [↑" .. tostring(status.ahead) .. " ↓" .. tostring(status.behind) .. "]"
	end

	local color = "success"
	if status.isDirty then
		color = "warning"
	end

	pcall(vault.ui.set_footer, {
		id = "git-branch",
		text = footer_text,
		icon = "mdi--git",
		tooltip = tooltip,
		command = "switch_branch",
		color = color,
		position = "right",
	})
end

local function publish_git_changed(project_id: string)
	local payload = vault.json.stringify({ projectId = project_id, changeType = "git" })
	vault.event.publish("project:changed", payload)
end

local function refresh_git_ui(project_id: string?, locale: string)
	update_git_footer(project_id, locale)
	if project_id and project_id ~= "" then
		sync_git_header(project_id, nil)
	else
		clear_git_header()
	end
end

local function run_git_sync(
	project_id: string,
	locale: string,
	args: { string },
	action: string,
	success_key: string,
	error_key: string
)
	vault.notification.info(t(locale, "sync_running", { action = action }))
	local res = vault.git.run(project_id, args)
	if res.success then
		vault.notification.success(t(locale, success_key))
		refresh_git_ui(project_id, locale)
		publish_git_changed(project_id)
	else
		vault.notification.error(t(locale, error_key, { err = res.stderr or "Unknown error" }))
	end
end

local function refresh_commits(project_id: string?, locale: string, show_warnings: boolean)
	if not project_id or project_id == "" then
		return
	end

	local ok, raw_log = pcall(vault.git.log, project_id, 15)
	if not ok or not raw_log then
		if show_warnings then
			vault.notification.error(t(locale, "error_loading"))
		end
		return
	end

	local commits = parse_git_commits(raw_log)
	if not commits or #commits == 0 then
		if show_warnings then
			vault.notification.info(t(locale, "no_git_repo"))
		end
		return
	end

	local project_name = project_name_for(project_id)
	local md = {}
	table.insert(md, "# Last Commits")
	table.insert(md, "Recent activity history for **" .. project_name .. "**:")
	table.insert(md, "")
	table.insert(md, "| Hash | Author | Date | Subject |")
	table.insert(md, "| :--- | :--- | :--- | :--- |")

	for _, commit in ipairs(commits) do
		table.insert(md, string.format(
			"| `[%s]` | **%s** | *%s* | %s |",
			commit.hash:sub(1, 8),
			commit.author,
			commit.relativeDate,
			commit.subject
		))
	end

	vault.ui.show_markdown_dialog(
		t(locale, "dialog_title", { name = project_name }),
		table.concat(md, "\n")
	)
end

local function show_settings_form(project_id: string?, locale: string)
	local current_header = vault.settings.get("show_header") ~= "false"
	local current_dec = vault.settings.get("decorate_files") ~= "false"
	local res = vault.ui.show_form({
		title = t(locale, "settings_title"),
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
		},
	})

	if not res then
		return
	end

	vault.settings.set("show_header", tostring(res.show_header))
	vault.settings.set("decorate_files", tostring(res.decorate_files))
	vault.notification.success(t(locale, "settings_saved"))

	if project_id and project_id ~= "" then
		sync_git_header(project_id, res.show_header)
		publish_git_changed(project_id)
	end
end

function plugin.get_decorations(project_id: string, tab_id: string, element_ids: { string })
	local decs = {}

	if tab_id == "files" then
		if vault.settings.get("decorate_files") == "false" then
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
	local is_viewing_commits = vault.settings.get("is_viewing_commits") == "true"

	if command_id == "init"
		or command_id == "project_focus"
		or command_id == "project_state_changed"
		or command_id == "git_status_changed"
	then
		local project_id = if command_id == "git_status_changed"
			then resolve_active_project_id(context)
			else resolve_focus_project_id(context)
		refresh_git_ui(project_id, locale)
		if is_viewing_commits then
			refresh_commits(project_id, locale, false)
		end
		return
	end

	if command_id == "markdown_dialog_closed" then
		vault.settings.set("is_viewing_commits", "false")
		return
	end

	if command_id == "show_settings" then
		show_settings_form(resolve_active_project_id(context), locale)
		return
	end

	if command_id == "switch_branch" then
		local project_id = resolve_active_project_id(context)
		if not project_id or project_id == "" then
			vault.notification.error(t(locale, "no_active_project"))
			return
		end

		local project = find_project(project_id)
		if not project then
			vault.notification.error(t(locale, "no_active_project"))
			return
		end

		local res = vault.shell.execute("git", { "branch", "--format=%(refname:short)" }, project.path)
		if not res.success then
			vault.notification.error(t(locale, "error_loading_branches"))
			return
		end

		local current_branch: string? = nil
		local status = get_git_status(project_id)
		if status then
			current_branch = status.branch
		end

		local items: { VaultQuickPickItem } = {}
		for line in res.stdout:gmatch("[^\r\n]+") do
			local branch_name = line:match("^%s*(.-)%s*$")
			if branch_name and branch_name ~= "" then
				local is_current = branch_name == current_branch
				table.insert(items, {
					id = branch_name,
					label = branch_name,
					icon = is_current and "mdi--check" or "mdi--source-branch",
					detail = is_current and t(locale, "current_branch") or nil,
				})
			end
		end

		if #items == 0 then
			vault.notification.info(t(locale, "no_branches_found"))
			return
		end

		local selected = vault.ui.show_quick_pick({
			title = t(locale, "switch_branch_title"),
			items = items,
		})

		if not selected then
			return
		end

		if selected == current_branch then
			vault.notification.info(t(locale, "already_on_branch", { branch = selected }))
			return
		end

		local checkout_res = vault.shell.execute("git", { "checkout", selected }, project.path)
		if checkout_res.success then
			vault.notification.success(t(locale, "switch_success", { branch = selected }))
			refresh_git_ui(project_id, locale)
			publish_git_changed(project_id)
			if is_viewing_commits then
				refresh_commits(project_id, locale, false)
			end
		else
			local err_msg = checkout_res.stderr:match("^%s*(.-)%s*$")
			if err_msg == "" then
				err_msg = checkout_res.stdout:match("^%s*(.-)%s*$")
			end
			vault.notification.error(t(locale, "switch_error", { branch = selected, error = err_msg }))
		end
		return
	end

	if command_id == "view_commits" then
		local project_id = resolve_active_project_id(context)
		if not project_id or project_id == "" then
			vault.notification.error(t(locale, "no_active_project"))
			return
		end

		vault.settings.set("is_viewing_commits", "true")
		refresh_commits(project_id, locale, true)
		return
	end

	if command_id == "pull" or command_id == "push" then
		local project_id = resolve_active_project_id(context)
		if not project_id or project_id == "" then
			vault.notification.error(t(locale, "no_active_project"))
			return
		end

		if command_id == "pull" then
			run_git_sync(project_id, locale, { "pull" }, "pull", "pull_success", "pull_error")
		else
			run_git_sync(project_id, locale, { "push" }, "push", "push_success", "push_error")
		end
	end
end

return plugin
