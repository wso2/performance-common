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
# Start JMeter Server
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")
JMETER_HOME=""
for dir in $HOME/apache-jmeter-*; do
    [ -d "${dir}" ] && JMETER_HOME="${dir}" && break
done

jar_name=ApacheJMeter.jar
jmeter_host=$1

if pgrep -f "$jar_name" > /dev/null; then
    echo "Stopping JMeter Server"
    pkill -f $jar_name
fi

echo "Waiting for JMeter Server to stop"

while true
do
    if ! pgrep -f "$jar_name" > /dev/null; then
        echo "JMeter Server stopped"
        break
    else
        sleep 1
    fi
done

gc_log_file=$HOME/jmetergc.log

if [[ -f $gc_log_file ]]; then
    echo "GC Log exists. Moving $gc_log_file to /tmp"
    mv $gc_log_file /tmp/
fi

export JVM_ARGS="-Xms4g -Xmx4g -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:$gc_log_file"
export RMI_HOST_DEF=-Djava.rmi.server.hostname=$jmeter_host

echo "Starting JMeter Server"
nohup $JMETER_HOME/bin/jmeter-server > server.out 2>&1 &

# Sleep for 10 seconds and make sure the JMeter server is ready to run the tests
sleep 10
