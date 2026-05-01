import { BotContext } from '@/bot/types'
import { InlineKeyboard } from 'grammy'

export default async function admin(ctx: BotContext) {
	await ctx.reply('admika', { reply_markup: new InlineKeyboard().text('add server', 'add_server') })
}
