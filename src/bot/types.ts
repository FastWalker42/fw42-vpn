import { ConversationFlavor } from '@grammyjs/conversations'
import { Context, Bot } from 'grammy'

export type BotContext = ConversationFlavor<Context>

export type BotType = Bot<BotContext>
