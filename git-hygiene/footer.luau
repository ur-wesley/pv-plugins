--!strict

local types = (require :: any)("./types")
local query = (require :: any)("./query")

type ProjectStatus = types.ProjectStatus

local FOOTER_ID = "git_hygiene_state"

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

local function clear()
	pcall(vault.ui.clear_footer, FOOTER_ID)
end

local function render(
	entries: { ProjectStatus },
	locale: string,
	t: (string, string, { [string]: any }?) -> string
)
	if not footer_enabled() then
		clear()
		return
	end

	local dirty = query.count_dirty(entries)
	local unpushed = query.count_unpushed(entries)
	local no_upstream = query.count_no_upstream(entries)
	local behind = query.count_behind(entries)

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

return {
	FOOTER_ID = FOOTER_ID,
	render = render,
	clear = clear,
}
