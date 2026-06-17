--!strict

local scan = (require :: any)("./scan")
local picker = (require :: any)("./picker")
local footer = (require :: any)("./footer")

type PluginLocales = {
	en: { [string]: string },
	de: { [string]: string },
}

type PluginCommandContext = {
	projectId: string?,
	elementId: string?,
}

type ProjectStatus = scan.ProjectStatus

local plugin = {
	lazy = false,
	cmd = { "show_dirty", "refresh_scan", "show_settings" },
	event = { "project_focus", "git_status_changed" },
	name = "Git Hygiene",
	description = "Scan every project in the vault for uncommitted changes, unpushed commits, and missing upstreams.",
	version = "1.0.0",
	category = "utility",
	locales = {
		en = {
			name = "Git Hygiene",
			description = "Scan every project in the vault for uncommitted changes, unpushed commits, and missing upstreams.",
			["command.show_dirty"] = "Git Hygiene: Show Dirty & Unpushed Projects",
			["command.refresh_scan"] = "Git Hygiene: Refresh Scan",
			["command.show_settings"] = "Git Hygiene: Settings",
			no_projects = "No projects in the vault to scan.",
			no_issues = "All clean! No dirty or unpushed projects.",
			scan_done = "Scanned {n} project(s): {dirty} dirty, {unpushed} unpushed, {no_upstream} no-upstream.",
			scan_partial = "Scanned {n} project(s) with {errors} error(s) skipped.",
			scanning = "Scanning {n} project(s) for git issues...",
			settings_title = "Git Hygiene Settings",
			settings_saved = "Settings saved.",
			picker_title = "Git Hygiene — {n} project(s) need attention",
			picker_title_empty = "Git Hygiene — all clean",
			section_dirty = "Dirty",
			section_unpushed = "Unpushed",
			section_no_upstream = "No Upstream",
			section_behind = "Behind",
			detail_dirty = "Working directory has uncommitted changes",
			detail_unpushed = "{n} commit(s) ahead of {branch}",
			detail_no_upstream = "Local branch with no upstream tracking",
			detail_behind = "{n} commit(s) behind {branch}",
			footer_clean = "All clean",
			footer_summary = "{dirty} dirty · {unpushed} unpushed",
			footer_summary_full = "{dirty} dirty · {unpushed} unpushed · {no_upstream} no upstream · {behind} behind",
		},
		de = {
			name = "Git-Hygiene",
			description = "Durchsucht alle Projekte im Vault nach ungespeicherten Änderungen, nicht gepushten Commits und fehlenden Upstreams.",
			["command.show_dirty"] = "Git-Hygiene: Dirty- und Unpushed-Projekte anzeigen",
			["command.refresh_scan"] = "Git-Hygiene: Scan aktualisieren",
			["command.show_settings"] = "Git-Hygiene: Einstellungen",
			no_projects = "Keine Projekte im Vault zum Scannen.",
			no_issues = "Alles sauber! Keine dirty oder unpushed Projekte.",
			scan_done = "{n} Projekt(e) gescannt: {dirty} dirty, {unpushed} unpushed, {no_upstream} ohne Upstream.",
			scan_partial = "{n} Projekt(e) gescannt, {errors} Fehler übersprungen.",
			scanning = "Scanne {n} Projekt(e) auf Git-Probleme...",
			settings_title = "Git-Hygiene-Einstellungen",
			settings_saved = "Einstellungen gespeichert.",
			picker_title = "Git-Hygiene — {n} Projekt(e) benötigen Aufmerksamkeit",
			picker_title_empty = "Git-Hygiene — alles sauber",
			section_dirty = "Dirty",
			section_unpushed = "Unpushed",
			section_no_upstream = "Kein Upstream",
			section_behind = "Hinter Remote",
			detail_dirty = "Arbeitsverzeichnis hat ungespeicherte Änderungen",
			detail_unpushed = "{n} Commit(s) vor {branch}",
			detail_no_upstream = "Lokaler Branch ohne Upstream-Tracking",
			detail_behind = "{n} Commit(s) hinter {branch}",
			footer_clean = "Alles sauber",
			footer_summary = "{dirty} dirty · {unpushed} unpushed",
			footer_summary_full = "{dirty} dirty · {unpushed} unpushed · {no_upstream} ohne Upstream · {behind} hinter",
		},
	},
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

local function translate(locales: PluginLocales, locale: string, key: string, args: { [string]: any }?): string
	local dict: { [string]: string } = if locale == "de" then locales.de else locales.en
	local str = dict[key] or key
	if args then
		for k, v in pairs(args) do
			str = str:gsub("{" .. k .. "}", tostring(v))
		end
	end
	return str
end

local function t(locale: string, key: string, args: { [string]: any }?): string
	return translate(plugin.locales :: PluginLocales, locale, key, args)
end

local function get_track_flags(): { dirty: boolean, unpushed: boolean, no_upstream: boolean, behind: boolean }
	return {
		dirty = vault.settings.get("track_dirty") ~= "false",
		unpushed = vault.settings.get("track_unpushed") ~= "false",
		no_upstream = vault.settings.get("track_no_upstream") ~= "false",
		behind = vault.settings.get("track_behind") == "true",
	}
end

local function filter_by_track(
	entries: { ProjectStatus },
	track: { dirty: boolean, unpushed: boolean, no_upstream: boolean, behind: boolean }
): { ProjectStatus }
	local out: { ProjectStatus } = {}
	for _, p in ipairs(entries) do
		if (track.dirty and p.isDirty)
			or (track.unpushed and p.ahead > 0)
			or (track.no_upstream and p.hasUpstream == false)
			or (track.behind and p.behind > 0)
		then
			table.insert(out, p)
		end
	end
	return out
end

local function render_footer(entries: { ProjectStatus }, locale: string)
	footer.render(entries, {
		clean = t(locale, "footer_clean"),
		summary = function(dirty, unpushed)
			return t(locale, "footer_summary", { dirty = tostring(dirty), unpushed = tostring(unpushed) })
		end,
		summary_full = function(dirty, unpushed, no_upstream, behind)
			return t(locale, "footer_summary_full", {
				dirty = tostring(dirty),
				unpushed = tostring(unpushed),
				no_upstream = tostring(no_upstream),
				behind = tostring(behind),
			})
		end,
	})
end

local function run_full_scan_and_render(locale: string, silent: boolean?): { ProjectStatus }
	local result = scan.scan_all()
	if not silent then
		vault.notification.info(t(locale, "scan_done", {
			n = tostring(#result.projects),
			dirty = tostring(picker.count_dirty(result.projects)),
			unpushed = tostring(picker.count_unpushed(result.projects)),
			no_upstream = tostring(picker.count_no_upstream(result.projects)),
		}))
		if #result.errors > 0 then
			vault.notification.warn(t(locale, "scan_partial", {
				n = tostring(#result.projects),
				errors = tostring(#result.errors),
			}))
			for _, e in ipairs(result.errors) do
				vault.log.error("git-hygiene: " .. e.name .. " — " .. e.message)
			end
		end
	end
	render_footer(result.projects, locale)
	return result.projects
end

local function parse_projects(): { any }?
	local ok, p = pcall(function()
		return vault.json.parse(vault.projects.list())
	end)
	if ok and type(p) == "table" then
		return p :: { any }
	end
	return nil
end

local function show_dirty_picker(locale: string)
	local projects = parse_projects()
	if not projects or #projects == 0 then
		vault.notification.info(t(locale, "no_projects"))
		footer.clear()
		return
	end

	vault.notification.info(t(locale, "scanning", { n = tostring(#projects) }))
	local result = scan.scan_all()
	local track = get_track_flags()
	local filtered = filter_by_track(result.projects, track)
	render_footer(result.projects, locale)

	if #filtered == 0 then
		vault.ui.show_quick_pick({
			title = t(locale, "picker_title_empty"),
			items = {
				{ id = "empty", label = t(locale, "no_issues"), icon = "mdi--check-circle" },
			},
		})
		return
	end

	local items = picker.build_items(filtered, track, {
		title = t(locale, "picker_title", { n = tostring(#filtered) }),
		section_dirty = t(locale, "section_dirty"),
		section_unpushed = t(locale, "section_unpushed"),
		section_no_upstream = t(locale, "section_no_upstream"),
		section_behind = t(locale, "section_behind"),
		detail_dirty = t(locale, "detail_dirty"),
		detail_unpushed = function(ahead, branch)
			return t(locale, "detail_unpushed", { n = tostring(ahead), branch = branch })
		end,
		detail_no_upstream = t(locale, "detail_no_upstream"),
		detail_behind = function(behind, branch)
			return t(locale, "detail_behind", { n = tostring(behind), branch = branch })
		end,
	})

	local selected = vault.ui.show_quick_pick({ title = t(locale, "picker_title", { n = tostring(#filtered) }), items = items })
	if selected and selected ~= "" and not selected:find("^section_") then
		vault.ui.open_project_file(selected, "", 0)
	end
end

local function show_settings_form(locale: string)
	local track_dirty = vault.settings.get("track_dirty") ~= "false"
	local track_unpushed = vault.settings.get("track_unpushed") ~= "false"
	local track_no_upstream = vault.settings.get("track_no_upstream") ~= "false"
	local track_behind = vault.settings.get("track_behind") == "true"
	local show_in_footer = vault.settings.get("show_in_footer") ~= "false"
	local scan_on_focus = vault.settings.get("scan_on_focus") ~= "false"
	local footer_position = vault.settings.get("footer_position")
	if footer_position ~= "left" and footer_position ~= "right" then
		footer_position = "right"
	end
	local interval_raw = vault.settings.get("auto_scan_interval_sec")
	local interval = tonumber(interval_raw) or 60

	local res = vault.ui.show_form({
		title = t(locale, "settings_title"),
		fields = {
			{
				id = "track_dirty",
				label = "Include Dirty Projects",
				fieldType = "boolean",
				defaultValue = track_dirty,
				required = false,
			},
			{
				id = "track_unpushed",
				label = "Include Unpushed Projects",
				fieldType = "boolean",
				defaultValue = track_unpushed,
				required = false,
			},
			{
				id = "track_no_upstream",
				label = "Include Projects Without Upstream",
				fieldType = "boolean",
				defaultValue = track_no_upstream,
				required = false,
			},
			{
				id = "track_behind",
				label = "Include Projects Behind Remote",
				fieldType = "boolean",
				defaultValue = track_behind,
				required = false,
			},
			{
				id = "show_in_footer",
				label = "Show Count in Footer",
				fieldType = "boolean",
				defaultValue = show_in_footer,
				required = false,
			},
			{
				id = "footer_position",
				label = "Footer Chip Position",
				fieldType = "select",
				defaultValue = footer_position,
				options = {
					{ id = "left", label = "Left" },
					{ id = "right", label = "Right" },
				},
				required = false,
			},
			{
				id = "scan_on_focus",
				label = "Rescan on Project Focus",
				fieldType = "boolean",
				defaultValue = scan_on_focus,
				required = false,
			},
			{
				id = "auto_scan_interval_sec",
				label = "Auto-Scan Interval (seconds)",
				fieldType = "number",
				defaultValue = interval,
				required = false,
				min = 10,
				max = 600,
			},
		},
	})

	if not res then
		return
	end

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

	local cache = scan.load_cache() or {}
	render_footer(cache, locale)
end

function plugin.execute(command_id: string, context: PluginCommandContext?)
	local locale = vault.i18n.get_locale()

	if command_id == "init" then
		local cache = scan.load_cache() or {}
		if #cache > 0 then
			render_footer(cache, locale)
		else
			-- No cache yet: keep the footer clear so we don't show a stale
			-- "all clean" chip before the first scan. Full scan happens on
			-- first focus or first user command.
			footer.clear()
		end
		return
	end

	if command_id == "project_focus" then
		if vault.settings.get("scan_on_focus") == "false" then
			local cache = scan.load_cache() or {}
			render_footer(cache, locale)
			return
		end
		-- Defer to cache (which honours TTL internally).
		local cache = scan.get_fresh_cache(false)
		render_footer(cache, locale)
		return
	end

	if command_id == "git_status_changed" then
		local project_id = context and context.projectId
		if project_id and project_id ~= "" then
			local cache = scan.update_project(project_id) or {}
			render_footer(cache, locale)
		end
		return
	end

	if command_id == "show_dirty" then
		show_dirty_picker(locale)
		return
	end

	if command_id == "refresh_scan" then
		run_full_scan_and_render(locale, false)
		return
	end

	if command_id == "show_settings" then
		show_settings_form(locale)
		return
	end
end

return plugin
