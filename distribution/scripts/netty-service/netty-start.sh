#!/bin/bash
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
# Start Netty Service
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")
# Change directory to make sure logs directory is created inside $script_dir
cd $script_dir
service_name=netty-http-echo-service
heap_size=""

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 [-m <heap_size>] [-h] -- [netty_service_flags]"
    echo ""
    echo "-m: The heap memory size of Netty Service."
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "m:h" opts; do
    case $opts in
    m)
        heap_size=${OPTARG}
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

netty_service_flags="$@"

if [[ -z $heap_size ]]; then
    heap_size="4G"
fi

if pgrep -f "$service_name" >/dev/null; then
    echo "Shutting down Netty"
    pkill -f $service_name
fi

gc_log_file=./logs/nettygc.log

if [[ -f $gc_log_file ]]; then
    echo "GC Log exists. Moving $gc_log_file to /tmp"
    mv $gc_log_file /tmp/
fi

mkdir -p logs

echo "Starting Netty"
nohup java -Xms${heap_size} -Xmx${heap_size} -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:$gc_log_file \
    -jar $service_name-${performance.common.version}.jar "$@" >netty.out 2>&1 &

sleep 1
tail -10 netty.out
