import mongoose from 'mongoose'

import User from './user'
import VpnHost from './VpnHost'

mongoose
	.connect('mongodb://localhost:27017/tgspamer')
	.then(() => console.log('mongodb connected!'))
	.catch((e) => console.error(e))

export { User, VpnHost }
