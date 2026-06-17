--!strict

export type ProjectStatus = {
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

export type VaultProject = {
	id: string,
	name: string,
	path: string,
}

export type GitStatus = {
	branch: string,
	ahead: number,
	behind: number,
	isDirty: boolean,
	hasUpstream: boolean,
	version: string?,
}

export type ScanResult = {
	projects: { ProjectStatus },
	scanned_at: number,
	errors: { { id: string, name: string, message: string } },
}

local CACHE_KEY = "scan_cache"
local CACHE_TS_KEY = "scan_cache_ts"

local function now_ms(): number
	-- LuaOS time is seconds since epoch; convert to ms.
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
	local raw = vault.settings.get(CACHE_KEY)
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
	vault.settings.set(CACHE_KEY, vault.json.stringify(entries))
	vault.settings.set(CACHE_TS_KEY, tostring(now_ms()))
end

local function load_cache_ts(): number
	local raw = vault.settings.get(CACHE_TS_KEY)
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

local function project_lookup(): { [string]: VaultProject }
	local list = parse_projects(vault.projects.list()) or {}
	local out: { [string]: VaultProject } = {}
	for _, p in ipairs(list) do
		out[p.id] = p
	end
	return out
end

local function scan_one(p: VaultProject, ts: number): (ProjectStatus?, string?)
	local ok, status_or_err = pcall(fetch_status, p.id)
	if not ok then
		return nil, tostring(status_or_err)
	end
	local status = status_or_err :: GitStatus?
	if not status then
		-- Not a git repo, or git failed silently. Skip without error.
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

local function scan_all(): ScanResult
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
	return { projects = entries, scanned_at = ts, errors = errors }
end

local function update_project(project_id: string): { ProjectStatus }?
	local lookup = project_lookup()
	local p = lookup[project_id]
	if not p then
		-- Project no longer in vault: drop from cache.
		local cache = load_cache() or {}
		local idx = find_index(cache, project_id)
		if idx then
			table.remove(cache, idx)
			save_cache(cache)
		end
		return cache
	end
	local entry, _err = scan_one(p, now_ms())
	local cache = load_cache() or {}
	local idx = find_index(cache, project_id)
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

local function is_stale(ts: number, ttl_ms: number): boolean
	if ts <= 0 then
		return true
	end
	return (now_ms() - ts) > ttl_ms
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
	if n < 10 then
		n = 10
	end
	if n > 600 then
		n = 600
	end
	return n * 1000
end

local function get_fresh_cache(force: boolean?): { ProjectStatus }
	local cache = load_cache() or {}
	local ts = load_cache_ts()
	if force or is_stale(ts, ttl_ms()) then
		return scan_all().projects
	end
	return cache
end

return {
	scan_all = scan_all,
	update_project = update_project,
	get_fresh_cache = get_fresh_cache,
	load_cache = load_cache,
}
