#!/bin/bash -e
# Copyright 2019 WSO2 Inc. (http://wso2.org)
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
# Start collecting Performance counter stats using perf
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")
pgrep_pattern=""

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 -p <pgrep_pattern>"
    echo ""
    echo "-p: Pattern to grep the process ID"
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "p:d:wh" opts; do
    case $opts in
    p)
        pgrep_pattern="${OPTARG}"
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

if [[ -z $pgrep_pattern ]]; then
    echo "Please provide the pattern to grep the process ID."
    exit 1
fi

# Remove exisiting perf.csv
if rm /tmp/perf.csv >/dev/null 2>&1; then
    echo "Removed existing /tmp/perf.csv"
fi

pid=""
n=0
until [ $n -ge 60 ]; do
    declare -a pids=($(pgrep -f "$pgrep_pattern"))
    if [[ ${#pids[@]} -gt 2 ]]; then
        echo "WARNING: The pattern \"$pgrep_pattern\" to match process is not unique! PIDs found: ${pids[@]}"
    fi
    for pgrep_pid in ${pids[@]}; do
        if [[ $pgrep_pid != $$ ]]; then
            # Ignore this script's process ID
            pid=$pgrep_pid
            break 2
        fi
    done
    echo "Waiting for the process with pattern \"$pgrep_pattern\""
    sleep 1
    n=$(($n + 1))
done
if [[ -n $pid ]]; then
    echo "Collecting perf stats of the process ID ($pid) with pattern: $pgrep_pattern"
    nohup perf stat -e task-clock,context-switches,cpu-migrations,page-faults,cache-misses,cycles,instructions,branches,branch-misses -x\; -d -d -p $pid -o /tmp/perf.csv >/dev/null 2>&1 &
    echo "perf process ID: $!"
else
    echo "Process with pattern \"$pgrep_pattern\" not found!"
fi
