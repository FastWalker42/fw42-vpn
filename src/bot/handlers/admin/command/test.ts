import { BotContext } from '@/bot/types'

export default async function test(ctx: BotContext) {
	await ctx.reply('admin tested')
}
