#!/bin/bash -e
# Copyright 2017 WSO2 Inc. (http://wso2.org)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ----------------------------------------------------------------------------
# Start JMeter Server
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")

jar_name=ApacheJMeter.jar
jmeter_hostname=""
jmeter_installation_dir=""
jmeter_heap_size=""

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 -n <jmeter_hostname> -i <jmeter_installation_dir> [-h] -- [jmeter_flags]"
    echo ""
    echo "-n: The JMeter hostname."
    echo "-i: The JMeter installation directory."
    echo "-m: The heap memory size of JMeter."
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "n:i:m:h" opts; do
    case $opts in
    n)
        jmeter_hostname=${OPTARG}
        ;;
    i)
        jmeter_installation_dir=${OPTARG}
        ;;
    m)
        jmeter_heap_size=${OPTARG}
        ;;
    h)
        usage
        exit 0
        ;;
    \?)
        usage
        exit 1
        ;;
    esac
done
shift "$((OPTIND - 1))"

jmeter_flags="$@"

JMETER_HOME=""
for dir in $jmeter_installation_dir/apache-jmeter-*; do
    [ -d "${dir}" ] && JMETER_HOME="${dir}" && break
done

if [[ -z $jmeter_hostname ]]; then
    echo "Please provide a hostname for JMeter server."
    exit 1
fi

if [[ ! -d $JMETER_HOME ]]; then
    echo "Could not find JMeter home directory."
    exit 1
fi

if pgrep -f "$jar_name" >/dev/null; then
    echo "Stopping JMeter Server"
    pkill -f $jar_name

    echo "Waiting for JMeter Server to stop"

    while true; do
        if ! pgrep -f "$jar_name" >/dev/null; then
            echo "JMeter Server stopped"
            break
        else
            sleep 1
        fi
    done
fi

gc_log_file=$HOME/jmetergc.log

if [[ -f $gc_log_file ]]; then
    echo "GC Log exists. Moving $gc_log_file to /tmp"
    mv $gc_log_file /tmp/
fi

if [[ -z $jmeter_heap_size ]]; then
    jmeter_heap_size="4g"
fi

export JVM_ARGS="-Xms$jmeter_heap_size -Xmx$jmeter_heap_size -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:$gc_log_file $jmeter_flags"
export RMI_HOST_DEF=-Djava.rmi.server.hostname=$jmeter_hostname

echo "Starting JMeter Server with JVM_ARGS=$JVM_ARGS"
nohup $JMETER_HOME/bin/jmeter-server >server.out 2>&1 &

# Sleep for 10 seconds and make sure the JMeter server is ready to run the tests
sleep 10
log_files=("server.out" "jmeter.log" "jmeter-server.log")

for log_file in "${log_files[@]}"; do
    if [[ -s $log_file ]]; then
        echo "Viewing log file: $log_file"
        echo -ne "----\n"
        cat $log_file
        echo -ne "----\n"
    fi
done

if pgrep -f "$jar_name" >/dev/null; then
    echo "Started JMeter server."
else
    echo "JMeter Server has not started!"
    exit 1
fi
