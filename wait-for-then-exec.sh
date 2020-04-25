#!/bin/bash

args=( "$@" )

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

create_contrast_flask() {
    dest="$1"
    cat <<EOF > "$dest"
import sys
import os.path

this = sys.modules[__name__]

print('Loading Contrast Flask shim')

orig_path = list(sys.path)

# Pop off ourself
while sys.path[0] == os.path.dirname("$dest"):
    sys.path.pop(0)

while sys.path[0] == '':
    sys.path.pop(0)

if 'flask' in sys.modules:
    del sys.modules['flask']

from flask import *
from flask import Flask as _original_Flask

if 'flask' in sys.modules:
    del sys.modules['flask']

print('Real flask module ', sys.modules[_original_Flask.__module__].__file__)

sys.path = orig_path

sys.modules[__name__] = this

from contrast.agent.middlewares.flask_middleware import FlaskMiddleware as ContrastMiddleware

print('Reverted path to', sys.path)

#class Flask(_original_Flask):
#    def __init__(self, *args, **kw):
#        print('Instantiating Contrast-enabled Flask object')
#        ret = super(Flask,self).__init__(*args, **kw)
#        ret.wsgi_app = ContrastMiddleware(ret)
def Flask(*args, **kw):
    print('Instantiating Contrast-enabled Flask object')
    ret = _original_Flask(*args, **kw)
    ret.wsgi_app = ContrastMiddleware(ret)
    return ret

#print('Flask: ', sys.modules[Flask.__module__].__file__)
EOF
}

#####################################################

echo "WAIT_FOR = $WAIT_FOR"

for target in $WAIT_FOR; do
    echo Waiting for \"$target\"
    case $target in
    contrast-agent*)
        language=`echo $target | awk 'BEGIN { FS=":" } {print $2}'`
        if [ ! -b /dev/console ]; then
            ln -s /proc/1/fd/1 /dev/console
        fi
            case $language in
            java)
                if [[ "$JAVA_TOOL_OPTIONS" == *"contrast"* ]]; then
                    agent=`echo $JAVA_TOOL_OPTIONS | sed 's/.*-javaagent://' | awk '{print $1}'`
                    until [ -f "$agent" ]; do
                        echo Waiting for $agent
                        sleep .5
                    done
                fi
                ;;
            node)
                agent=/agents/node/node-contrast.tgz
                until [ -f "$agent" ]; do
                    echo Waiting for $agent
                    sleep .5
                done
                npm install $agent --no-save
                if [ `basename $0` == "node" ]; then
                    script=${args[0]}
                    #args=( "./node_modules/node_contrast" "$script" --agent.logger.path /app/contrast.log --agent.logger.level DEBUG --agent.service.logger.path /app/contrast-service.log --agent.service.logger.level DEBUG "${args[@]:1}" )
                    args=( "./node_modules/node_contrast" "$script" "${args[@]:1}" )
                    echo ARGS updated to "${args[@]}"
                else
                    echo UNSUPPORTED NODE RUNNER `basename $0` "${args[@]}"
                    exit 1
                fi
                ;;
            python)
                agent=/agents/python/contrast-python-agent.tar.gz
                until [ -f "$agent" ]; do
                    echo Waiting for $agent
                    sleep .5
                done
                pip install $agent
                if grep -q Flask "${args[0]}"; then
                    export PYTHONPATH="/app $PYTHONPATH"
                    create_contrast_flask /app/flask.py
                else
                    echo UNSUPPORTED PYTHON FRAMEWORK "${args[@]}"
                    exit 1
                fi
                ;;
            *)
                echo "UNSUPPORTED LANGUAGE $language; ABORTING"
                exit 1
                ;;
            esac
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
    echo exec `basename $0` "${args[@]}"
    exec `basename $0` "${args[@]}"
fi