--!strict

type PluginLocales = {
	en: { [string]: string },
	de: { [string]: string },
}

local function create(locales: PluginLocales)
	local function translate(locale: string, key: string, args: { [string]: string }?): string
		local dict: { [string]: string } = if locale == "de" then locales.de else locales.en
		local str = dict[key] or key
		if args then
			for k, v in pairs(args) do
				str = str:gsub("{" .. k .. "}", tostring(v))
			end
		end
		return str
	end

	return {
		t = translate,
	}
end

return {
	create = create,
}
