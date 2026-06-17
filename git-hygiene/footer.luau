--!strict

local picker = (require :: any)("./picker")
local scan = (require :: any)("./scan")

type ProjectStatus = scan.ProjectStatus
type FooterStrings = {
	clean: string,
	summary: (dirty: number, unpushed: number) -> string,
	summary_full: (dirty: number, unpushed: number, no_upstream: number, behind: number) -> string,
}

local FOOTER_ID = "git_hygiene_state"

local function position(): string
	local raw = vault.settings.get("footer_position")
	if raw == "left" or raw == "right" then
		return raw
	end
	return "right"
end

local function is_enabled(): boolean
	return vault.settings.get("show_in_footer") ~= "false"
end

local function clear()
	pcall(vault.ui.clear_footer, FOOTER_ID)
end

local function color_for(dirty: number, unpushed: number, no_upstream: number, behind: number): string
	if dirty > 0 then
		return "warning"
	end
	if unpushed > 0 then
		return "primary"
	end
	if no_upstream > 0 or behind > 0 then
		return "muted"
	end
	return "success"
end

local function render(entries: { ProjectStatus }, t: FooterStrings)
	if not is_enabled() then
		clear()
		return
	end

	local dirty = picker.count_dirty(entries)
	local unpushed = picker.count_unpushed(entries)
	local no_upstream = picker.count_no_upstream(entries)
	local behind = picker.count_behind(entries)

	local text: string
	if dirty == 0 and unpushed == 0 and no_upstream == 0 and behind == 0 then
		text = t.clean
	elseif behind > 0 or no_upstream > 0 then
		text = t.summary_full(dirty, unpushed, no_upstream, behind)
	else
		text = t.summary(dirty, unpushed)
	end

	local tooltip_lines: { string } = {}
	if dirty > 0 then
		table.insert(tooltip_lines, tostring(dirty) .. " dirty")
	end
	if unpushed > 0 then
		table.insert(tooltip_lines, tostring(unpushed) .. " unpushed")
	end
	if no_upstream > 0 then
		table.insert(tooltip_lines, tostring(no_upstream) .. " no upstream")
	end
	if behind > 0 then
		table.insert(tooltip_lines, tostring(behind) .. " behind")
	end
	if #tooltip_lines == 0 then
		table.insert(tooltip_lines, t.clean)
	end
	table.insert(tooltip_lines, "Click to view details")

	pcall(vault.ui.set_footer, {
		id = FOOTER_ID,
		text = text,
		icon = dirty > 0 and "mdi--alert-circle" or "mdi--broom",
		tooltip = table.concat(tooltip_lines, "\n"),
		command = "show_dirty",
		color = color_for(dirty, unpushed, no_upstream, behind),
		position = position(),
	})
end

return {
	render = render,
	clear = clear,
	FOOTER_ID = FOOTER_ID,
}
