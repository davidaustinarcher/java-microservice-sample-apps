#!/bin/sh

# Name of the Contrast artifact 
name="contrast-agent"

# Search maven repo for the latest Contrast artifact
# Output goes to stdout, to be used by caller
_find_latest_maven_artifact() {
    curl -o agents.json "https://search.maven.org/solrsearch/select?q=$name&rows=1&wt=json"
    jq '.response.docs[0] | .id, .latestVersion' agents.json | sed s/\"//g
    rm agents.json
}

# Read stdin to assemble a download URL for the Contrast agent from Maven
# Output goes to stdout, to be used by caller
#
# Input format:
# <skip first line>
# artifact name
# version

_get_maven_url() {
    read
    read artifact
    read version

    # Convert '.' and ':' to '/'
    path=`echo $artifact | sed 's-\.-/-g' | sed s-\:-/-g`

    echo "https://search.maven.org/remotecontent?filepath=$path/$version/$name-$version.jar"
}

# Grab the latest Contrast agent and store at the path specified in $1
get_latest_agent_from_maven() {
    url=`_find_latest_maven_artifact | _get_maven_url`
    echo Downloading latest Java agent from $url
    curl -L -o "$1" "$url"
} 


# Where to store the downloaded agent
dest="contrast.jar"
if [ -n "$1" ]; then
    dest="$1"
fi

get_latest_agent_from_maven "$dest"
