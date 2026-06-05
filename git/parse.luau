--!strict

export type GitCommit = {
	hash: string,
	author: string,
	email: string,
	subject: string,
	date: string,
	relativeDate: string,
}

export type GitStatus = {
	branch: string,
	ahead: number,
	behind: number,
	isDirty: boolean,
	hasUpstream: boolean,
	version: string?,
}

local function status(raw: string): GitStatus?
	local ok, parsed = pcall(function()
		return vault.json.parse(raw)
	end)
	if ok and type(parsed) == "table" then
		return parsed :: GitStatus
	end
	return nil
end

local function commits(raw: string): { GitCommit }?
	local ok, parsed = pcall(function()
		return vault.json.parse(raw)
	end)
	if ok and type(parsed) == "table" then
		return parsed :: { GitCommit }
	end
	return nil
end

return {
	status = status,
	commits = commits,
}
