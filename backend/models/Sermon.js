const mongoose = require('mongoose');

const sermonPointSchema = new mongoose.Schema(
  {
    title: String,
    development: String,
    supportingVerses: [String],
  },
  { _id: false }
);

const sermonSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    basePassage: {
      type: String,
      trim: true,
      default: '',
    },
    language: {
      type: String,
      enum: ['pt', 'en'],
      default: 'pt',
    },
    inputPrompt: {
      type: String,
      trim: true,
      default: '',
    },
    content: {
      introduction: { type: String, default: '' },
      points: { type: [sermonPointSchema], default: [] },
      illustrations: { type: [String], default: [] },
      conclusion: { type: String, default: '' },
      closingPrayer: { type: String, default: '' },
    },
  },
  { timestamps: true }
);

// Index for text search on title
sermonSchema.index({ title: 'text', basePassage: 'text' });

module.exports = mongoose.model('Sermon', sermonSchema);
