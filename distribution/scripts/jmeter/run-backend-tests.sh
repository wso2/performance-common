#!/bin/bash -e
# Copyright (c) 2019, WSO2 Inc. (http://wso2.org) All Rights Reserved.
#
# WSO2 Inc. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# ----------------------------------------------------------------------------
# Run Backend Performance Tests
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")
# Execute common script
. $script_dir/perf-test-common.sh

function initialize() {
    export backend_host=$(get_ssh_hostname $backend_ssh_host)
}
export -f initialize

declare -A test_scenario0=(
    [name]="backend-h1c"
    [display_name]="Echo service - HTTP/1.1 over cleartext"
    [description]="An HTTP/1.1 over cleartext echo service implemented in Netty."
    [jmx]="http-post-request.jmx"
    [protocol]="http"
    [path]="/"
    [use_backend]=true
    [skip]=false
)

declare -A test_scenario1=(
    [name]="backend-h1"
    [display_name]="Echo service - HTTP/1.1 over TLS"
    [description]="An HTTP/1.1 over TLS echo service implemented in Netty."
    [jmx]="http-post-request.jmx"
    [protocol]="https"
    [backend_flags]="--ssl"
    [path]="/"
    [use_backend]=true
    [skip]=false
)

declare -A test_scenario2=(
    [name]="backend-h2"
    [display_name]="Echo service - HTTP/2 over TLS"
    [description]="An HTTP/2 over TLS echo service implemented in Netty."
    [jmx]="http2-post-request.jmx"
    [protocol]="https"
    [backend_flags]="--http2 --ssl"
    [path]="/"
    [use_backend]=true
    [skip]=false
)

function before_execute_test_scenario() {
    local service_path=${scenario[path]}
    local protocol=${scenario[protocol]}
    local backend_flags=${scenario[backend_flags]}
    jmeter_params+=("host=$backend_host" "port=8688" "path=$service_path")
    jmeter_params+=("payload=$HOME/${msize}B.json" "response_size=${msize}B" "protocol=$protocol")
    if [[ $backend_flags == *"http2"* ]]; then
        JMETER_JVM_ARGS="-Xbootclasspath/p:/opt/alpnboot/alpnboot.jar"
    fi
    if [[ "$netty_service_heap_size" == "$heap" ]]; then
        return 0
    fi
    echo "Restarting Backend Service. Heap: $heap, Delay: $sleep_time, Additional Flags: ${backend_flags:-N/A}"
    ssh $backend_ssh_host "./netty-service/netty-start.sh -m $heap -w \
     -- ${backend_flags} --delay $sleep_time"
    collect_server_metrics netty $backend_ssh_host netty
}

function after_execute_test_scenario() {
    return 0
}

test_scenarios
