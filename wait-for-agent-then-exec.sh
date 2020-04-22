#!/bin/bash

export PATH=""
unset PATH
export PATH
export PATH="/bin:/usr/bin"

source /etc/profile

export PATH

if [[ "$JAVA_TOOL_OPTIONS" == *"contrast"* ]]; then
    agent=`echo $JAVA_TOOL_OPTIONS | sed 's/.*-javaagent://' | awk '{print $1}'`
    until [ -f "$agent" ]; do
        echo Waiting for $agent
        sleep .5
    done
fi

echo PATH=$PATH
echo exec `basename $0` $*
exec `basename $0` $*
