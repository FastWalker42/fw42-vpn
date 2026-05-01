module.exports = {
	apps: [
		{
			name: 'tgbot',
			interpreter: 'bun',
			script: 'src/services/TgBot.ts',
			autorestart: true,
			max_memory_restart: '1G',
			watch: ['src/common', 'src/bot', 'src/services/TgBot.ts'],
		},
		{
			name: 'server',
			interpreter: 'bun',
			script: 'src/services/Server.ts',
			autorestart: true,
			max_memory_restart: '1G',
			watch: ['src/common', 'src/services/Server.ts'],
		},
	],
}
