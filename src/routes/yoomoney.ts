import Bun from 'bun'
import { createHash } from 'node:crypto'

export default {
	'/yoomoney': async (req) => {
		if (req.method !== 'POST') {
			return new Response('OK')
		}

		const rawInput = await req.text()
		const postData = Object.fromEntries(new URLSearchParams(rawInput))

		console.log(
			[
				'=== НОВЫЙ POST ЗАПРОС ОТ ЮMONEY ===',
				`IP: ${req.headers.get('x-forwarded-for')}`,
				`Content-Type: ${req.headers.get('content-type') ?? '—'}`,
				`Raw Body Length: ${rawInput.length} байт`,
				'',
				'=== RAW BODY ===',
				rawInput,
				'',
				'=== PARSED POST DATA ===',
				JSON.stringify(postData, null, 2),
				'=== КОНЕЦ ЗАПРОСА ===',
				'',
			].join('\n'),
		)

		if (!postData.notification_type || !postData.operation_id) {
			console.log('Получен POST, но это НЕ уведомление ЮMoney (нет notification_type или operation_id)')
			return new Response('OK')
		}

		const nt = postData.notification_type
		const op_id = postData.operation_id
		const amount = postData.amount ?? '0'
		const dt = postData.datetime ?? ''
		const sender = postData.sender ?? ''
		const label = postData.label ?? ''
		const codepro = postData.codepro === 'true'
		const test = postData.test_notification === 'true'
		const currency = postData.currency ?? '643'

		const isTestNotification = op_id === 'test-notification'

		let hashValid = false

		if (isTestNotification && postData.sign) {
			hashValid = true
		} else if (postData.sha1_hash) {
			const hashString = [
				nt,
				op_id,
				amount,
				currency,
				dt,
				sender,
				codepro ? 'true' : 'false',
				Bun.env.YOOMONEY_SECRET,
				label,
			].join('&')
			const calculated = createHash('sha1').update(hashString).digest('hex')
			hashValid = calculated === postData.sha1_hash
		}

		// ── Формирование сообщения ─────────────────────────────────────────────
		const emoji = test || isTestNotification ? '🧪' : '💰'
		const typeName = nt === 'p2p-incoming' ? 'Перевод из кошелька' : 'Пополнение с карты'

		const lines = [
			`*${emoji} Уведомление ЮMoney ${emoji}*`,
			'',
			`*Тип:* ${typeName}`,
			`*Operation ID:* \`${op_id}\``,
			`*Сумма:* \`${amount} ₽\``,
			`*Дата:* ${dt}`,
		]
		if (sender) lines.push(`*Отправитель:* \`${sender}\``)
		if (label) lines.push(`*Метка:* \`${label}\``)
		if (test || isTestNotification) lines.push('', '🧪 *Это тестовое уведомление*')

		lines.push(`\n🔐 Проверка подписи: ${hashValid ? '✅ OK' : '❌ Не проверена / ошибка'}`)
		if (!hashValid && !isTestNotification) lines.push('⚠️ Хэш не совпадает!')

		console.log(
			`Уведомление ЮMoney обработано | Operation ID: ${op_id} | Тест: ${test || isTestNotification ? 'ДА' : 'нет'}`,
		)

		return new Response('OK')
	},
} as Record<string, (req: Bun.BunRequest) => Response | Promise<Response>>
