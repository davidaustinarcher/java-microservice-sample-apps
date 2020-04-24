const express = require('express')
const router = express.Router()
const Favorite = require('../models/favorite')

// Getting all favorites
router.get('/', async (req, res) => {
  try {
    console.log("Getting favorites for", req.query);
    const favorites = await Favorite.find(req.query)
    res.json(favorites)
  } catch (err) {
    res.status(500).json({ message: err.message })
  }
})

// Creating one favorite
router.post('/', async (req, res) => {
  const favorite = new Favorite({
    user: req.body.user,
    title: req.body.title
  })

  try {
    const newFavorite = await favorite.save()
    res.status(201).json(newFavorite)
  } catch (err) {
    res.status(400).json({ message: err.message })
  }
})

// Getting one favorite
router.get('/:id', getFavorite, (req, res) => {
  res.json(res.favorite)
})

// Deleting one favorite
router.delete('/:id', getFavorite, async (req, res) => {
  try {
    await res.favorite.remove()
    res.json({ message: 'Deleted This Favorite' })
  } catch(err) {
    res.status(500).json({ message: err.message })
  }
})

// Middleware function for getting favorite object by ID
async function getFavorite(req, res, next) {
  try {
    favorite = await Favorite.findById(req.params.id)
    if (favorite == null) {
      return res.status(404).json({ message: 'Cant find favorite'})
    }
  } catch(err){
    return res.status(500).json({ message: err.message })
  }
  
  res.favorite = favorite
  next()
}

module.exports = router 