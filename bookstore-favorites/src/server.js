require('dotenv').config()

const express = require('express')
const app = express()
const mongoose = require('mongoose')
const Favorite = require('./models/favorite')

const db_url = process.env.DATABASE_URL || "mongodb://bookstore-mongodb:27017/favorites"

const initialData = [
    { user: "Bob", title: "Dune" },
    { user: "Alice", title: "The Stars My Destination" }
];

mongoose.connect(db_url, { useNewUrlParser: true })
const db = mongoose.connection
db.on('error', (error) => console.error(error))
db.once('open', () => {
    console.log('connected to database')
    Favorite.estimatedDocumentCount().then( count => {
        console.log(count," records found");
        if (count == 0) {
            for (d of initialData) {
                const rec = new Favorite(d);
                console.log("Adding", rec);
                rec.save(err => { if (err) return console.error(err); });
            }    
        }
    });
});

app.use(express.json())

const favoritesRouter = require('./routes/favorites')
app.route('/ping').get( (req,res) => res.send('') )
app.use('/favorites', favoritesRouter)

app.listen(3000, () => console.log('server started'))