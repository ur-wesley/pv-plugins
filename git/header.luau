--!strict

local parse = (require :: any)("./parse")

type GitStatus = {
	branch: string,
	ahead: number,
	behind: number,
	isDirty: boolean,
	hasUpstream: boolean,
	version: string?,
}

type SyncHeaderOptions = {
	show_header: boolean?,
}

local function get_status(project_id: string): GitStatus?
	local ok, status_json = pcall(vault.git.get_status, project_id)
	if not ok or not status_json or status_json == "null" or status_json == "" then
		return nil
	end
	local status = parse.status(status_json)
	if status and status.branch then
		return status
	end
	return nil
end

local function clear()
	vault.ui.clear_header_widget("git_branch")
	vault.ui.clear_header_widget("git_status_badge")
end

local function sync(project_id: string, options: SyncHeaderOptions?)
	local show_header = true
	if options and options.show_header ~= nil then
		show_header = options.show_header
	end
	if not show_header then
		clear()
		return
	end

	local status = get_status(project_id)
	if not status then
		clear()
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

return {
	sync = sync,
	clear = clear,
}
