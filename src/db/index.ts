import mongoose from 'mongoose'

mongoose
	.connect('mongodb://127.0.0.1:27017/vpnbot')
	.then(() => console.log('MongoDB connected'))
	.catch((error) => console.error('MongoDB connection error:', error))

import User from '@/db/model/user'
//import TgBot from '@/db/model/Tgbot'

/* Инициализируем Global singleton при старте
Global.findOneAndUpdate({ id: 'singleton' }, {}, { upsert: true, new: true })
	.then(() => console.log('Global settings initialized'))
	.catch(console.error)*/

export { User }
