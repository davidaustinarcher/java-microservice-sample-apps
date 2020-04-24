const mongoose = require('mongoose')

const favoriteSchema = new mongoose.Schema({
  user: {
    type: String,
    required: true
  },
  title: {
    type: String,
    required: true
  },
  addDate: {
    type: Date,
    required: true,
    default: Date.now
  }
})

module.exports = mongoose.model('Favorite', favoriteSchema)