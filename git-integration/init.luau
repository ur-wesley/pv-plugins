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
    projectId: string?
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

local plugin = {
    lazy = true,
    cmd = { "view_commits", "switch_branch", "pull", "push" },
    event = { "project_focus", "git_status_changed" },
    name = "Git Integration",
    description = "View repository commits and track status directly inside your launcher.",
    version = "1.0.1",
    category = "utility",
    locales = {
        en = {
            name = "Git Integration",
            description = "View repository commits and track status directly inside your launcher.",
            ["command.view_commits"] = "Git: View Last Commits",
            ["command.switch_branch"] = "Git: Switch Branch",
            ["command.pull"] = "Git: Pull Remote Changes",
            ["command.push"] = "Git: Push Local Changes",
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
        },
        de = {
            name = "Git-Integration",
            description = "Repository-Commits anzeigen und Status direkt im Launcher verfolgen.",
            ["command.view_commits"] = "Git: Letzte Commits anzeigen",
            ["command.switch_branch"] = "Git: Branch wechseln",
            ["command.pull"] = "Git: Remote-Änderungen abrufen (Pull)",
            ["command.push"] = "Git: Lokale Änderungen hochladen (Push)",
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
        }
    },
    config = {
        {
            key = "show_branch",
            type = "boolean",
            label = "Show Branch",
            description = "If enabled, displays the current Git branch name in the status bar footer.",
            default = true
        },
        {
            key = "show_tag",
            type = "boolean",
            label = "Show Latest Tag",
            description = "If enabled, displays the latest tag (release version) in the status bar footer.",
            default = false
        }
    },
    commands = {
        { id = "view_commits", title = "Git: View Last Commits", scope = "project" },
        { id = "switch_branch", title = "Git: Switch Branch", scope = "project" },
        { id = "pull", title = "Git: Pull Remote Changes", scope = "global" },
        { id = "push", title = "Git: Push Local Changes", scope = "global" },
    }
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

local function parseProjects(raw: string): { VaultProject }?
	local ok, parsed = pcall(function()
		return vault.json.parse(raw)
	end)
	if ok and type(parsed) == "table" then
		return parsed :: { VaultProject }
	end
	return nil
end

local function parseGitStatus(raw: string): GitStatus?
	local ok, parsed = pcall(function()
		return vault.json.parse(raw)
	end)
	if ok and type(parsed) == "table" then
		return parsed :: GitStatus
	end
	return nil
end

local function parseGitCommits(raw: string): { GitCommit }?
	local ok, parsed = pcall(function()
		return vault.json.parse(raw)
	end)
	if ok and type(parsed) == "table" then
		return parsed :: { GitCommit }
	end
	return nil
end

local function clear_git_footer()
    pcall(vault.ui.clear_footer, "git-branch")
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

-- Refresh footer git status chip for focused project
local function update_git_footer(projectId: string?, locale: string)
    local active_project = vault.projects.get_active()
    if not active_project or active_project == "" then
        clear_git_footer()
        return
    end

    if not projectId or projectId == "" then
        projectId = active_project
    end

    if projectId ~= active_project then
        clear_git_footer()
        return
    end

    local ok, raw_status = pcall(vault.git.status, projectId)
    if not ok then
        clear_git_footer()
        return
    end
    if not raw_status then
        clear_git_footer()
        return
    end

    local status = parseGitStatus(raw_status)
    if not status or not status.branch then
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
        position = "right"
    })
end

local function publish_git_changed(project_id: string)
    local payload = vault.json.stringify({ projectId = project_id, changeType = "git" })
    vault.event.publish("project:changed", payload)
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
        update_git_footer(project_id, locale)
        git_header().sync_header(project_id)
        publish_git_changed(project_id)
    else
        vault.notification.error(t(locale, error_key, { err = res.stderr or "Unknown error" }))
    end
end

-- Render and display/refresh commits dialog modal
local function refresh_commits(projectId: string?, locale: string, showWarnings: boolean)
    if not projectId or projectId == "" then
        return
    end

    local ok, raw_log = pcall(vault.git.log, projectId, 15)
    if not ok or not raw_log then
        if showWarnings then
            vault.notification.error(t(locale, "error_loading"))
        end
        return
    end

    local commits = parseGitCommits(raw_log)
    if not commits or #commits == 0 then
        if showWarnings then
            vault.notification.info(t(locale, "no_git_repo"))
        end
        return
    end

    -- Retrieve project name
    local projects = parseProjects(vault.projects.list())
    local project_name = "Repository"
    for _, p in ipairs(projects or {}) do
        if p.id == projectId then
            project_name = p.name
            break
        end
    end

    -- Build gorgeous Markdown
    local md = {}
    table.insert(md, "# Last Commits")
    table.insert(md, "Recent activity history for **" .. project_name .. "**:")
    table.insert(md, "")
    table.insert(md, "| Hash | Author | Date | Subject |")
    table.insert(md, "| :--- | :--- | :--- | :--- |")

    for _, commit in ipairs(commits) do
        local short_hash = commit.hash:sub(1, 8)
        local author_name = commit.author
        local relative_time = commit.relativeDate
        local subject = commit.subject

        table.insert(md, string.format(
            "| `[%s]` | **%s** | *%s* | %s |",
            short_hash, author_name, relative_time, subject
        ))
    end

    local markdown_content = table.concat(md, "\n")
    vault.ui.show_markdown_dialog(
        t(locale, "dialog_title", { name = project_name }),
        markdown_content
    )
end

function plugin.execute(command_id: string, context: PluginCommandContext?)
    local locale: string = vault.i18n.get_locale()
    local is_viewing_commits = vault.settings.get("is_viewing_commits") == "true"

    if command_id == "init" or command_id == "project_focus" or command_id == "project_state_changed" then
        local projectId = resolve_focus_project_id(context)
        update_git_footer(projectId, locale)
        if is_viewing_commits then
            refresh_commits(projectId, locale, false)
        end
        return
    elseif command_id == "git_status_changed" then
        local projectId = resolve_focus_project_id(context)
        update_git_footer(projectId, locale)
        if projectId and projectId ~= "" then
            git_header().sync_header(projectId)
        end
        if is_viewing_commits then
            refresh_commits(projectId, locale, false)
        end
        return
    elseif command_id == "markdown_dialog_closed" then
        vault.settings.set("is_viewing_commits", "false")
        return
    end

    if command_id == "switch_branch" then
        local projectId = context and context.projectId
        if not projectId or projectId == "" then
            projectId = vault.projects.get_active()
        end
        if not projectId or projectId == "" then
            vault.notification.error(t(locale, "no_active_project"))
            return
        end

        -- Find project path
        local projects = parseProjects(vault.projects.list())
        local project: VaultProject? = nil
        if projects then
            for _, p in ipairs(projects) do
                if p.id == projectId then
                    project = p
                    break
                end
            end
        end

        if not project then
            vault.notification.error(t(locale, "no_active_project"))
            return
        end

        local res = vault.shell.execute("git", { "branch", "--format=%(refname:short)" }, project.path)
        if not res.success then
            vault.notification.error(t(locale, "error_loading_branches"))
            return
        end

        -- Get current branch
        local status_ok, raw_status = pcall(vault.git.status, projectId)
        local current_branch = nil
        if status_ok and raw_status then
            local status = parseGitStatus(raw_status)
            if status then
                current_branch = status.branch
            end
        end

        local items: { VaultQuickPickItem } = {}
        for line in res.stdout:gmatch("[^\r\n]+") do
            local branch_name = line:match("^%s*(.-)%s*$")
            if branch_name and branch_name ~= "" then
                local is_current = branch_name == current_branch
                local icon = is_current and "mdi--check" or "mdi--source-branch"
                local detail = is_current and t(locale, "current_branch") or nil
                table.insert(items, {
                    id = branch_name,
                    label = branch_name,
                    icon = icon,
                    detail = detail,
                })
            end
        end

        if #items == 0 then
            vault.notification.info(t(locale, "no_branches_found"))
            return
        end

        local selected = vault.ui.show_quick_pick({
            title = t(locale, "switch_branch_title"),
            items = items
        })

        if selected then
            if selected == current_branch then
                vault.notification.info(t(locale, "already_on_branch", { branch = selected }))
                return
            end

            local checkout_res = vault.shell.execute("git", { "checkout", selected }, project.path)
            if checkout_res.success then
                vault.notification.success(t(locale, "switch_success", { branch = selected }))
                update_git_footer(projectId, locale)
                if is_viewing_commits then
                    refresh_commits(projectId, locale, false)
                end
            else
                local err_msg = checkout_res.stderr:match("^%s*(.-)%s*$")
                if err_msg == "" then
                    err_msg = checkout_res.stdout:match("^%s*(.-)%s*$")
                end
                vault.notification.error(t(locale, "switch_error", { branch = selected, error = err_msg }))
            end
        end
        return
    end

    if command_id == "view_commits" then
        local projectId = context and context.projectId
        if not projectId or projectId == "" then
            projectId = vault.projects.get_active()
        end
        if not projectId or projectId == "" then
            vault.notification.error(t(locale, "no_active_project"))
            return
        end

        vault.settings.set("is_viewing_commits", "true")
        refresh_commits(projectId, locale, true)
        return
    end

    if command_id == "pull" or command_id == "push" then
        local projectId = context and context.projectId
        if not projectId or projectId == "" then
            projectId = vault.projects.get_active()
        end
        if not projectId or projectId == "" then
            vault.notification.error(t(locale, "no_active_project"))
            return
        end

        if command_id == "pull" then
            run_git_sync(projectId, locale, { "pull" }, "pull", "pull_success", "pull_error")
        else
            run_git_sync(projectId, locale, { "push" }, "push", "push_success", "push_error")
        end
    end
end

return plugin
