import { Conversation } from '@grammyjs/conversations'
import { Context } from 'grammy'
import { Client } from 'ssh2'

const SCRIPT_URL = 'https://raw.githubusercontent.com/youruser/yourrepo/main/deploy.sh'

export default async function add_server(conv: Conversation, ctx: Context) {
	await ctx.reply('enter ip:')
	const ipmsg = await conv.waitFor(':text')
	const ip = ipmsg.msg.text.trim()

	await ctx.reply('enter pass:')
	const passmsg = await conv.waitFor(':text')
	const password = passmsg.msg.text.trim()

	// опционально удаляем сообщение с паролем из чата
	try {
		await ctx.api.deleteMessage(passmsg.msg.chat.id, passmsg.msg.message_id)
	} catch {}

	await ctx.reply('deploying node...')

	try {
		const output = await conv.external(() => runRemoteScript(ip, 'root', password, SCRIPT_URL))
		// телеграм режет сообщения длиннее 4096 символов
		const tail = output.slice(-3500)
		await ctx.reply(`✅ done\n\n<pre>${escapeHtml(tail)}</pre>`, {
			parse_mode: 'HTML',
		})
	} catch (e) {
		const err = e instanceof Error ? e.message : String(e)
		await ctx.reply(`❌ failed: ${escapeHtml(err)}`)
	}
}

function runRemoteScript(host: string, username: string, password: string, scriptUrl: string): Promise<string> {
	return new Promise((resolve, reject) => {
		const conn = new Client()
		// curl грузит скрипт прямо на удалённой машине и пайпит в bash.
		// set -e чтобы любой провалившийся шаг ронял всю установку.
		const cmd = `set -e; curl -fsSL ${JSON.stringify(scriptUrl)} | bash -s`

		let stdout = ''
		let stderr = ''

		conn.on('ready', () => {
			conn.exec(cmd, { pty: true }, (err, stream) => {
				if (err) {
					conn.end()
					return reject(err)
				}
				stream
					.on('close', (code: number) => {
						conn.end()
						if (code === 0) resolve(stdout || stderr)
						else reject(new Error(`exit ${code}\n${stderr || stdout}`))
					})
					.on('data', (d: Buffer) => {
						stdout += d.toString()
					})
				stream.stderr.on('data', (d: Buffer) => {
					stderr += d.toString()
				})
			})
		})

		conn.on('error', reject)

		conn.connect({
			host,
			port: 22,
			username,
			password,
			readyTimeout: 20_000,
		})
	})
}

function escapeHtml(s: string) {
	return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}
