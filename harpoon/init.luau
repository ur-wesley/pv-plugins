--!strict

type PluginLocales = {
	en: { [string]: string },
	de: { [string]: string },
}

type ProjectItem = {
	id: string,
	name: string,
}

type VaultProject = {
	id: string,
	name: string,
	path: string,
}

type QuickPickItem = {
	id: string,
	label: string,
	detail: string?,
	icon: string?,
}

type PluginCommandContext = {
    projectId: string?
}

local plugin = {
    name = "Harpoon",
    description = "Mark your favourite projects and jump between them instantly.",
    version = "1.1.0",
    category = "utility",
    lazy = true,
    cmd = { "mark_project", "quick_menu", "manage_harpoon", "jump_1", "jump_2", "jump_3", "jump_4", "clear_harpoon" },
    event = { "project_focus", "startup" },
    locales = {
        en = {
            name = "Harpoon",
            description = "Mark your favourite projects and jump between them instantly.",
            ["command.mark_project"] = "Harpoon: Mark Current Project",
            ["command.quick_menu"] = "Harpoon: Show Quick Menu",
            ["command.manage_harpoon"] = "Harpoon: Manage Marked Projects",
            ["command.jump_1"] = "Harpoon: Jump to Project 1",
            ["command.jump_2"] = "Harpoon: Jump to Project 2",
            ["command.jump_3"] = "Harpoon: Jump to Project 3",
            ["command.jump_4"] = "Harpoon: Jump to Project 4",
            ["command.clear_harpoon"] = "Harpoon: Clear All Marked Projects",

            no_active_project = "Harpoon: No active project is currently selected to mark.",
            marked_success = "Harpooned project: '{name}' in slot {slot}!",
            already_marked = "Project '{name}' is already harpooned in slot {slot}!",
            unmarked_success = "Removed project: '{name}' from Harpoon slot {slot}!",
            menu_title = "Harpooned Projects",
            empty_menu = "No projects harpooned yet! Mark some projects first.",
            cleared_success = "Cleared all harpooned projects.",
            jump_empty = "No project harpooned in slot {slot} yet.",
            jump_success = "Jumped to slot {slot}: '{name}'",

            manage_title = "Manage Harpoon",
            manage_empty = "No projects marked yet.",
            action_jump = "Jump to this project",
            action_move_up = "Move up",
            action_move_down = "Move down",
            action_remove = "Remove from Harpoon",
            action_cancel = "Cancel",
            removed = "Removed '{name}' from Harpoon.",
            moved_up = "Moved '{name}' up to slot {slot}.",
            moved_down = "Moved '{name}' down to slot {slot}.",
            cap_reached = "Harpoon is full ({n}/{max}). Use 'Manage Harpoon' to make room.",
            entries_removed_single = "Removed '{name}' from Harpoon (no longer in vault).",
            entries_removed_many = "Removed {n} stale entries from Harpoon (no longer in vault)."
        },
        de = {
            name = "Harpoon",
            description = "Markieren Sie Ihre Lieblingsprojekte und springen Sie sofort zwischen ihnen hin und her.",
            ["command.mark_project"] = "Harpoon: Aktuelles Projekt markieren",
            ["command.quick_menu"] = "Harpoon: Schnellmenü anzeigen",
            ["command.manage_harpoon"] = "Harpoon: Markierte Projekte verwalten",
            ["command.jump_1"] = "Harpoon: Zu Projekt 1 springen",
            ["command.jump_2"] = "Harpoon: Zu Projekt 2 springen",
            ["command.jump_3"] = "Harpoon: Zu Projekt 3 springen",
            ["command.jump_4"] = "Harpoon: Zu Projekt 4 springen",
            ["command.clear_harpoon"] = "Harpoon: Alle markierten Projekte löschen",

            no_active_project = "Harpoon: Es ist derzeit kein aktives Projekt zum Markieren ausgewählt.",
            marked_success = "Projekt harpooniert: '{name}' in Slot {slot}!",
            already_marked = "Projekt '{name}' ist bereits in Slot {slot} harpooniert!",
            unmarked_success = "Projekt entfernt: '{name}' aus Harpoon-Slot {slot}!",
            menu_title = "Harponierte Projekte",
            empty_menu = "Noch keine Projekte harpooniert! Markieren Sie zuerst einige Projekte.",
            cleared_success = "Alle harpoonierten Projekte gelöscht.",
            jump_empty = "Noch kein Projekt in Slot {slot} harpooniert.",
            jump_success = "Zu Slot {slot} gesprungen: '{name}'",

            manage_title = "Harpoon verwalten",
            manage_empty = "Noch keine Projekte markiert.",
            action_jump = "Zu diesem Projekt springen",
            action_move_up = "Nach oben verschieben",
            action_move_down = "Nach unten verschieben",
            action_remove = "Aus Harpoon entfernen",
            action_cancel = "Abbrechen",
            removed = "'{name}' aus Harpoon entfernt.",
            moved_up = "'{name}' nach oben in Slot {slot} verschoben.",
            moved_down = "'{name}' nach unten in Slot {slot} verschoben.",
            cap_reached = "Harpoon ist voll ({n}/{max}). Verwenden Sie 'Harpoon verwalten', um Platz zu schaffen.",
            entries_removed_single = "'{name}' aus Harpoon entfernt (nicht mehr im Vault).",
            entries_removed_many = "{n} veraltete Einträge aus Harpoon entfernt (nicht mehr im Vault)."
        }
    },
    config = {
        {
            key = "max_entries",
            type = "number",
            label = "Maximum Entries",
            description = "Maximum number of projects that can be pinned. Min 1, max 16.",
            default = 8
        },
        {
            key = "toggle_mode",
            type = "boolean",
            label = "Toggle Project Mark",
            description = "If enabled, trying to mark an already marked project will unmark (remove) it instead of showing an error.",
            default = false
        },
        {
            key = "show_in_footer",
            type = "boolean",
            label = "Show in Footer",
            description = "If enabled, shows Harpoon slots and anchor in the status bar footer.",
            default = true
        }
    },
    commands = {
        { id = "mark_project", title = "Harpoon: Mark Current Project", scope = "global" },
        { id = "quick_menu", title = "Harpoon: Show Quick Menu", scope = "global" },
        { id = "manage_harpoon", title = "Harpoon: Manage Marked Projects", scope = "global" },
        { id = "jump_1", title = "Harpoon: Jump to Project 1", scope = "global" },
        { id = "jump_2", title = "Harpoon: Jump to Project 2", scope = "global" },
        { id = "jump_3", title = "Harpoon: Jump to Project 3", scope = "global" },
        { id = "jump_4", title = "Harpoon: Jump to Project 4", scope = "global" },
        { id = "clear_harpoon", title = "Harpoon: Clear All Marked Projects", scope = "global" }
    }
}

local function translate(locales: PluginLocales, locale: string, key: string, args: { [string]: string }?): string
	local dict: { [string]: string } = if locale == "de" then locales.de else locales.en
	local str = dict[key] or key
	if args then
		for k, v in pairs(args) do
			str = str:gsub("{" .. k .. "}", tostring(v))
		end
	end
	return str
end

local function t(locale: string, key: string, args: { [string]: string }?): string
	return translate(plugin.locales :: PluginLocales, locale, key, args)
end

local function parseProjects(raw: string): { VaultProject }?
	local ok, parsed = pcall(function()
		return vault.json.parse(raw)
	end)
	if ok and type(parsed) == "table" then
		return parsed :: { VaultProject }
	end
	return nil
end

-- Get stored list of projects
local function get_harpooned(): {ProjectItem}
    local raw = vault.settings.get("marked_projects")
    if not raw or raw == "" then
        return {}
    end
    local ok, parsed = pcall(function()
        return vault.json.parse(raw)
    end)
    if ok and type(parsed) == "table" then
        return parsed :: { ProjectItem }
    end
    return {}
end

-- Save list of projects
local function save_harpooned(list: {ProjectItem})
    local raw = vault.json.stringify(list)
    vault.settings.set("marked_projects", raw)
end

local function get_max_entries(): number
    local raw = vault.settings.get("max_entries")
    if not raw or raw == "" then return 8 end
    local n = tonumber(raw)
    if not n then return 8 end
    n = math.floor(n)
    if n < 1 then return 1 end
    if n > 16 then return 16 end
    return n
end

-- Removes entries whose project no longer exists in the vault and trims the
-- list to the configured cap. Persists changes and emits a single notification
-- summarising what was removed.
local function maybe_clean_stale(locale: string): {ProjectItem}
    local list = get_harpooned()
    local all = parseProjects(vault.projects.list()) or {}
    local by_id: { [string]: boolean } = {}
    for _, p in ipairs(all) do
        by_id[p.id] = true
    end

    local removed_names: {string} = {}
    local kept: {ProjectItem} = {}
    for _, item in ipairs(list) do
        if by_id[item.id] then
            table.insert(kept, item)
        else
            table.insert(removed_names, item.name)
        end
    end

    -- Trim if max_entries has been reduced since the list was last saved
    local max = get_max_entries()
    while #kept > max do
        table.insert(removed_names, kept[#kept].name)
        table.remove(kept)
    end

    if #removed_names > 0 then
        save_harpooned(kept)
        if #removed_names == 1 then
            vault.notification.info(t(locale, "entries_removed_single", { name = removed_names[1] }))
        else
            vault.notification.info(t(locale, "entries_removed_many", { n = tostring(#removed_names) }))
        end
    end
    return kept
end

-- Sync the footer chip with the current harpoon state.
-- current_slot: the slot number of the currently viewed project, or nil if not harpooned.
-- Always shows a 4-slot window that tracks the active project (slides right as it
-- advances past slot 4), or the first 4 slots when no project is active.
local function sync_footer(list: {ProjectItem}, current_slot: number?)
    local show_in_footer = vault.settings.get("show_in_footer") ~= "false"
    if not show_in_footer or #list == 0 then
        vault.ui.clear_footer("harpoon_state")
        return
    end

    local max = get_max_entries()
    local total = math.min(#list, max)

    local start: number
    local finish: number
    if current_slot and current_slot >= 1 and current_slot <= total then
        -- Window of 4 slots, with the active slot anchored inside it. When the
        -- active slot is in the first 4, the window covers 1..4; once it advances
        -- past 4, the window slides so the active slot is always visible.
        start = math.max(1, math.min(current_slot, total - 3))
        finish = math.min(start + 3, total)
    else
        start = 1
        finish = math.min(total, 4)
    end

    local slots: {string} = {}
    for i = start, finish do
        if i == current_slot then
            table.insert(slots, "[" .. tostring(i) .. "]")
        elseif list[i] then
            table.insert(slots, tostring(i))
        else
            table.insert(slots, "·")
        end
    end

    -- Tooltip lists every pinned project, marking the active one
    local names: {string} = {}
    for i, item in ipairs(list) do
        local prefix = (i == current_slot) and "▸ " or "  "
        table.insert(names, prefix .. tostring(i) .. ": " .. item.name)
    end

    vault.ui.set_footer({
        id      = "harpoon_state",
        text    = table.concat(slots, "  "),
        icon    = "mdi--anchor",
        tooltip = table.concat(names, "\n"),
        command = "quick_menu",
        color   = current_slot and "success" or "primary",
    })
end

-- Find project by ID inside list
local function find_project_index(list: {ProjectItem}, id: string?): number?
    if not id then return nil end
    for idx, item in ipairs(list) do
        if item.id == id then
            return idx
        end
    end
    return nil
end

-- Look up project metadata by ID
local function get_project_metadata(project_id: string): ProjectItem?
    local list = parseProjects(vault.projects.list())
    if list then
        for _, p in ipairs(list) do
            if p.id == project_id then
                return p
            end
        end
    end
    return nil
end

-- Action picker for a single marked project. After a move or remove, the flow
-- terminates and the user can re-invoke 'Harpoon: Manage Marked Projects' to
-- continue editing. (Re-opening the project picker would require mutual
-- recursion between these two helpers, which the type-checker doesn't like.)
local function show_action_picker(list: {ProjectItem}, idx: number, locale: string, active_id: string?)

    local item = list[idx]
    local actions: {QuickPickItem} = {}
    table.insert(actions, {
        id = "jump",
        label = t(locale, "action_jump"),
        detail = item.name,
        icon = "mdi--open-in-app"
    })
    if idx > 1 then
        table.insert(actions, {
            id = "up",
            label = t(locale, "action_move_up"),
            detail = "→ slot " .. tostring(idx - 1),
            icon = "mdi--arrow-up"
        })
    end
    if idx < #list then
        table.insert(actions, {
            id = "down",
            label = t(locale, "action_move_down"),
            detail = "→ slot " .. tostring(idx + 1),
            icon = "mdi--arrow-down"
        })
    end
    table.insert(actions, {
        id = "remove",
        label = t(locale, "action_remove"),
        detail = item.name,
        icon = "mdi--delete"
    })
    table.insert(actions, {
        id = "cancel",
        label = t(locale, "action_cancel"),
        icon = "mdi--close"
    })

    local selected = vault.ui.show_quick_pick({
        title = t(locale, "manage_title") .. ": " .. item.name,
        items = actions
    })

    if not selected or selected == "cancel" then return end

    if selected == "jump" then
        vault.ui.open_project_file(item.id, "", 0)
        vault.notification.info(t(locale, "jump_success", { slot = tostring(idx), name = item.name }))
        return
    end

    if selected == "up" and idx > 1 then
        local prev = list[idx - 1]
        list[idx - 1] = item
        list[idx] = prev
        save_harpooned(list)
        sync_footer(list, find_project_index(list, active_id))
        vault.notification.info(t(locale, "moved_up", { name = item.name, slot = tostring(idx - 1) }))
        return
    end

    if selected == "down" and idx < #list then
        local next_item = list[idx + 1]
        list[idx + 1] = item
        list[idx] = next_item
        save_harpooned(list)
        sync_footer(list, find_project_index(list, active_id))
        vault.notification.info(t(locale, "moved_down", { name = item.name, slot = tostring(idx + 1) }))
        return
    end

    if selected == "remove" then
        table.remove(list, idx)
        save_harpooned(list)
        sync_footer(list, find_project_index(list, active_id))
        vault.notification.info(t(locale, "removed", { name = item.name }))
        return
    end
end

local function show_manage_picker(locale: string, active_id: string?)

    local list = maybe_clean_stale(locale)
    if #list == 0 then
        vault.ui.show_quick_pick({
            title = t(locale, "manage_title"),
            items = {
                { id = "empty", label = t(locale, "manage_empty") }
            }
        })
        return
    end

    local items: {QuickPickItem} = {}
    for i, item in ipairs(list) do
        table.insert(items, {
            id = tostring(i),
            label = tostring(i) .. ". " .. item.name,
            detail = item.id,
            icon = "mdi--anchor"
        })
    end

    local selected = vault.ui.show_quick_pick({
        title = t(locale, "manage_title"),
        items = items
    })

    if not selected then return end
    local idx = tonumber(selected)
    if not idx or not list[idx] then return end

    show_action_picker(list, idx, locale, active_id)
end

function plugin.execute(command_id: string, context: PluginCommandContext?)
    local locale: string = vault.i18n.get_locale()

    if command_id == "mark_project" then
        local project_id = context and context.projectId
        if not project_id or project_id == "" then
            vault.notification.error(t(locale, "no_active_project"))
            return
        end

        local project = get_project_metadata(project_id)
        if not project then
            vault.notification.error(t(locale, "no_active_project"))
            return
        end

        local list = maybe_clean_stale(locale)
        local existing_slot = find_project_index(list, project_id)

        if existing_slot then
            local toggle_mode = vault.settings.get("toggle_mode") == "true"
            if toggle_mode then
                table.remove(list, existing_slot)
                save_harpooned(list)
                sync_footer(list, nil)
                vault.notification.success(t(locale, "unmarked_success", { name = project.name, slot = tostring(existing_slot) }))
            else
                vault.notification.info(t(locale, "already_marked", { name = project.name, slot = tostring(existing_slot) }))
            end
            return
        end

        local max = get_max_entries()
        if #list >= max then
            vault.notification.warn(t(locale, "cap_reached", { n = tostring(#list), max = tostring(max) }))
            return
        end
        table.insert(list, { id = project.id, name = project.name })
        save_harpooned(list)
        sync_footer(list, find_project_index(list, project_id))
        vault.notification.success(t(locale, "marked_success", { name = project.name, slot = tostring(#list) }))

    elseif command_id == "quick_menu" then
        local list = maybe_clean_stale(locale)
        if #list == 0 then
            vault.ui.show_quick_pick({
                title = t(locale, "menu_title"),
                items = {
                    { id = "empty", label = t(locale, "empty_menu") }
                }
            })
            return
        end

        local items: {QuickPickItem} = {}
        for i, item in ipairs(list) do
            table.insert(items, {
                id = tostring(i),
                label = tostring(i) .. ". " .. item.name,
                detail = item.id,
                icon = "mdi--anchor"
            })
        end

        local selected = vault.ui.show_quick_pick({
            title = t(locale, "menu_title"),
            items = items
        })

        if selected then
            local idx = tonumber(selected)
            if idx and list[idx] then
                local item = list[idx]
                vault.ui.open_project_file(item.id, "", 0)
                vault.notification.info(t(locale, "jump_success", { slot = tostring(idx), name = item.name }))
            end
        end

    elseif command_id == "manage_harpoon" then
        local active_id = context and context.projectId
        show_manage_picker(locale, active_id)

    elseif command_id:find("^jump_") then
        local slot_str = command_id:match("^jump_(%d+)$")
        local slot = slot_str and tonumber(slot_str)
        if slot then
            local list = maybe_clean_stale(locale)
            if list[slot] then
                local item = list[slot]
                vault.ui.open_project_file(item.id, "", 0)
                vault.notification.info(t(locale, "jump_success", { slot = tostring(slot), name = item.name }))
            else
                vault.notification.error(t(locale, "jump_empty", { slot = tostring(slot) }))
            end
        end

    elseif command_id == "clear_harpoon" then
        save_harpooned({})
        sync_footer({}, nil)
        vault.notification.success(t(locale, "cleared_success"))

    elseif command_id == "init" then
        -- Restore footer state on app startup (no project focused yet)
        sync_footer(maybe_clean_stale(locale), nil)

    elseif command_id == "project_focus" then
        -- Called by the app whenever the active project changes
        local project_id = context and context.projectId
        local list = maybe_clean_stale(locale)
        local slot: number? = nil
        if project_id and project_id ~= "" then
            slot = find_project_index(list, project_id)
        end
        sync_footer(list, slot)
    end
end

return plugin
