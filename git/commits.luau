--!strict

local parse = (require :: any)("./parse")
local projects = (require :: any)("./projects")

type GitCommit = {
	hash: string,
	author: string,
	email: string,
	subject: string,
	date: string,
	relativeDate: string,
}

local function refresh(
	project_id: string?,
	locale: string,
	t: (string, string, { [string]: string }?) -> string,
	show_warnings: boolean
)
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

	local log = parse.commits(raw_log)
	if not log or #log == 0 then
		if show_warnings then
			vault.notification.info(t(locale, "no_git_repo"))
		end
		return
	end

	local project_name = projects.name_for(project_id)
	local md = {}
	table.insert(md, "# Last Commits")
	table.insert(md, "Recent activity history for **" .. project_name .. "**:")
	table.insert(md, "")
	table.insert(md, "| Hash | Author | Date | Subject |")
	table.insert(md, "| :--- | :--- | :--- | :--- |")

	for _, commit in ipairs(log :: { GitCommit }) do
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

return {
	refresh = refresh,
}
