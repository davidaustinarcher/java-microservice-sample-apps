#!/bin/sh

start() {
    echo ''
    echo ''
    echo ''
    echo '====================================================='
    echo "    STARTING $1"
    echo '====================================================='
}

start "Health Check"
curl http://localhost:8000/health

start "List of Books"
curl http://localhost:8000/list

# Identifies XXE
start "Adding Books"
curl -H 'Content-type: application/xml' http://localhost:8000/add -d '<book><title>The Giving Tree</title><pages>30</pages></book>'
curl -H 'Content-type: application/xml' http://localhost:8000/add -d '<book><title>Shooting Stars</title><pages>48</pages></book>'

# Identifies SSRF
start "Testing debug service"
curl http://localhost:8000/debug

# Identifies deserialization
start "Dumping Book"
rm -f Dune.ser
curl -o Dune.ser 'http://localhost:8001/dump?title=Dune'
start "Updating Book"
curl -X POST -H 'Content-type: application/octet-stream' --data-binary @Dune.ser http://localhost:8001/update
rm Dune.ser


start "Adding Favorite"
curl -X POST -H "Content-Type: application/xml" http://localhost:8000/favorites/add -d '<favorite><title>Billychuck</title><user>Jon</user></favorite>'
start "Adding Review"
curl -X POST -H "Content-Type: application/xml" http://localhost:8000/reviews/add -d '<review><user>Jon</user><title>Billychuck</title><score>5.0</score><comments>My new favorite!</comments></review>'

start "Listing Favorites"
curl http://localhost:8000/favorites
start "Listing Reviews"
curl http://localhost:8000/reviews
start "Listing Jon's Favorites"
curl 'http://localhost:8000/favorites?user=Jon'
start "Listing Jons' Reviews"
curl 'http://localhost:8000/reviews?user=Jon'

