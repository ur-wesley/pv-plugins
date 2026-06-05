--!strict

type QuickPickItem = {
	id: string,
	label: string,
	detail: string?,
	icon: string?,
	filePath: string?,
	lineNumber: number?,
}

type PickIndexOptions = {
	title: string,
	items: { QuickPickItem },
	fuzzy: boolean?,
	preview: boolean?,
}

local function pick_index(options: PickIndexOptions): string?
	return vault.ui.show_quick_pick({
		title = options.title,
		items = options.items,
		fuzzy = options.fuzzy,
		preview = options.preview,
	})
end

local fs_mod: any = nil
local projects_mod: any = nil

local function fs()
	if not fs_mod then
		fs_mod = (require :: any)("./fs")
	end
	return fs_mod
end

local function projects()
	if not projects_mod then
		projects_mod = (require :: any)("./projects")
	end
	return projects_mod
end

local plugin = {
	name = "Picker Library",
	description = "Shared picker and multi-project scan utilities for dependent plugins.",
	version = "1.0.0",
	category = "library",
	lazy = true,
	exports = {
		pick_index = pick_index,
		list_projects = function(...)
			return projects().list_projects(...)
		end,
		walk_files = function(...)
			return fs().walk_files(...)
		end,
	},
}

return plugin
