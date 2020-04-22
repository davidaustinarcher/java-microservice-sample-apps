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
