--!strict

local types = (require :: any)("./types")
type TrackFlags = types.TrackFlags

local function get_track_flags(): TrackFlags
	return {
		dirty = vault.settings.get("track_dirty") ~= "false",
		unpushed = vault.settings.get("track_unpushed") ~= "false",
		no_upstream = vault.settings.get("track_no_upstream") ~= "false",
		behind = vault.settings.get("track_behind") == "true",
	}
end

local function show_form(
	locale: string,
	t: (string, string, { [string]: any }?) -> string,
	on_saved: (() -> ())?
)
	local track_dirty = vault.settings.get("track_dirty") ~= "false"
	local track_unpushed = vault.settings.get("track_unpushed") ~= "false"
	local track_no_upstream = vault.settings.get("track_no_upstream") ~= "false"
	local track_behind = vault.settings.get("track_behind") == "true"
	local show_in_footer = vault.settings.get("show_in_footer") ~= "false"
	local scan_on_focus = vault.settings.get("scan_on_focus") ~= "false"
	local fp = vault.settings.get("footer_position")
	if fp ~= "left" and fp ~= "right" then fp = "right" end
	local interval = tonumber(vault.settings.get("auto_scan_interval_sec")) or 60

	local res = vault.ui.show_form({
		title = t(locale, "settings_title"),
		fields = {
			{ id = "track_dirty", label = "Include Dirty Projects", fieldType = "boolean", defaultValue = track_dirty, required = false },
			{ id = "track_unpushed", label = "Include Unpushed Projects", fieldType = "boolean", defaultValue = track_unpushed, required = false },
			{ id = "track_no_upstream", label = "Include Projects Without Upstream", fieldType = "boolean", defaultValue = track_no_upstream, required = false },
			{ id = "track_behind", label = "Include Projects Behind Remote", fieldType = "boolean", defaultValue = track_behind, required = false },
			{ id = "show_in_footer", label = "Show Count in Footer", fieldType = "boolean", defaultValue = show_in_footer, required = false },
			{ id = "footer_position", label = "Footer Chip Position", fieldType = "select", defaultValue = fp, options = { { id = "left", label = "Left" }, { id = "right", label = "Right" } }, required = false },
			{ id = "scan_on_focus", label = "Rescan on Project Focus", fieldType = "boolean", defaultValue = scan_on_focus, required = false },
			{ id = "auto_scan_interval_sec", label = "Auto-Scan Interval (seconds)", fieldType = "number", defaultValue = interval, required = false, min = 10, max = 600 },
		},
	})

	if not res then return end

	vault.settings.set("track_dirty", tostring(res.track_dirty))
	vault.settings.set("track_unpushed", tostring(res.track_unpushed))
	vault.settings.set("track_no_upstream", tostring(res.track_no_upstream))
	vault.settings.set("track_behind", tostring(res.track_behind))
	vault.settings.set("show_in_footer", tostring(res.show_in_footer))
	vault.settings.set("footer_position", tostring(res.footer_position))
	vault.settings.set("scan_on_focus", tostring(res.scan_on_focus))

	local n = tonumber(res.auto_scan_interval_sec) or 60
	if n < 10 then n = 10 end
	if n > 600 then n = 600 end
	vault.settings.set("auto_scan_interval_sec", tostring(n))

	vault.notification.success(t(locale, "settings_saved"))
	if on_saved then
		on_saved()
	end
end

return {
	get_track_flags = get_track_flags,
	show_form = show_form,
}
