#!/bin/sh -x

# Usage: grab-latest-from-teamserver.sh <language> <destination_path>

language="$1"
dest="$2"

# Requires the following variables to be set in the environment, typically
# via Docker build arguments: URL, API_KEY, ORG_ID, AUTH_HDR

if [ -z "$URL" -o -z "$API_KEY" -o -z "$ORG_ID" -o -z "$AUTH_HDR" ]; then
    echo "Environment must include URL, API_KEY, ORG_ID, and AUTH_HDR!  Aborting"
    echo "Values, respectively: $URL, $API_KEY, $ORG_ID, and $AUTH_HDR"
    exit 1
fi

#echo URL $URL
echo API_KEY $API_KEY
echo ORG_ID $ORG_ID
echo AUTH_HDR $AUTH_HDR

# Strip trailing slashes on URL
URL=`echo $URL | sed 's|/*$||'`

# Convert language to uppercase
language=`echo $language | tr '[:lower:]' '[:upper:]'`

echo URL $URL
echo language $LANGUAGE

curl -X GET -o "$dest" "$URL/api/ng/$ORG_ID/agents/default/$language" -H "Authorization: $AUTH_HDR" -H "API-Key: $API_KEY" -H 'Accept: application/json' -OJ
