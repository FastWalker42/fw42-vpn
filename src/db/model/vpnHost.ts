import { InferSchemaType, model, Schema, Model } from 'mongoose'

const schema = new Schema({
	_id: { type: Number, required: true },

	ip: {
		type: String,
		required: true,
	},
	password: {
		type: String,
		required: true,
	},
})

schema.pre('save', function () {})
export default model<InferSchemaType<typeof schema>>('VpnHost', schema)
