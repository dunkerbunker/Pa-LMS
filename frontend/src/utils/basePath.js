export function getLmsBasePath() {
	const configuredPath = window.lms_path || 'lms'
	return `/${configuredPath.replace(/^\/+|\/+$/g, '')}/`
}

export function getLmsRoute(path = '') {
	const base = getLmsBasePath().replace(/^\/+|\/+$/g, '')
	if (!path) {
		return `/${base}`
	}
	const normalized = path.startsWith('/') ? path.slice(1) : path
	return `/${base}/${normalized}`
}
