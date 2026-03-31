const mongoose = require('mongoose');

const aiUsageSchema = new mongoose.Schema(
  {
    subjectType: {
      type: String,
      enum: ['user', 'device'],
      required: true,
    },
    subjectId: {
      type: String,
      required: true,
      index: true,
    },
    feature: {
      type: String,
      required: true,
      index: true,
    },
    periodType: {
      type: String,
      enum: ['day', 'week', 'month'],
      required: true,
    },
    periodStart: {
      type: Date,
      required: true,
    },
    count: {
      type: Number,
      default: 0,
    },
  },
  { timestamps: true }
);

aiUsageSchema.index(
  { subjectType: 1, subjectId: 1, feature: 1 },
  { unique: true }
);

module.exports = mongoose.model('AiUsage', aiUsageSchema);
