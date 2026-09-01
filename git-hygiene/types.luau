--!strict

export type PluginLocales = {
	en: { [string]: string },
	de: { [string]: string },
}

export type PluginCommandContext = {
	projectId: string?,
	elementId: string?,
	pageId: string?,
	itemId: string?,
}

export type ProjectStatus = {
	id: string,
	name: string,
	path: string,
	branch: string,
	ahead: number,
	behind: number,
	isDirty: boolean,
	hasUpstream: boolean,
	scanned_at: number,
}

export type VaultProject = {
	id: string,
	name: string,
	path: string,
}

export type GitStatus = {
	branch: string,
	ahead: number,
	behind: number,
	isDirty: boolean,
	hasUpstream: boolean,
	version: string?,
}

export type TrackFlags = {
	dirty: boolean,
	unpushed: boolean,
	no_upstream: boolean,
	behind: boolean,
}

export type QuickPickItem = {
	id: string,
	label: string,
	detail: string?,
	icon: string?,
}

export type ScanResult = {
	projects: { ProjectStatus },
	errors: { { id: string, name: string, message: string } },
}

return {}
