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
    [name]="netty-backend-http"
    [display_name]="HTTP echo service"
    [description]="An HTTP echo service implemented in Netty"
    [jmx]="backend-test.jmx"
    [protocol]="http"
    [path]="/"
    [use_backend]=true
    [skip]=false
)

declare -A test_scenario1=(
    [name]="netty-backend-https"
    [display_name]="HTTPS echo service"
    [description]="An HTTPS echo service implemented in Netty"
    [jmx]="backend-test.jmx"
    [protocol]="https"
    [backend_flags]="--enable-ssl"
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
    if [[ "$netty_service_heap_size" == "$heap" ]]; then
        return 0
    fi
    echo "Restarting Backend Service. Worker Threads: $users, Sleep Time: $sleep_time, Additional Flags: ${backend_flags:-N/A}"
    ssh $backend_ssh_host "./netty-service/netty-start.sh -m $heap -w \
     -- ${backend_flags} --worker-threads $users --sleep-time $sleep_time"
}

function after_execute_test_scenario() {
    return 0
}

test_scenarios
