import { Bot } from 'grammy'
import { BotContext } from './types'

import { conversations, createConversation } from '@grammyjs/conversations'
import adminMiddleware from './middleware/admin'

async function createBot(token: string) {
	const bot = new Bot<BotContext>(token)
	bot.use(conversations())

	const baseDir = import.meta.dir

	for await (const file of new Bun.Glob('**/handlers/**/*.ts').scan({ cwd: baseDir })) {
		console.log(file)
		const mod = await import(`${baseDir}/${file}`)

		const isAdmin = file.includes('admin')

		let handlers = isAdmin ? [adminMiddleware, mod.default] : [mod.default]

		const cbPattern = new RegExp(`^${mod.default.name}`)

		if (file.includes('command')) {
			bot.command(mod.default.name, ...handlers)
			bot.callbackQuery(cbPattern, ...handlers)
		} else if (file.includes('callbackQuery')) {
			bot.callbackQuery(cbPattern, ...handlers)
		} else if (file.includes('conversation')) {
			// ЕСЛИ У НАС КОНВЕРСА ТО МЕНЯЕМ ХЕНДЛЕРЫ
			const callbackH = async (ctx: BotContext) => await ctx.conversation.enter(mod.default.name)
			handlers = isAdmin ? [adminMiddleware, callbackH] : [callbackH]

			bot.use(createConversation(mod.default))
			bot.callbackQuery(cbPattern, ...handlers)
		}
	}

	bot.catch((err: any) => {
		console.error('Unhandled error:', err)
	})

	return bot
}

export default createBot
