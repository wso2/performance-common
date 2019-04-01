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

function write_sar_reports() {
    local server=$1
    local sa_file=$2
    local sa_yesterday_file=$3
    if [[ ! -f $sa_file ]]; then
        return 1
    fi
    if [[ -z $report_location ]]; then
        return 1
    fi
    local sar_args=""
    if [[ ! -z $sar_start_time ]]; then
        sar_args+=" -s $sar_start_time"
    fi
    if [[ ! -z $sar_end_time ]]; then
        sar_args+=" -e $sar_end_time"
    fi
    local file_prefix="${report_location}/${server}_sar_report"
    sadf $sar_args -d -U $sa_file -- -A >${file_prefix}_all.csv
    sadf $sar_args -d -h -U $sa_file -- -A >${file_prefix}_all_h.csv
    sadf $sar_args -g $sa_file -- -A >${file_prefix}_all.svg
    sar $sar_args -A >${file_prefix}_all.txt
    sar $sar_args -q >${file_prefix}_loadavg.txt
    sar $sar_args -u >${file_prefix}_cpu.txt
    sar $sar_args -r >${file_prefix}_memory.txt
    sar $sar_args -n DEV >${file_prefix}_network.txt
    sar $sar_args -d >${file_prefix}_disk.txt
    sar $sar_args -b >${file_prefix}_io.txt
    sar $sar_args -w >${file_prefix}_task.txt
    sar $sar_args -v >${file_prefix}_file.txt

    # Write CSVs
    for sa in $sa_yesterday_file $sa_file; do
        if [[ ! -f $sa ]]; then
            continue
        fi
        sadf -U -d $sa -- -q | write_sar_csv_report ${file_prefix}_loadavg.csv
        sadf -U -d $sa -- -u | write_sar_csv_report ${file_prefix}_cpu.csv
        sadf -U -d $sa -- -r | write_sar_csv_report ${file_prefix}_memory.csv
        sadf -U -d $sa -- -d | write_sar_csv_report ${file_prefix}_disk.csv
        sadf -U -d $sa -- -b | write_sar_csv_report ${file_prefix}_io.csv
        sadf -U -d $sa -- -w | write_sar_csv_report ${file_prefix}_task.csv
        sadf -U -d $sa -- -v | write_sar_csv_report ${file_prefix}_file.csv
        sadf -U -d $sa -- -n DEV | write_sar_csv_report ${file_prefix}_network.csv
    done
}

# Write SAR report
function write_sar_csv_report() {
    if [[ -f $1 ]]; then
        sed '1d' >>$1
    else
        sed '1 s/# //' >$1
    fi
}

function write_server_metrics() {
    if [[ -z $report_location ]]; then
        echo "Report location not found" >&2
        return 1
    fi
    local server=$1
    echo "Collecting server metrics for $server."
    local ssh_host=$2
    local pgrep_pattern=$3
    local command_prefix=""
    export LC_TIME=C
    local sar_yesterday_file="/var/log/sysstat/sa$(date +%d -d yesterday)"
    local sar_today_file="/var/log/sysstat/sa$(date +%d)"
    local local_sar_yesterday_file="${report_location}/${server}_$(basename $sar_yesterday_file)"
    local local_sar_today_file="${report_location}/${server}_$(basename $sar_today_file)"
    if [[ ! -z $ssh_host ]]; then
        command_prefix="ssh -o SendEnv=LC_TIME $ssh_host"
        download_file $server $sar_yesterday_file $(basename $local_sar_yesterday_file)
        download_file $server $sar_today_file $(basename $local_sar_today_file)
    else
        if [[ -f $sar_yesterday_file ]]; then
            echo "Copying $sar_yesterday_file to $local_sar_yesterday_file..."
            cp -v $sar_yesterday_file $local_sar_yesterday_file
        fi
        if [[ -f $sar_today_file ]]; then
            echo "Copying $sar_today_file to $local_sar_today_file..."
            cp -v $sar_today_file $local_sar_today_file
        fi
    fi
    write_sar_reports $server $local_sar_today_file $local_sar_yesterday_file
    $command_prefix date >${report_location}/${server}_date.txt
    $command_prefix ss -s >${report_location}/${server}_ss.txt
    $command_prefix uptime >${report_location}/${server}_uptime.txt
    $command_prefix top -bn 1 >${report_location}/${server}_top.txt
    $command_prefix df -h >${report_location}/${server}_disk_usage.txt
    $command_prefix free -m >${report_location}/${server}_free_memory.txt
    if [[ ! -z $pgrep_pattern ]]; then
        $command_prefix ps u -p \`pgrep -f $pgrep_pattern\` >${report_location}/${server}_ps.txt
    fi
}
