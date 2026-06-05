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

local function clear()
	pcall(vault.ui.clear_footer, "git-branch")
end

local function update(project_id: string?, t: (string, string, { [string]: string }?) -> string, locale: string)
	local active_project = vault.projects.get_active()
	if not active_project or active_project == "" then
		clear()
		return
	end

	if not project_id or project_id == "" then
		project_id = active_project
	end

	if project_id ~= active_project then
		clear()
		return
	end

	local ok, raw_status = pcall(vault.git.status, project_id)
	if not ok or not raw_status then
		clear()
		return
	end

	local status: GitStatus? = parse.status(raw_status)
	if not status or not status.branch then
		clear()
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
		clear()
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

return {
	update = update,
	clear = clear,
}
