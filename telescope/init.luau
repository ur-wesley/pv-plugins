--!strict

local fs = (require :: any)("./lib/fs")
local projects = (require :: any)("./lib/projects")

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

local plugin = {
	name = "Picker Library",
	description = "Shared picker and multi-project scan utilities for dependent plugins.",
	version = "1.0.0",
	category = "library",
	lazy = true,
	exports = {
		pick_index = pick_index,
		list_projects = projects.list_projects,
		walk_files = fs.walk_files,
	},
}

return plugin
