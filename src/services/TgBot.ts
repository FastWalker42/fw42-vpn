import createBot from '@/bot'
import '@/db'

import CONFIG from '../../CONFIG.json'

createBot(CONFIG.BOT_TOKEN).then((b) =>
	b.start({
		drop_pending_updates: true,
		onStart: () => console.log('started'),
	}),
)
