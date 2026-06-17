--!strict

local scan = (require :: any)("./scan")

type ProjectStatus = scan.ProjectStatus
type VaultQuickPickItem = {
	id: string,
	label: string,
	detail: string?,
	icon: string?,
}

type PickOptions = {
	title: string,
	section_dirty: string,
	section_unpushed: string,
	section_no_upstream: string,
	section_behind: string,
	detail_dirty: string,
	detail_unpushed: (ahead: number, branch: string) -> string,
	detail_no_upstream: string,
	detail_behind: (behind: number, branch: string) -> string,
}

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

-- Severity: higher means more urgent, sort first.
local function severity(p: ProjectStatus): number
	local s = 0
	if has_dirty(p) and has_unpushed(p) then
		s = 40
	elseif has_dirty(p) then
		s = 30
	elseif has_unpushed(p) then
		s = 20
	elseif has_no_upstream(p) then
		s = 10
	elseif has_behind(p) then
		s = 5
	end
	return s
end

local function is_dirty_unpushed_no_upstream(p: ProjectStatus): boolean
	return has_dirty(p) or has_unpushed(p) or has_no_upstream(p)
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

local function build_project_detail(
	p: ProjectStatus,
	opts: PickOptions
): string
	local parts: { string } = {}
	if has_dirty(p) then
		table.insert(parts, opts.detail_dirty)
	end
	if has_unpushed(p) then
		table.insert(parts, opts.detail_unpushed(p.ahead, p.branch))
	end
	if has_no_upstream(p) then
		table.insert(parts, opts.detail_no_upstream)
	end
	if has_behind(p) then
		table.insert(parts, opts.detail_behind(p.behind, p.branch))
	end
	return table.concat(parts, " · ")
end

local function build_item(p: ProjectStatus, opts: PickOptions): VaultQuickPickItem
	return {
		id = p.id,
		label = p.name,
		detail = build_project_detail(p, opts),
		icon = state_icon(p),
	}
end

local function build_items(
	entries: { ProjectStatus },
	track: { dirty: boolean, unpushed: boolean, no_upstream: boolean, behind: boolean },
	opts: PickOptions
): { VaultQuickPickItem }
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

	local items: { VaultQuickPickItem } = {}
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
				table.insert(items, build_item(p, opts))
			end
		end
	end

	return items
end

local function count_dirty(entries: { ProjectStatus }): number
	local n = 0
	for _, p in ipairs(entries) do
		if has_dirty(p) then
			n = n + 1
		end
	end
	return n
end

local function count_unpushed(entries: { ProjectStatus }): number
	local n = 0
	for _, p in ipairs(entries) do
		if has_unpushed(p) then
			n = n + 1
		end
	end
	return n
end

local function count_no_upstream(entries: { ProjectStatus }): number
	local n = 0
	for _, p in ipairs(entries) do
		if has_no_upstream(p) then
			n = n + 1
		end
	end
	return n
end

local function count_behind(entries: { ProjectStatus }): number
	local n = 0
	for _, p in ipairs(entries) do
		if has_behind(p) then
			n = n + 1
		end
	end
	return n
end

return {
	build_items = build_items,
	count_dirty = count_dirty,
	count_unpushed = count_unpushed,
	count_no_upstream = count_no_upstream,
	count_behind = count_behind,
	has_dirty = has_dirty,
	has_unpushed = has_unpushed,
	has_no_upstream = has_no_upstream,
	has_behind = has_behind,
	is_dirty_unpushed_no_upstream = is_dirty_unpushed_no_upstream,
	severity = severity,
}
