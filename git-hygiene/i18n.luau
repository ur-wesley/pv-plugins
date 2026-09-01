--!strict

local types = (require :: any)("./types")
type PluginLocales = types.PluginLocales

local function create(locales: PluginLocales)
	local function translate(locale: string, key: string, args: { [string]: any }?): string
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
