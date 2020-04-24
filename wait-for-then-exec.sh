#!/bin/bash

timeout=1

export PATH=""
unset PATH
export PATH
export PATH="/bin:/usr/bin"

source /etc/profile

export PATH

# The fallback (error) connection testing script
wait_for() {
    echo 'NO TOOL TO TEST CONNECTION.  ABORTING.'
    exit 1
}

# Try to eplace the connection testing script with something that works
if which nc && [ -x `which nc` ]; then
    wait_for() {
        port="$1"
        host="$2"
        nc -z -w $timeout $host $port
    }
elif which node && [ -x `which node` ]; then
    wait_for() {
        port="$1"
        host="$2"

        node <<EOF
const net = require('net');

var client = new net.Socket();

process.exitCode=1;

client.connect($port, '$host', () => {
    console.log("Connected");
    process.exitCode=0;
    client.destroy();
});

client.on('close', () => {
    console.log(process.exitCode);
    process.exit()
});

setTimeout(() => {
console.log('Timed out');
client.destroy()
}, 10000);
EOF
    }
elif which python && [ -x `which python` ]; then
    wait_for() {
        port="$1"
        host="$2"

        python <<EOF
import socket as s
import sys
retcode=1
c = s.socket(s.AF_INET,s.SOCK_STREAM)
c.settimeout(1)
try:
    tgt=('$host',$port)
    c.connect(tgt)
    c.close()
    print('Connected')
    retcode=0
except:
    print('Timed out')
sys.exit(retcode)
EOF
    }
fi

#####################################################

echo "WAIT_FOR = $WAIT_FOR"

for target in $WAIT_FOR; do
    echo Waiting for \"$target\"
    case $target in
    contrast-agent*)
        echo $target | while IFS=":" read dummy language; do
            if [ "$language" == "java" ]; then
                if [[ "$JAVA_TOOL_OPTIONS" == *"contrast"* ]]; then
                    agent=`echo $JAVA_TOOL_OPTIONS | sed 's/.*-javaagent://' | awk '{print $1}'`
                    until [ -f "$agent" ]; do
                        echo Waiting for $agent
                        sleep .5
                    done
                fi
            else
                echo "UNSUPPORTED LANGUAGE $language; ABORTING"
                exit 1
            fi
        done
        ;;
    *)
        echo $target | while IFS=":" read host port; do
            until wait_for $port $host ; do
                echo Waiting for $host:$port to become available
                sleep .5
            done
        done
        ;;
    esac
done

if [ $? -eq 0 ]; then
    echo PATH=$PATH
    echo exec `basename $0` $*
    exec `basename $0` $*
fi