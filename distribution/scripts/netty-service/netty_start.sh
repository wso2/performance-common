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
service_name=netty-http-echo-service
sleep_time=$1

if [ -z "$sleep_time" ]; then
    sleep_time=0
fi

if pgrep -f "$service_name" > /dev/null; then
    echo "Shutting down Netty"
    pkill -f $service_name
fi

if [[ -f $script_dir/logs/nettygc.log ]]; then
    echo "GC Log exists. Moving to /tmp"
    mv $script_dir/logs/nettygc.log /tmp/
fi

mkdir -p $script_dir/logs

echo "Starting Netty"
nohup java -Xms2g -Xmx2g -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:$script_dir/logs/nettygc.log \
    -jar $script_dir/$service_name-${performance.common.version}.jar --worker-threads 2000 --sleep-time $sleep_time &
