--!strict
-- Canonical plugin manifest for monorepo Git repositories.
-- Parsed on install from plugins.registry.luau at the repo root.
-- Each entry's `dir` is the subdirectory containing init.luau (relative to repo root).
return {
  {
    id = "catppuccin-theme",
    dir = "catppuccin-theme",
    lazy = true,
    category = "theme",
    version = "1.0.0",
    enabled = true,
    options = {
      { id = "latte", label = "Catppuccin Latte" },
      { id = "frappe", label = "Catppuccin Frappe" },
      { id = "macchiato", label = "Catppuccin Macchiato" },
      { id = "mocha", label = "Catppuccin Mocha" }
    },
    config = {
      {
        key = "flavor",
        type = "select",
        label = "Theme Flavor",
        description = "Select your preferred Catppuccin flavor.",
        default = "mocha",
        options = {
          { id = "latte", label = "Catppuccin Latte" },
          { id = "frappe", label = "Catppuccin Frappe" },
          { id = "macchiato", label = "Catppuccin Macchiato" },
          { id = "mocha", label = "Catppuccin Mocha" }
        }
      }
    }
  },
  {
    id = "harpoon",
    dir = "harpoon",
    lazy = true,
    category = "utility",
    version = "1.0.0",
    enabled = true,
    commands = {
      { id = "mark_project", title = "Harpoon: Mark Current Project", scope = "global" },
      { id = "quick_menu", title = "Harpoon: Show Quick Menu", scope = "global" },
      { id = "jump_1", title = "Harpoon: Jump to Project 1", scope = "global" },
      { id = "jump_2", title = "Harpoon: Jump to Project 2", scope = "global" },
      { id = "jump_3", title = "Harpoon: Jump to Project 3", scope = "global" },
      { id = "jump_4", title = "Harpoon: Jump to Project 4", scope = "global" },
      { id = "clear_harpoon", title = "Harpoon: Clear All Marked Projects", scope = "global" }
    },
    cmd = { "mark_project", "quick_menu", "jump_1", "jump_2", "jump_3", "jump_4", "clear_harpoon" },
    event = { "project_focus", "startup" }
  },
  {
    id = "mise",
    dir = "mise",
    lazy = true,
    category = "utility",
    version = "1.0.0",
    enabled = true,
    commands = {
      { id = "manage_tools", title = "Mise: Manage Project Tools", scope = "project" }
    },
    cmd = { "manage_tools" }
  },
  {
    id = "search-all-projects",
    dir = "search-all-projects",
    lazy = true,
    category = "utility",
    version = "1.0.0",
    enabled = true,
    commands = {
      { id = "search_all", title = "Search: Query all project files", scope = "global" }
    },
    cmd = { "search_all" }
  },
  {
    id = "fzf-project-files",
    dir = "fzf-project-files",
    lazy = true,
    category = "utility",
    version = "1.0.0",
    enabled = true,
    commands = {
      { id = "find_files", title = "FZF: Find files in project", scope = "project" }
    },
    cmd = { "find_files" }
  },
  {
    id = "todo-telescope",
    dir = "todo-telescope",
    lazy = true,
    category = "utility",
    version = "1.0.0",
    enabled = true,
    commands = {
      { id = "scan_todos", title = "Telescope: Search Workspaces for TODOs", scope = "global" }
    },
    cmd = { "scan_todos" }
  },
  {
    id = "auto-session-manager",
    dir = "auto-session-manager",
    lazy = true,
    category = "utility",
    version = "1.0.0",
    enabled = true,
    commands = {
      { id = "clear_session", title = "Sessions: Clear Saved Session for Current Project", scope = "project" }
    },
    cmd = { "clear_session" },
    event = { "project_focus", "startup" }
  },
  {
    id = "git-integration",
    dir = "git-integration",
    lazy = true,
    category = "git",
    version = "1.0.0",
    enabled = true,
    commands = {
      { id = "view_commits", title = "Git: View Last Commits", scope = "project" },
      { id = "switch_branch", title = "Git: Switch Branch", scope = "project" }
    },
    cmd = { "view_commits", "switch_branch" }
  },
  {
    id = "git-enrichment",
    dir = "git-enrichment",
    lazy = true,
    category = "git",
    version = "1.0.0",
    enabled = true,
    commands = {
      { id = "pull", title = "Git: Pull Remote Changes", scope = "global" },
      { id = "show_settings", title = "Git Enrichment: Configure Settings", scope = "global" }
    },
    cmd = { "pull", "show_settings" }
  },
}
