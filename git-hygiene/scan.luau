--!strict

local types = (require :: any)("./types")
local query = (require :: any)("./query")

type ProjectStatus = types.ProjectStatus
type VaultProject = types.VaultProject
type GitStatus = types.GitStatus
type ScanResult = types.ScanResult

local SCAN_CACHE_KEY = "scan_cache"
local SCAN_CACHE_TS_KEY = "scan_cache_ts"

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
	return { projects = entries, errors = errors }
end

local function get_fresh_cache(force: boolean?): { ProjectStatus }
	local cache = load_cache() or {}
	local ts = load_cache_ts()
	if force or ts <= 0 or (now_ms() - ts) > ttl_ms() then
		return scan_all().projects
	end
	return cache
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

local function full_scan(
	locale: string,
	t: (string, string, { [string]: any }?) -> string,
	on_scanned: ((entries: { ProjectStatus }, locale: string) -> ())?
): { ProjectStatus }
	local result = scan_all()
	vault.notification.info(t(locale, "scan_done", {
		n = tostring(#result.projects),
		dirty = tostring(query.count_dirty(result.projects)),
		unpushed = tostring(query.count_unpushed(result.projects)),
		no_upstream = tostring(query.count_no_upstream(result.projects)),
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
	if on_scanned then
		on_scanned(result.projects, locale)
	end
	return result.projects
end

return {
	now_ms = now_ms,
	parse_projects = parse_projects,
	parse_status = parse_status,
	fetch_status = fetch_status,
	load_cache = load_cache,
	save_cache = save_cache,
	load_cache_ts = load_cache_ts,
	scan_all = scan_all,
	get_fresh_cache = get_fresh_cache,
	update_project_cache = update_project_cache,
	full_scan = full_scan,
}
