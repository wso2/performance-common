#!/bin/bash -e
# Copyright (c) 2018, WSO2 Inc. (http://wso2.org) All Rights Reserved.
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
# Common functions
# ----------------------------------------------------------------------------

function function_exists() {
    declare -F $1 >/dev/null 2>&1
}

function check_command() {
    if ! command -v $1 >/dev/null 2>&1; then
        echo "Please install $1"
        exit 1
    fi
}

function format_time() {
    # Duration in seconds
    local duration="$1"
    local minutes=$(echo "$duration/60" | bc)
    local seconds=$(echo "$duration-$minutes*60" | bc)
    if [[ $minutes -ge 60 ]]; then
        local hours=$(echo "$minutes/60" | bc)
        minutes=$(echo "$minutes-$hours*60" | bc)
        printf "%d hour(s), %02d minute(s) and %02d second(s)\n" $hours $minutes $seconds
    elif [[ $minutes -gt 0 ]]; then
        printf "%d minute(s) and %02d second(s)\n" $minutes $seconds
    else
        printf "%d second(s)\n" $seconds
    fi
}

function measure_time() {
    local end_time=$(date +%s)
    local start_time=$1
    local duration=$(echo "$end_time - $start_time" | bc)
    echo "$duration"
}

function get_ssh_hostname() {
    ssh -G $1 | awk '/^hostname / { print $2 }'
}

function write_server_metrics() {
    local server=$1
    echo "Collecting server metrics for $server."
    local ssh_host=$2
    local pgrep_pattern=$3
    local command_prefix=""
    export LC_TIME=C
    if [[ ! -z $ssh_host ]]; then
        command_prefix="ssh -o SendEnv=LC_TIME $ssh_host"
    fi
    $command_prefix ss -s >${report_location}/${server}_ss.txt
    $command_prefix uptime >${report_location}/${server}_uptime.txt
    $command_prefix sar -q >${report_location}/${server}_loadavg.txt
    $command_prefix sar -A >${report_location}/${server}_sar.txt
    $command_prefix top -bn 1 >${report_location}/${server}_top.txt
    $command_prefix df -h >${report_location}/${server}_disk_usage.txt
    $command_prefix free -m >${report_location}/${server}_free_memory.txt
    if [[ ! -z $pgrep_pattern ]]; then
        $command_prefix ps u -p \`pgrep -f $pgrep_pattern\` >${report_location}/${server}_ps.txt
    fi
}

function download_file() {
    local server=$1
    local remote_file=$2
    local local_file_name=$3
    echo "Downloading $remote_file from $server to $local_file_name"
    if scp -qp $server:$remote_file ${report_location}/$local_file_name; then
        echo "File transfer succeeded."
    else
        echo "WARNING: File transfer failed!"
    fi
}
