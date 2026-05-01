import { Conversation } from '@grammyjs/conversations'

import { BotContext } from '@/bot/types'

export default async function topupBalance(conv: Conversation, ctx: BotContext) {
	ctx = (await conv.waitFor(':text')) as BotContext

	await ctx.reply('Баланс пополнен!')
}
