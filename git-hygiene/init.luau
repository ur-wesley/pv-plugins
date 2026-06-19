--!strict

type PluginLocales = {
	en: { [string]: string },
	de: { [string]: string },
}

type PluginCommandContext = {
	projectId: string?,
	elementId: string?,
}

type ProjectStatus = {
	id: string,
	name: string,
	path: string,
	branch: string,
	ahead: number,
	behind: number,
	isDirty: boolean,
	hasUpstream: boolean,
	scanned_at: number,
}

type VaultProject = {
	id: string,
	name: string,
	path: string,
}

type GitStatus = {
	branch: string,
	ahead: number,
	behind: number,
	isDirty: boolean,
	hasUpstream: boolean,
	version: string?,
}

type TrackFlags = {
	dirty: boolean,
	unpushed: boolean,
	no_upstream: boolean,
	behind: boolean,
}

local SCAN_CACHE_KEY = "scan_cache"
local SCAN_CACHE_TS_KEY = "scan_cache_ts"
local FOOTER_ID = "git_hygiene_state"

local function now_ms(): number
	return os.time() * 1000
end

local function parse_json(raw: string): any
	local ok, parsed = pcall(function()
		return vault.json.parse(raw)
	end)
	if ok then
		return parsed
	end
	return nil
end

local function parse_projects(raw: string): { VaultProject }?
	local parsed = parse_json(raw)
	if type(parsed) == "table" then
		return parsed :: { VaultProject }
	end
	return nil
end

local function parse_status(raw: string): GitStatus?
	local parsed = parse_json(raw)
	if type(parsed) ~= "table" then
		return nil
	end
	local t = parsed :: GitStatus
	if type(t.branch) ~= "string" or t.branch == "" then
		return nil
	end
	return t
end

local function fetch_status(project_id: string): GitStatus?
	local ok, raw = pcall(vault.git.get_status, project_id)
	if not ok or type(raw) ~= "string" or raw == "" or raw == "null" then
		return nil
	end
	return parse_status(raw)
end

local function load_cache(): { ProjectStatus }?
	local raw = vault.settings.get(SCAN_CACHE_KEY)
	if not raw or raw == "" then
		return nil
	end
	local parsed = parse_json(raw)
	if type(parsed) == "table" then
		return parsed :: { ProjectStatus }
	end
	return nil
end

local function save_cache(entries: { ProjectStatus })
	vault.settings.set(SCAN_CACHE_KEY, vault.json.stringify(entries))
	vault.settings.set(SCAN_CACHE_TS_KEY, tostring(now_ms()))
end

local function load_cache_ts(): number
	local raw = vault.settings.get(SCAN_CACHE_TS_KEY)
	if not raw or raw == "" then
		return 0
	end
	local n = tonumber(raw)
	if not n then
		return 0
	end
	return n
end

local function find_index(list: { ProjectStatus }, id: string): number?
	for i, item in ipairs(list) do
		if item.id == id then
			return i
		end
	end
	return nil
end

local function scan_one(p: VaultProject, ts: number): (ProjectStatus?, string?)
	local ok, status_or_err = pcall(fetch_status, p.id)
	if not ok then
		return nil, tostring(status_or_err)
	end
	local status = status_or_err :: GitStatus?
	if not status then
		return nil, nil
	end
	local entry: ProjectStatus = {
		id = p.id,
		name = p.name,
		path = p.path,
		branch = status.branch,
		ahead = status.ahead or 0,
		behind = status.behind or 0,
		isDirty = status.isDirty == true,
		hasUpstream = status.hasUpstream == true,
		scanned_at = ts,
	}
	return entry, nil
end

local function scan_all(): { projects: { ProjectStatus }, errors: { { id: string, name: string, message: string } } }
	local ts = now_ms()
	local projects = parse_projects(vault.projects.list()) or {}
	local entries: { ProjectStatus } = {}
	local errors: { { id: string, name: string, message: string } } = {}
	for _, p in ipairs(projects) do
		local entry, err = scan_one(p, ts)
		if entry then
			table.insert(entries, entry)
		elseif err then
			table.insert(errors, { id = p.id, name = p.name, message = err })
		end
	end
	save_cache(entries)
	return { projects = entries, errors = errors }
end

local function update_project_cache(project_id: string): { ProjectStatus }?
	local projects = parse_projects(vault.projects.list()) or {}
	local lookup: { [string]: VaultProject } = {}
	for _, p in ipairs(projects) do
		lookup[p.id] = p
	end
	local p = lookup[project_id]
	local cache = load_cache() or {}
	local idx = find_index(cache, project_id)
	if not p then
		if idx then
			table.remove(cache, idx)
			save_cache(cache)
		end
		return cache
	end
	local entry, _err = scan_one(p, now_ms())
	if entry then
		if idx then
			cache[idx] = entry
		else
			table.insert(cache, entry)
		end
	elseif idx then
		table.remove(cache, idx)
	end
	save_cache(cache)
	return cache
end

local function ttl_ms(): number
	local raw = vault.settings.get("auto_scan_interval_sec")
	if not raw or raw == "" then
		return 60000
	end
	local n = tonumber(raw)
	if not n then
		return 60000
	end
	if n < 10 then n = 10 end
	if n > 600 then n = 600 end
	return n * 1000
end

local function get_fresh_cache(force: boolean?): { ProjectStatus }
	local cache = load_cache() or {}
	local ts = load_cache_ts()
	if force or ts <= 0 or (now_ms() - ts) > ttl_ms() then
		return scan_all().projects
	end
	return cache
end

local function has_dirty(p: ProjectStatus): boolean
	return p.isDirty
end

local function has_unpushed(p: ProjectStatus): boolean
	return p.ahead > 0
end

local function has_no_upstream(p: ProjectStatus): boolean
	return p.hasUpstream == false
end

local function has_behind(p: ProjectStatus): boolean
	return p.behind > 0
end

local function severity(p: ProjectStatus): number
	if has_dirty(p) and has_unpushed(p) then
		return 40
	elseif has_dirty(p) then
		return 30
	elseif has_unpushed(p) then
		return 20
	elseif has_no_upstream(p) then
		return 10
	elseif has_behind(p) then
		return 5
	end
	return 0
end

local function state_icon(p: ProjectStatus): string
	if has_dirty(p) then
		return "mdi--alert-circle"
	elseif has_unpushed(p) then
		return "mdi--upload"
	elseif has_no_upstream(p) then
		return "mdi--source-branch"
	elseif has_behind(p) then
		return "mdi--download"
	end
	return "mdi--check"
end

local function count_dirty(entries: { ProjectStatus }): number
	local n = 0
	for _, p in ipairs(entries) do
		if has_dirty(p) then n = n + 1 end
	end
	return n
end

local function count_unpushed(entries: { ProjectStatus }): number
	local n = 0
	for _, p in ipairs(entries) do
		if has_unpushed(p) then n = n + 1 end
	end
	return n
end

local function count_no_upstream(entries: { ProjectStatus }): number
	local n = 0
	for _, p in ipairs(entries) do
		if has_no_upstream(p) then n = n + 1 end
	end
	return n
end

local function count_behind(entries: { ProjectStatus }): number
	local n = 0
	for _, p in ipairs(entries) do
		if has_behind(p) then n = n + 1 end
	end
	return n
end

local plugin = {
	lazy = false,
	cmd = { "show_dirty", "refresh_scan", "show_settings" },
	event = { "project_focus", "git_status_changed" },
	name = "Git Hygiene",
	description = "Scan every project in the vault for uncommitted changes, unpushed commits, and missing upstreams.",
	version = "1.0.1",
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

local function get_track_flags(): TrackFlags
	return {
		dirty = vault.settings.get("track_dirty") ~= "false",
		unpushed = vault.settings.get("track_unpushed") ~= "false",
		no_upstream = vault.settings.get("track_no_upstream") ~= "false",
		behind = vault.settings.get("track_behind") == "true",
	}
end

local function filter_by_track(entries: { ProjectStatus }, track: TrackFlags): { ProjectStatus }
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

local function footer_position(): string
	local raw = vault.settings.get("footer_position")
	if raw == "left" or raw == "right" then
		return raw
	end
	return "right"
end

local function footer_enabled(): boolean
	return vault.settings.get("show_in_footer") ~= "false"
end

local function footer_color(dirty: number, unpushed: number, no_upstream: number, behind: number): string
	if dirty > 0 then return "warning" end
	if unpushed > 0 then return "primary" end
	if no_upstream > 0 or behind > 0 then return "muted" end
	return "success"
end

local function render_footer(entries: { ProjectStatus }, locale: string)
	if not footer_enabled() then
		pcall(vault.ui.clear_footer, FOOTER_ID)
		return
	end

	local dirty = count_dirty(entries)
	local unpushed = count_unpushed(entries)
	local no_upstream = count_no_upstream(entries)
	local behind = count_behind(entries)

	local text: string
	if dirty == 0 and unpushed == 0 and no_upstream == 0 and behind == 0 then
		text = t(locale, "footer_clean")
	elseif behind > 0 or no_upstream > 0 then
		text = t(locale, "footer_summary_full", {
			dirty = tostring(dirty),
			unpushed = tostring(unpushed),
			no_upstream = tostring(no_upstream),
			behind = tostring(behind),
		})
	else
		text = t(locale, "footer_summary", { dirty = tostring(dirty), unpushed = tostring(unpushed) })
	end

	local tooltip_lines: { string } = {}
	if dirty > 0 then table.insert(tooltip_lines, tostring(dirty) .. " dirty") end
	if unpushed > 0 then table.insert(tooltip_lines, tostring(unpushed) .. " unpushed") end
	if no_upstream > 0 then table.insert(tooltip_lines, tostring(no_upstream) .. " no upstream") end
	if behind > 0 then table.insert(tooltip_lines, tostring(behind) .. " behind") end
	if #tooltip_lines == 0 then table.insert(tooltip_lines, t(locale, "footer_clean")) end
	table.insert(tooltip_lines, "Click to view details")

	pcall(vault.ui.set_footer, {
		id = FOOTER_ID,
		text = text,
		icon = dirty > 0 and "mdi--alert-circle" or "mdi--broom",
		tooltip = table.concat(tooltip_lines, "\n"),
		command = "show_dirty",
		color = footer_color(dirty, unpushed, no_upstream, behind),
		position = footer_position(),
	})
end

local function full_scan(locale: string): { ProjectStatus }
	local result = scan_all()
	vault.notification.info(t(locale, "scan_done", {
		n = tostring(#result.projects),
		dirty = tostring(count_dirty(result.projects)),
		unpushed = tostring(count_unpushed(result.projects)),
		no_upstream = tostring(count_no_upstream(result.projects)),
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
	render_footer(result.projects, locale)
	return result.projects
end

local function build_picker_items(
	entries: { ProjectStatus },
	track: TrackFlags,
	opts: {
		section_dirty: string,
		section_unpushed: string,
		section_no_upstream: string,
		section_behind: string,
		detail_dirty: string,
		detail_unpushed: (ahead: number, branch: string) -> string,
		detail_no_upstream: string,
		detail_behind: (behind: number, branch: string) -> string,
	}
): { { id: string, label: string, detail: string?, icon: string? } }
	local buckets: { { ProjectStatus } } = { {}, {}, {}, {} }
	for _, p in ipairs(entries) do
		if has_dirty(p) and track.dirty then
			table.insert(buckets[1], p)
		elseif has_unpushed(p) and track.unpushed then
			table.insert(buckets[2], p)
		elseif has_no_upstream(p) and track.no_upstream then
			table.insert(buckets[3], p)
		elseif has_behind(p) and track.behind then
			table.insert(buckets[4], p)
		end
	end

	local items: { { id: string, label: string, detail: string?, icon: string? } } = {}
	local headers: { { label: string, icon: string } } = {
		{ label = opts.section_dirty, icon = "mdi--alert-circle" },
		{ label = opts.section_unpushed, icon = "mdi--upload" },
		{ label = opts.section_no_upstream, icon = "mdi--source-branch" },
		{ label = opts.section_behind, icon = "mdi--download" },
	}

	for i, bucket in ipairs(buckets) do
		if #bucket > 0 then
			table.sort(bucket, function(a, b)
				return severity(a) > severity(b)
			end)
			local header = headers[i]
			table.insert(items, {
				id = "section_" .. tostring(i),
				label = header.label .. " (" .. tostring(#bucket) .. ")",
				detail = "",
				icon = header.icon,
			})
			for _, p in ipairs(bucket) do
				local parts: { string } = {}
				if has_dirty(p) then table.insert(parts, opts.detail_dirty) end
				if has_unpushed(p) then table.insert(parts, opts.detail_unpushed(p.ahead, p.branch)) end
				if has_no_upstream(p) then table.insert(parts, opts.detail_no_upstream) end
				if has_behind(p) then table.insert(parts, opts.detail_behind(p.behind, p.branch)) end
				table.insert(items, {
					id = p.id,
					label = p.name,
					detail = table.concat(parts, " · "),
					icon = state_icon(p),
				})
			end
		end
	end

	return items
end

local function show_dirty_picker(locale: string)
	local projects = parse_projects(vault.projects.list()) or {}
	if #projects == 0 then
		vault.notification.info(t(locale, "no_projects"))
		pcall(vault.ui.clear_footer, FOOTER_ID)
		return
	end

	vault.notification.info(t(locale, "scanning", { n = tostring(#projects) }))
	local entries = full_scan(locale)
	local track = get_track_flags()
	local filtered = filter_by_track(entries, track)

	if #filtered == 0 then
		vault.ui.show_quick_pick({
			title = t(locale, "picker_title_empty"),
			items = { { id = "empty", label = t(locale, "no_issues"), icon = "mdi--check-circle" } },
		})
		return
	end

	local items = build_picker_items(filtered, track, {
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

	local title = t(locale, "picker_title", { n = tostring(#filtered) })
	local selected = vault.ui.show_quick_pick({ title = title, items = items })
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
	render_footer(load_cache() or {}, locale)
end

function plugin.execute(command_id: string, context: PluginCommandContext?)
	local locale = vault.i18n.get_locale()

	if command_id == "init" then
		local cache = load_cache() or {}
		if #cache > 0 then
			render_footer(cache, locale)
		else
			pcall(vault.ui.clear_footer, FOOTER_ID)
		end
		return
	end

	if command_id == "project_focus" then
		if vault.settings.get("scan_on_focus") == "false" then
			render_footer(load_cache() or {}, locale)
			return
		end
		render_footer(get_fresh_cache(false), locale)
		return
	end

	if command_id == "git_status_changed" then
		local project_id = context and context.projectId
		if project_id and project_id ~= "" then
			render_footer(update_project_cache(project_id) or {}, locale)
		end
		return
	end

	if command_id == "show_dirty" then
		show_dirty_picker(locale)
		return
	end

	if command_id == "refresh_scan" then
		full_scan(locale)
		return
	end

	if command_id == "show_settings" then
		show_settings_form(locale)
		return
	end
end

return plugin
