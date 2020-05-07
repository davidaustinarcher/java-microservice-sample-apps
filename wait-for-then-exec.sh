#!/bin/bash

#####################################################################
#
# wait-for-then-exec.sh
#
# We usually inject this script on the path before the normal container
# entrypoint, so that the container starts with this script and this script
# waits for an appropriate state before running the real container entrypoint.
#
# An appropriate state generally means that certain external resources are
# available.  For example, ensuring that the Contrast agent for a specific
# language is available and operational, or ensuring that a certain network
# endpoint is available.
#
# Using this script usually requires a few extra lines in your
# docker-compose.yml for the service that will wait for another service.
# Assume that the container entrypoint or cmd indicates that prog should be
# run, and the workdir is /app.  The entrypoint/cmd must use a relative
# path to prog, not an absolute path.  If the Dockerfile specifies an
# absolute path, you will need to modify the Dockerfile in order to use this
# script.
#
# We are effectively tricking the container into running this script instead
# of the expected entrypoint/cmd.  This script will ensure the necessary
# services are available before launching the expected entrypoint/cmd.  It
# uses some PATH trickery to accomplish this.
#
# <service>:
#  volumes:
#    - "wait-for-then-exec.sh:/app/prog"
#  environment:
#    - "PATH=/app" (append other directories as needed)
#    - "WAIT_FOR=spec spec spec"
#      (where spec is arbitrary list of host:port or contrast-agent:language)
#
# The volume entry places this script at /app/prog
# The PATH entry ensures this script will be run when the container starts,
#     rather than the expected executable.
# The WAIT_FOR entry tells this script what to wait for
# Other variables, including the tunables below, may of course be added



# Retain the original command line to exec later

args=( "$@" )

# Tunables in the environment (all optional)
#
# CONNECT_TIMEOUT: timeout for individual connect attempts
# WAIT_PERIOD: amount of time to sleep before reattempting connection
# LOG_TARGET: path to which the agent will send log output.  We will try to symlink to the container's shared stdout.
# AGENT: absolute path to the necessary agent file

timeout=${CONNECT_TIMEOUT:-1}
wait_between_checks=${WAIT_PERIOD:-.5}
log_target=${LOG_TARGET:/dev/console}

# Restoring the normal PATH.
export PATH=""
unset PATH
export PATH
export PATH="/bin:/usr/bin"

source /etc/profile

export PATH


#########################
# The wait_for function is used to verify a network connection to the
# relevant target, using whatever available tool we know how to use.
#
# TODO: consider packaging a standlone tool for this

# Start with a script that errors out, meaning that we don't know how to
# test for a connection.
wait_for() {
    echo 'NO TOOL TO TEST CONNECTION.  ABORTING.'
    exit 1
}

# Try to replace the connection testing script with something that works
if which nc && [ -x `which nc` ]; then
    # Use netcat or nc
    wait_for() {
        port="$1"
        host="$2"
        nc -z -w $timeout $host $port
    }
elif which node && [ -x `which node` ]; then
    # Use a small node script
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
}, $timeout*1000);
EOF
    }
elif which python && [ -x `which python` ]; then
    # Use a small python script
    wait_for() {
        port="$1"
        host="$2"

        python <<EOF
import socket as s
import sys
retcode=1
c = s.socket(s.AF_INET,s.SOCK_STREAM)
c.settimeout($timeout)
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


#------------
# create_contrast_flask creates a small Python app that uses trickery similar
# to this script in order to automatically add the Contrast middleware to
# a Flask app

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

# Load the normal flask module so we can tie back to it

from flask import *
from flask import Flask as _original_Flask

if 'flask' in sys.modules:
    del sys.modules['flask']

print('Real flask module ', sys.modules[_original_Flask.__module__].__file__)

# Restore the original path and put this module back on the modules list
sys.path = orig_path

sys.modules[__name__] = this

from contrast.agent.middlewares.flask_middleware import FlaskMiddleware as ContrastMiddleware

print('Reverted path to', sys.path)

# When a user instantiates a Flask object, we'll return an object that has
# the Contrast middleware added
def Flask(*args, **kw):
    print('Instantiating Contrast-enabled Flask object')
    ret = _original_Flask(*args, **kw)
    ret.wsgi_app = ContrastMiddleware(ret)
    return ret
EOF
}

#####################################################

echo "Need to wait for $WAIT_FOR"

for target in $WAIT_FOR; do
    echo Waiting for \"$target\"
    case $target in

    #------------
    # Wait for the specified Contrast agent to be available
    contrast-agent*)

        # Create a special link to the container's stdout.  Single-executable
        # containers can use /dev/stdout, but the Contrast Service runs in
        # a separate process which has a different stdout.  $LOG_TARGET
        # provides a way to send that output to the main stdout of the
        # container.
        if [ ! -e $LOG_TARGET ]; then
            ln -s /proc/1/fd/1 $LOG_TARGET
        fi

        # This section tries to ensure that the Contrast agent is activated
        # It may not handle all cases.
        language=`echo $target | awk 'BEGIN { FS=":" } {print $2}'`
        case $language in

            # For Java, we take the path to the agent from the env var
            # JAVA_TOOL_OPTIONS.
            java)
                if [[ "$JAVA_TOOL_OPTIONS" == *"contrast"* ]]; then
                    agent=`echo $JAVA_TOOL_OPTIONS | sed 's/.*-javaagent://' | awk '{print $1}'`
                    until [ -f "$agent" ]; do
                        echo Waiting for $agent
                        sleep $wait_between_checks
                    done
                fi
                ;;

            # For local Node, we assume that the Contrast agent tarball has
            # been  mapped to /agents/node/node-contrast.tgz
            node*)
                if [ $language == "node-local" ]; then
                    agent=${AGENT:-/agents/node/node-contrast.tgz}

                    # Wait for the agent file to become available
                    until [ -f "$agent" ]; do
                        echo Waiting for $agent
                        sleep $wait_between_checks
                    done
                    process_node_args() {
                        script=${args[0]}
                        args=( "./node_modules/node_contrat" "$script" "${args[@]:1}" )
                    }
                else
                    agent="@contrast/agent"
                    process_node_args() {
                        script=${args[0]}
                        args=( "-r" "$agent" "$script" "--" "${args[@]:1}" )
                    }
                fi

                # Then npm install it in the app directory
                npm install $agent --no-save

                # And inject it into the startup command
                if [ `basename $0` == "node" ]; then
                    process_node_args
                    echo ARGS updated to "${args[@]}"
                else
                    echo UNSUPPORTED NODE RUNNER `basename $0` "${args[@]}"
                    exit 1
                fi
                ;;

            # For Python, we assume that the Contrast agent tarball has been
            # mapped to /agents/python/contrast-python-agent.tar.gz
            python)
                agent=${AGENT:-/agents/python/contrast-python-agent.tar.gz}

                # Wait for the agent file to become available
                until [ -f "$agent" ]; do
                    echo Waiting for $agent
                    sleep $wait_between_checks
                done

                # Then pip install it in the app directory
                pip install $agent

                # If the main script references "Flask", use our Flask shim
                # to inject the Contrast middleware
                if grep -q Flask "${args[0]}"; then
                    # Make sure our shim is used before the real Flask
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

        
    #------------
    # Wait for a network connection to succeed, on the assumption that the
    # necessary network resource is available.
    *)
        echo $target | while IFS=":" read host port; do
            until wait_for $port $host ; do
                echo Waiting for $host:$port to become available
                sleep $wait_between_checks
            done
        done
        ;;
    esac
done

# Finally, spawn the container's main app
if [ $? -eq 0 ]; then
    echo PATH=$PATH
    echo exec `basename $0` "${args[@]}"
    exec `basename $0` "${args[@]}"
fi
