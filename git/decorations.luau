--!strict

local function for_elements(project_id: string, tab_id: string, element_ids: { string })
	local decs = {}

	if tab_id == "files" then
		if vault.settings.get("decorate_files") == "false" then
			return decs
		end

		local res = vault.git.run(project_id, { "status", "--porcelain" })
		if not res.success then
			return decs
		end

		local status_map = {}
		for line in res.stdout:gmatch("[^\r\n]+") do
			if #line >= 4 then
				local code = line:sub(1, 2)
				local file_path = line:sub(4)
				if file_path:sub(1, 1) == '"' and file_path:sub(-1) == '"' then
					file_path = file_path:sub(2, -2)
				end

				local icon, color, label, tooltip
				if code == " M" or code == "M " then
					icon = "mdi--pencil"
					color = "#eab308"
					label = "M"
					tooltip = "Modified file"
				elseif code == "??" then
					icon = "mdi--plus"
					color = "#22c55e"
					label = "U"
					tooltip = "Untracked file"
				elseif code == " A" or code == "A " then
					icon = "mdi--plus"
					color = "#22c55e"
					label = "A"
					tooltip = "Added to index"
				end

				if label then
					status_map[file_path] = {
						before = {
							{
								icon = icon,
								color = color,
								tooltip = tooltip,
							},
						},
						after = {
							{
								label = label,
								color = color == "#eab308" and "bg-yellow-500/10 text-yellow-600 border-yellow-500/25"
									or "bg-green-500/10 text-green-600 border-green-500/25",
								tooltip = tooltip,
							},
						},
					}
				end
			end
		end

		for _, el_id in ipairs(element_ids) do
			if status_map[el_id] then
				decs[el_id] = status_map[el_id]
			end
		end
	elseif tab_id == "tasks" then
		for _, el_id in ipairs(element_ids) do
			local lower_id = el_id:lower()
			if lower_id:find("git") or lower_id:find("pull") or lower_id:find("push") or lower_id:find("sync") then
				decs[el_id] = {
					before = {
						{
							icon = "mdi--git",
							color = "#f05032",
							tooltip = "Executes a Git-related command",
						},
					},
				}
			end
		end
	end

	return decs
end

return {
	for_elements = for_elements,
}
