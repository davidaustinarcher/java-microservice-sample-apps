#!/bin/sh

curl http://localhost:8000/health

curl http://localhost:8000/list

# Identifies XXE
curl -H 'Content-type: application/xml' http://localhost:8000/add -d '<book><title>The Giving Tree</title><pages>30</pages></book>'
curl -H 'Content-type: application/xml' http://localhost:8000/add -d '<book><title>Shooting Stars</title><pages>48</pages></book>'

# Identifies SSRF
curl http://localhost:8000/debug

# Identifies deserialization

rm -f Dune.ser
curl -o Dune.ser 'http://localhost:8001/dump?title=Dune'
curl -X POST -H 'Content-type: application/octet-stream' --data-binary @Dune.ser http://localhost:8001/update
rm Dune.ser


curl -X POST -H "Content-Type: application/xml" http://localhost:8000/favorites/add -d '<favorite><title>Billychuck</title><user>Jon</user></favorite>'
curl -X POST -H "Content-Type: application/xml" http://localhost:8000/reviews/add -d '<review><user>Jon</user><title>Billychuck</title><score>5.0</score><comments>My new favorite!</comments></review>'

curl http://localhost:8000/favorites
curl http://localhost:8000/reviews
curl 'http://localhost:8000/favorites?user=Jon'
curl 'http://localhost:8000/reviews?user=Jon'

