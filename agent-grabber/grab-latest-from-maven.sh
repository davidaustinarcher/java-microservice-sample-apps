#!/bin/sh

name="contrast-agent"

_find_latest_maven_artifact() {
    curl -o agents.json "https://search.maven.org/solrsearch/select?q=$name&rows=1&wt=json"
    jq '.response.docs[0] | .id, .latestVersion' agents.json | sed s/\"//g
    rm agents.json
}

_get_maven_url() {
    read
    read artifact
    read version

    path=`echo $artifact | sed 's-\.-/-g' | sed s-\:-/-g`

    echo "https://search.maven.org/remotecontent?filepath=$path/$version/$name-$version.jar"
}

get_latest_agent_from_maven() {
    url=`_find_latest_maven_artifact | _get_maven_url`
    echo Downloading latest Java agent from $url
    curl -L -o "$1" "$url"
} 

dest="contrast.jar"

if [ -n "$1" ]; then
    dest="$1"
fi
get_latest_agent_from_maven "$dest"
