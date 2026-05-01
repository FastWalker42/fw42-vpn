import { InferSchemaType, model, Schema } from 'mongoose'

const schema = new Schema({
	id: { type: Number, required: true },
	role: {
		type: String,
		default: 'none',
		enum: ['none', 'admin'],
	},
	balance: {
		type: Number,
		default: 0,
	},
})

export default model<InferSchemaType<typeof schema>>('User', schema)
