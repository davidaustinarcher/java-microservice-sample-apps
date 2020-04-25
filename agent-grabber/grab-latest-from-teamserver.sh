#!/bin/sh -x

language="$1"
dest="$2"

#CF="contrast_security-user.yaml"
#
#get() {
#    grep $field $CF | sed "s/^.*$field://"
#}

#URL=`get url`
#API_KEY=`get api_key`
#ORG_ID=`get org_id`
#SERVICE_KEY=`get service_key`
#AUTH_HDR=`get auth_hdr`

echo URL $URL
echo API_KEY $API_KEY
echo ORG_ID $ORG_ID
echo SERVICE_KEY $SERVICE_KEY
echo AUTH_HDR $AUTH_HDR

URL=`echo $URL | sed 's|/*$||'`
language=`echo $language | tr '[:lower:]' '[:upper:]'`

echo URL $URL
echo language $LANGUAGE

curl -X GET -o "$dest" "$URL/api/ng/$ORG_ID/agents/default/$language" -H "Authorization: $AUTH_HDR" -H "API-Key: $API_KEY" -H 'Accept: application/json' -OJ
