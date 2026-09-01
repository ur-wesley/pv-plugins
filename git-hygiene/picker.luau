--!strict

local types = (require :: any)("./types")
local query = (require :: any)("./query")
local scan = (require :: any)("./scan")
local settings = (require :: any)("./settings")

type ProjectStatus = types.ProjectStatus
type TrackFlags = types.TrackFlags
type QuickPickItem = types.QuickPickItem

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
): { QuickPickItem }
	local buckets: { { ProjectStatus } } = { {}, {}, {}, {} }
	for _, p in ipairs(entries) do
		if query.has_dirty(p) and track.dirty then
			table.insert(buckets[1], p)
		elseif query.has_unpushed(p) and track.unpushed then
			table.insert(buckets[2], p)
		elseif query.has_no_upstream(p) and track.no_upstream then
			table.insert(buckets[3], p)
		elseif query.has_behind(p) and track.behind then
			table.insert(buckets[4], p)
		end
	end

	local items: { QuickPickItem } = {}
	local headers: { { label: string, icon: string } } = {
		{ label = opts.section_dirty, icon = "mdi--alert-circle" },
		{ label = opts.section_unpushed, icon = "mdi--upload" },
		{ label = opts.section_no_upstream, icon = "mdi--source-branch" },
		{ label = opts.section_behind, icon = "mdi--download" },
	}

	for i, bucket in ipairs(buckets) do
		if #bucket > 0 then
			table.sort(bucket, function(a, b)
				return query.severity(a) > query.severity(b)
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
				if query.has_dirty(p) then table.insert(parts, opts.detail_dirty) end
				if query.has_unpushed(p) then table.insert(parts, opts.detail_unpushed(p.ahead, p.branch)) end
				if query.has_no_upstream(p) then table.insert(parts, opts.detail_no_upstream) end
				if query.has_behind(p) then table.insert(parts, opts.detail_behind(p.behind, p.branch)) end
				table.insert(items, {
					id = p.id,
					label = p.name,
					detail = table.concat(parts, " · "),
					icon = query.state_icon(p),
				})
			end
		end
	end

	return items
end

local function get_picker_options(
	locale: string,
	t: (string, string, { [string]: any }?) -> string
)
	return {
		section_dirty = t(locale, "section_dirty"),
		section_unpushed = t(locale, "section_unpushed"),
		section_no_upstream = t(locale, "section_no_upstream"),
		section_behind = t(locale, "section_behind"),
		detail_dirty = t(locale, "detail_dirty"),
		detail_unpushed = function(ahead: number, branch: string)
			return t(locale, "detail_unpushed", { n = tostring(ahead), branch = branch })
		end,
		detail_no_upstream = t(locale, "detail_no_upstream"),
		detail_behind = function(behind: number, branch: string)
			return t(locale, "detail_behind", { n = tostring(behind), branch = branch })
		end,
	}
end

local function open_project(project_id: string)
	if project_id and project_id ~= "" and not project_id:find("^section_") and project_id ~= "empty" then
		vault.ui.open_project_file(project_id, "", 0)
	end
end

local function update_page(
	locale: string,
	t: (string, string, { [string]: any }?) -> string,
	entries: { ProjectStatus }
)
	local track = settings.get_track_flags()
	local filtered = query.filter_by_track(entries, track)
	local title = if #filtered == 0
		then t(locale, "picker_title_empty")
		else t(locale, "picker_title", { n = tostring(#filtered) })

	local items: { QuickPickItem }
	if #filtered == 0 then
		items = { { id = "empty", label = t(locale, "no_issues"), icon = "mdi--check-circle" } }
	else
		local opts = get_picker_options(locale, t)
		items = build_picker_items(filtered, track, opts)
	end

	pcall(vault.ui.set_page, {
		id = "dirty",
		title = title,
		itemCommand = "open_item",
		items = items,
	})
end

local function show_dirty_picker(
	locale: string,
	t: (string, string, { [string]: any }?) -> string,
	render_footer: ((entries: { ProjectStatus }, locale: string) -> ())?
)
	local projects = scan.parse_projects(vault.projects.list()) or {}
	if #projects == 0 then
		vault.notification.info(t(locale, "no_projects"))
		if render_footer then
			render_footer({}, locale)
		end
		return
	end

	vault.notification.info(t(locale, "scanning", { n = tostring(#projects) }))
	local entries = scan.full_scan(locale, t, render_footer)
	local track = settings.get_track_flags()
	local filtered = query.filter_by_track(entries, track)

	update_page(locale, t, entries)

	if #filtered == 0 then
		vault.ui.show_quick_pick({
			title = t(locale, "picker_title_empty"),
			items = { { id = "empty", label = t(locale, "no_issues"), icon = "mdi--check-circle" } },
		})
		return
	end

	local opts = get_picker_options(locale, t)
	local items = build_picker_items(filtered, track, opts)
	local title = t(locale, "picker_title", { n = tostring(#filtered) })
	local selected = vault.ui.show_quick_pick({ title = title, items = items })
	if selected and selected ~= "" then
		open_project(selected)
	end
end

return {
	build_picker_items = build_picker_items,
	open_project = open_project,
	update_page = update_page,
	show_dirty_picker = show_dirty_picker,
}
