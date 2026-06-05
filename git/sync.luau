--!strict

local footer = (require :: any)("./footer")
local header = (require :: any)("./header")

local function publish_changed(project_id: string)
	local payload = vault.json.stringify({ projectId = project_id, changeType = "git" })
	vault.event.publish("project:changed", payload)
end

local function run(
	project_id: string,
	locale: string,
	t: (string, string, { [string]: string }?) -> string,
	args: { string },
	action: string,
	success_key: string,
	error_key: string
)
	vault.notification.info(t(locale, "sync_running", { action = action }))
	local res = vault.git.run(project_id, args)
	if res.success then
		vault.notification.success(t(locale, success_key))
		footer.update(project_id, t, locale)
		header.sync(project_id, {
			show_header = vault.settings.get("show_header") ~= "false",
		})
		publish_changed(project_id)
	else
		vault.notification.error(t(locale, error_key, { err = res.stderr or "Unknown error" }))
	end
end

return {
	run = run,
	publish_changed = publish_changed,
}
