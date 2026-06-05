--!strict

local parse = (require :: any)("./parse")
local projects = (require :: any)("./projects")
local footer = (require :: any)("./footer")
local header = (require :: any)("./header")
local commits = (require :: any)("./commits")
local sync = (require :: any)("./sync")

type VaultQuickPickItem = {
	id: string,
	label: string,
	detail: string?,
	icon: string?,
}

local function switch(
	project_id: string,
	locale: string,
	t: (string, string, { [string]: string }?) -> string,
	is_viewing_commits: boolean
)
	local project = projects.find(project_id)
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
	local status_ok, raw_status = pcall(vault.git.status, project_id)
	if status_ok and raw_status then
		local status = parse.status(raw_status)
		if status then
			current_branch = status.branch
		end
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
		footer.update(project_id, t, locale)
		header.sync(project_id, {
			show_header = vault.settings.get("show_header") ~= "false",
		})
		sync.publish_changed(project_id)
		if is_viewing_commits then
			commits.refresh(project_id, locale, t, false)
		end
	else
		local err_msg = checkout_res.stderr:match("^%s*(.-)%s*$")
		if err_msg == "" then
			err_msg = checkout_res.stdout:match("^%s*(.-)%s*$")
		end
		vault.notification.error(t(locale, "switch_error", { branch = selected, error = err_msg }))
	end
end

return {
	switch = switch,
}
