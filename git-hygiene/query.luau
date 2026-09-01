--!strict

local types = (require :: any)("./types")
type ProjectStatus = types.ProjectStatus
type TrackFlags = types.TrackFlags

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

return {
	has_dirty = has_dirty,
	has_unpushed = has_unpushed,
	has_no_upstream = has_no_upstream,
	has_behind = has_behind,
	severity = severity,
	state_icon = state_icon,
	count_dirty = count_dirty,
	count_unpushed = count_unpushed,
	count_no_upstream = count_no_upstream,
	count_behind = count_behind,
	filter_by_track = filter_by_track,
}
