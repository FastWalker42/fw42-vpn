export function SafeParse(o: any) {
	return JSON.parse(JSON.stringify(o))
}

export function NormalizedChatLink(input: string): string {
	input = input.trim()

	// ссылка
	if (input.includes('t.me/')) {
		const parts = input.split('t.me/')[1]
		input = parts.split('?')[0]
	}

	// убрать @
	if (input.startsWith('@')) {
		input = input.slice(1)
	}

	return input.toLowerCase()
}
