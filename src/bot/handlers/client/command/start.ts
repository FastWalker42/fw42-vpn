import { InlineKeyboard } from 'grammy'
import { BotContext } from '@/bot/types'
import { User } from '@/db/model'

export default async function start(ctx: BotContext) {
	const user = await User.findOneAndUpdate({ id: ctx.from!.id }, {}, { upsert: true, returnDocument: 'before' })
	if (!user) {
		await ctx.reply('Впервые!')
	}
	const kb = new InlineKeyboard()

	const text = 'hi'
	const props = { reply_markup: kb }
	ctx.callbackQuery ? await ctx.editMessageText(text, props) : await ctx.reply(text, props)
}
