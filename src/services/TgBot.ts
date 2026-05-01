import Bun from 'bun'
import createBot from '@/bot'
import '@/db'

createBot(Bun.env.BOT_TOKEN || '').then((b) =>
	b.start({
		drop_pending_updates: true,
		onStart: () => console.log('started'),
	}),
)
