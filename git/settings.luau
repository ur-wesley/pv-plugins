--!strict

local header = (require :: any)("./header")
local sync = (require :: any)("./sync")

local function show(
	project_id: string?,
	locale: string,
	t: (string, string, { [string]: string }?) -> string
)
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
		header.sync(project_id, {
			show_header = res.show_header,
		})
		sync.publish_changed(project_id)
	end
end

return {
	show = show,
}
