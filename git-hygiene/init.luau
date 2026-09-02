--!strict

type PluginCommandContext = {
	projectId: string?,
	elementId: string?,
	pageId: string?,
	itemId: string?,
}

local locales = (require :: any)("./locales")

local plugin = {
	lazy = false,
	cmd = { "show_dirty", "refresh_scan", "show_settings", "open_item" },
	event = { "project_focus", "git_status_changed" },
	name = "Git Hygiene",
	description = "Scan every project in the vault for uncommitted changes, unpushed commits, and missing upstreams.",
	version = "1.0.2",
	category = "utility",
	pages = {
		{
			id = "dirty",
			title = "Git Hygiene",
			icon = "mdi--broom",
			defaultPinned = true,
			command = "show_dirty",
		},
	},
	locales = locales,
	config = {
		{
			key = "track_dirty",
			type = "boolean",
			label = "Include Dirty Projects",
			description = "Show projects with uncommitted working tree changes.",
			default = true,
		},
		{
			key = "track_unpushed",
			type = "boolean",
			label = "Include Unpushed Projects",
			description = "Show projects with commits ahead of their upstream branch.",
			default = true,
		},
		{
			key = "track_no_upstream",
			type = "boolean",
			label = "Include Projects Without Upstream",
			description = "Show projects whose current branch has no upstream tracking.",
			default = true,
		},
		{
			key = "track_behind",
			type = "boolean",
			label = "Include Projects Behind Remote",
			description = "Show projects with commits behind their upstream branch.",
			default = false,
		},
		{
			key = "show_in_footer",
			type = "boolean",
			label = "Show Count in Footer",
			description = "Display a status-bar chip summarising the scan results.",
			default = true,
		},
		{
			key = "footer_position",
			type = "select",
			label = "Footer Chip Position",
			description = "Which side of the status bar the chip is anchored to.",
			default = "right",
			options = {
				{ id = "left", label = "Left" },
				{ id = "right", label = "Right" },
			},
		},
		{
			key = "scan_on_focus",
			type = "boolean",
			label = "Rescan on Project Focus",
			description = "Trigger a rescan when the active project changes (respects the auto-scan interval).",
			default = true,
		},
		{
			key = "auto_scan_interval_sec",
			type = "number",
			label = "Auto-Scan Interval (seconds)",
			description = "Minimum time between automatic rescans. Min 10, max 600.",
			default = 60,
			min = 10,
			max = 600,
		},
	},
	commands = {
		{ id = "show_dirty", title = "Git Hygiene: Show Dirty & Unpushed Projects", scope = "global" },
		{ id = "refresh_scan", title = "Git Hygiene: Refresh Scan", scope = "global" },
		{ id = "show_settings", title = "Git Hygiene: Settings", scope = "global" },
	},
}

local scan_mod: any = nil
local footer_mod: any = nil
local picker_mod: any = nil
local settings_mod: any = nil
local i18n_mod: any = nil

local function get_scan()
	if not scan_mod then
		scan_mod = (require :: any)("./scan")
	end
	return scan_mod
end

local function get_footer()
	if not footer_mod then
		footer_mod = (require :: any)("./footer")
	end
	return footer_mod
end

local function get_picker()
	if not picker_mod then
		picker_mod = (require :: any)("./picker")
	end
	return picker_mod
end

local function get_settings()
	if not settings_mod then
		settings_mod = (require :: any)("./settings")
	end
	return settings_mod
end

local function get_i18n()
	if not i18n_mod then
		local factory = (require :: any)("./i18n")
		i18n_mod = factory.create(plugin.locales)
	end
	return i18n_mod
end

function plugin.execute(command_id: string, context: PluginCommandContext?)
	local locale = vault.i18n.get_locale()
	local t = get_i18n().t
	local scan = get_scan()
	local footer = get_footer()
	local picker = get_picker()
	local settings = get_settings()

	if command_id == "init" then
		local cache = scan.load_cache() or {}
		if #cache > 0 then
			footer.render(cache, locale, t)
			picker.update_page(locale, t, cache)
		else
			footer.clear()
		end
		return
	end

	if command_id == "project_focus" then
		if vault.settings.get("scan_on_focus") == "false" then
			local cache = scan.load_cache() or {}
			footer.render(cache, locale, t)
			picker.update_page(locale, t, cache)
			return
		end
		local fresh = scan.get_fresh_cache(false)
		footer.render(fresh, locale, t)
		picker.update_page(locale, t, fresh)
		return
	end

	if command_id == "git_status_changed" then
		local project_id = context and context.projectId
		if project_id and project_id ~= "" then
			local updated = scan.update_project_cache(project_id) or {}
			footer.render(updated, locale, t)
			picker.update_page(locale, t, updated)
		end
		return
	end

	if command_id == "show_dirty" then
		if context and context.pageId == "dirty" then
			local fresh = scan.get_fresh_cache(false)
			footer.render(fresh, locale, t)
			picker.update_page(locale, t, fresh)
			return
		end
		picker.show_dirty_picker(locale, t, function(entries, loc)
			footer.render(entries, loc, t)
		end)
		return
	end

	if command_id == "open_item" or command_id == "open_project" then
		local item_id = context and context.itemId
		if item_id then
			picker.open_project(item_id)
		end
		return
	end

	if command_id == "refresh_scan" then
		scan.full_scan(locale, t, function(entries, loc)
			footer.render(entries, loc, t)
			picker.update_page(loc, t, entries)
		end)
		return
	end

	if command_id == "show_settings" then
		settings.show_form(locale, t, function()
			local cache = scan.load_cache() or {}
			footer.render(cache, locale, t)
			picker.update_page(locale, t, cache)
		end)
		return
	end
end

return plugin
