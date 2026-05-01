import { User } from '@/db'
import { BotContext } from '../types'
import { NextFunction } from 'grammy'

export default async function adminMiddleware(ctx: BotContext, next: NextFunction) {
	console.log('admin check')
	const { id } = ctx.from!
	const user = await User.findOne({ id })
	console.log(user)
	if (user?.role === 'admin') {
		await next()
	}
}
