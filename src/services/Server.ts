import Bun from 'bun'

import yoomoney from '@/routes/yoomoney'

import { Update } from '@grammyjs/conversations/out/deps.node'
import createBot from '@/bot'
import { BotType } from '@/bot/types'

import '@/db'

//import cryptobot from '@/routes/cryptobot'

const BOTS_CACHE: Map<string, BotType> = new Map()

const server = Bun.serve({
	hostname: '127.0.0.1',
	port: Bun.env.PORT || 3000,

	routes: {
		'/api/test': async (req) => Response.json({ ok: true }, { status: 200 }),

		/*/...cryptobot,*/

		'/webhook/:token': async (req: Bun.BunRequest) => {
			const { token } = req.params
			let bot = BOTS_CACHE.get(token)
			if (!bot) {
				bot = await createBot(token)
				BOTS_CACHE.set(token, bot)
			}
			await bot.handleUpdate((await req.json()) as Update)
			return Response.json({ ok: true })
		},
		...yoomoney,

		'/*': (req) => {
			const path = new URL(req.url).pathname
			if (!path.includes('.')) {
				return new Response(Bun.file('./app/index.html'), {
					headers: { 'Content-Type': 'text/html' },
				})
			}
			const file = Bun.file('./app' + path)
			if (file.size === 0) return new Response('Not Found', { status: 404 })
			return new Response(file)
		},
	},
})

console.log(`Запущен на http://localhost:${server.port}`)
