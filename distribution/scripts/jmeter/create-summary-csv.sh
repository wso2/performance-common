#!/bin/bash
# Copyright 2018 WSO2 Inc. (http://wso2.org)
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
# Create a summary report from JMeter results
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")
# Application Name to be used in column headers
application_name=""
default_filename="summary.csv"
filename="$default_filename"
default_header_names=("Heap Size" "Concurrent Users" "Message Size (Bytes)" "Back-end Service Delay (ms)")
declare -a header_names
# Results are usually in following directory structure:
# results/${scenario_name}/${heap}_heap/${total_users}_users/${msize}B/${sleep_time}ms_sleep
default_regexs=("([0-9]+[a-zA-Z])_heap" "([0-9]+)_users" "([0-9]+)B" "([0-9]+)ms_sleep")
declare -a regexs
print_column_names=false
# Prefix of files
file_prefix=""
# Results directory
default_results_dir="${script_dir}/results"
results_dir="$default_results_dir"
# GCViewer Jar file to analyze GC logs
gcviewer_jar_path=""
# JMeter Servers
# If jmeter_servers = 1, only client was used. If jmeter_servers > 1, remote JMeter servers were used.
default_jmeter_servers=1
jmeter_servers=$default_jmeter_servers
# Number of application instances
default_application_instance_count=1
application_instance_count=$default_application_instance_count
# Use warmup results
use_warmup=false
# Include GC statistics and load averages for other servers
include_all=false
# Exclude Netty
exclude_netty=false

function join_by() {
    local IFS="$1"
    shift
    echo "$*"
}

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 -n <application_name> [-o <filename>] [-c <column_header_name>] [-r <regex>] [-x] "
    echo "   [-p <file_prefix>] [-g <gcviewer_jar_path>] [-d <results_dir>]"
    echo "   [-j <jmeter_servers>] [-k <application_instance_count>] [-w] [-i] [-l] [-h]"
    echo ""
    echo "-n: Name of the application to be used in column headers."
    echo "-o: Output filename. Default: $default_filename"
    echo "-c: Column header name for each parameter."
    echo "    You should give multiple header names in order for each directory in the results directory structure."
    echo "    Default: $(join_by , "${default_header_names[@]}")"
    echo "-r: Regular expression with a single group to extract parameter value from directory name."
    echo "    You should give multiple regular expressions in order for each directory in the results directory structure."
    echo "    Default: $(join_by , "${default_regexs[@]}")"
    echo "-x: Print column names and exit."
    echo "-p: Prefix of the files to get metrics (Load Average, GC, etc)."
    echo "-g: Path of GCViewer Jar file, which will be used to analyze GC logs."
    echo "-d: Results directory. Default: $default_results_dir."
    echo "-j: Number of JMeter servers. If n=1, only client was used. If n > 1, remote JMeter servers were used. Default: $default_jmeter_servers."
    echo "-k: Number of Application instances. Default: $default_application_instance_count."
    echo "-w: Use warmup results instead of measurement results."
    echo "-i: Include GC statistics and load averages for other servers."
    echo "-l: Exclude Netty Backend Service statistics. Works with -i."
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "n:o:c:r:xp:g:d:j:k:wilh" opts; do
    case $opts in
    n)
        application_name=${OPTARG}
        ;;
    o)
        filename=${OPTARG}
        ;;
    c)
        header_names+=("${OPTARG}")
        ;;
    r)
        regexs+=("${OPTARG}")
        ;;
    x)
        print_column_names=true
        ;;
    p)
        file_prefix=${OPTARG}
        ;;
    g)
        gcviewer_jar_path=${OPTARG}
        ;;
    d)
        results_dir=${OPTARG}
        ;;
    j)
        jmeter_servers=${OPTARG}
        ;;
    k)
        application_instance_count=${OPTARG}
        ;;
    w)
        use_warmup=true
        ;;
    i)
        include_all=true
        ;;
    l)
        exclude_netty=true
        ;;
    c)
        header_names+=("${OPTARG}")
        ;;
    r)
        regexs+=("${OPTARG}")
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

if [ ${#header_names[@]} -eq 0 ]; then
    header_names+=("${default_header_names[@]}")
fi

if [ ${#regexs[@]} -eq 0 ]; then
    regexs+=("${default_regexs[@]}")
fi

# Validate options
if [[ -z $application_name ]]; then
    echo "Please specify the application name."
    exit 1
fi

if [[ -z $filename ]]; then
    echo "Please specify the output filename."
    exit 1
fi

if [[ -z $jmeter_servers ]]; then
    echo "Please specify the number of JMeter servers."
    exit 1
fi

if [ ! "${#header_names[@]}" -eq "${#regexs[@]}" ]; then
    echo "Number of column header names should be equal to number of regular expressions."
    exit 1
fi

function add_gc_headers() {
    headers+=("$1 GC Throughput (%)")
    headers+=("$1 Memory Footprint (M)")
    headers+=("Average $1 Memory Footprint After Full GC (M)")
    headers+=("Standard Deviation of $1 Memory Footprint After Full GC (M)")
}

function add_sar_headers() {
    # Queue length and load averages
    headers+=("$1 - Run queue length")
    headers+=("$1 - Number of tasks")
    headers+=("$1 - System Load Average - Last 1 minute")
    headers+=("$1 - System Load Average - Last 5 minutes")
    headers+=("$1 - System Load Average - Last 15 minutes")
    headers+=("$1 - Blocked")
    # CPU utilization
    headers+=("$1 - CPU - User (%)")
    headers+=("$1 - CPU - Nice (%)")
    headers+=("$1 - CPU - System (%)")
    headers+=("$1 - CPU - I/O Wait (%)")
    headers+=("$1 - CPU - Steal (%)")
    headers+=("$1 - CPU - Idle (%)")
    # Memory utilization statistics
    headers+=("$1 - Memory - Free (kB)")
    headers+=("$1 - Memory - Available (kB)")
    headers+=("$1 - Memory - Used (kB)")
    headers+=("$1 - Memory - Used (%)")
    headers+=("$1 - Memory - Buffers (kB)")
    headers+=("$1 - Memory - Cached (kB)")
    headers+=("$1 - Memory - Commit (kB)")
    headers+=("$1 - Memory - Commit (%)")
    headers+=("$1 - Memory - Active (kB)")
    headers+=("$1 - Memory - Inactive (kB)")
    headers+=("$1 - Memory - Dirty (kB)")
    # Block device activity
    headers+=("$1 - Block Device - TPS (transfers/s)")
    headers+=("$1 - Block Device - Read TPS (kB/s)")
    headers+=("$1 - Block Device - Write TPS (kB/s)")
    headers+=("$1 - Block Device - Discard TPS (kB/s)")
    headers+=("$1 - Block Device - Average Request Size (kB)")
    headers+=("$1 - Block Device - Average Queue Length")
    headers+=("$1 - Block Device - Average Time (ms)")
    headers+=("$1 - Block Device - Utilization (%)")
    # I/O and transfer rate statistics
    headers+=("$1 - IO - TPS (transfers/s)")
    headers+=("$1 - IO - Read TPS (requests/s")
    headers+=("$1 - IO - Write TPS (requests/s)")
    headers+=("$1 - IO - Discard TPS (requests/s)")
    headers+=("$1 - IO - Data reads per seconds (blocks/s)")
    headers+=("$1 - IO - Data writes per seconds (blocks/s)")
    headers+=("$1 - IO - Data discarded per seconds (blocks/s)")
    # Task creation and system switching activity
    headers+=("$1 - Tasks created per second")
    headers+=("$1 - Context switches per second")
    # Status  of inode, file and other kernel tables
    headers+=("$1 - Unused directory cache entries")
    headers+=("$1 - Number of file handles")
    headers+=("$1 - Number of inode handlers")
    headers+=("$1 - Number of pseudo-terminals")
    # Network statistics
    headers+=("$1 - Network - Received packets/s")
    headers+=("$1 - Network - Transmitted packets/s")
    headers+=("$1 - Network - Received kB/s")
    headers+=("$1 - Network - Transmitted kB/s")
    headers+=("$1 - Network - Received compressed packets/s")
    headers+=("$1 - Network - Transmitted compressed packets/s")
    headers+=("$1 - Network - Received multicast packets/s")
    headers+=("$1 - Network - Utilization (%)")
}

function add_perf_headers() {
    # perf stat headers
    headers+=("$1 - Task clock")
    headers+=("$1 - Context switches")
    headers+=("$1 - CPU Migrations")
    headers+=("$1 - Page faults")
}

declare -ag headers
headers+=("Scenario Name")
for ((i = 0; i < ${#header_names[@]}; i++)); do
    headers+=("${header_names[$i]}")
done
headers+=("Label")
headers+=("# Samples")
headers+=("Error Count")
headers+=("Error %")
headers+=("Throughput (Requests/sec)")
headers+=("Average Response Time (ms)")
headers+=("Average Users in the System")
headers+=("Standard Deviation of Response Time (ms)")
headers+=("Minimum Response Time (ms)")
headers+=("Maximum Response Time (ms)")
headers+=("75th Percentile of Response Time (ms)")
headers+=("90th Percentile of Response Time (ms)")
headers+=("95th Percentile of Response Time (ms)")
headers+=("98th Percentile of Response Time (ms)")
headers+=("99th Percentile of Response Time (ms)")
headers+=("99.9th Percentile of Response Time (ms)")
headers+=("Received (KB/sec)")
headers+=("Sent (KB/sec)")

if [[ $application_instance_count -gt 1 ]]; then
    for ((i = 1; i <= $application_instance_count; i++)); do
        add_gc_headers "${application_name} ${i}"
    done
else
    add_gc_headers "${application_name}"
fi
if [ "$include_all" = true ]; then
    if [ "$exclude_netty" = false ]; then
        add_gc_headers "Netty Service"
    fi
    add_gc_headers "JMeter Client"
    if [ $jmeter_servers -gt 1 ]; then
        for ((c = 1; c <= $jmeter_servers; c++)); do
            add_gc_headers "JMeter Server $c"
        done
    fi
fi
if [[ $application_instance_count -gt 1 ]]; then
    for ((i = 1; i <= $application_instance_count; i++)); do
        add_sar_headers "${application_name} ${i}"
        add_perf_headers "${application_name} ${i}"
    done
else
    add_sar_headers "${application_name}"
    add_perf_headers "${application_name}"
fi
if [ "$include_all" = true ]; then
    if [ "$exclude_netty" = false ]; then
        add_sar_headers "Netty Service"
        add_perf_headers "Netty Service"
    fi
    add_sar_headers "JMeter Client"
    if [ $jmeter_servers -gt 1 ]; then
        for ((c = 1; c <= $jmeter_servers; c++)); do
            add_sar_headers "JMeter Server $c"
        done
    fi
fi

if [ "$print_column_names" = true ]; then
    for ((i = 0; i < ${#headers[@]}; i++)); do
        echo "${headers[$i]}"
    done
    exit 0
fi

# Following should be validated only if "$print_column_names" = false
if [[ -z $file_prefix ]]; then
    echo "Please specify the prefix of the files."
    exit 1
fi

if [[ -z $application_instance_count ]]; then
    echo "Please specify the number of Application instances."
    exit 1
fi

if [[ ! -f $gcviewer_jar_path ]]; then
    echo "Please specify the path to GCViewer JAR file."
    exit 1
fi

if [[ ! -d $results_dir ]]; then
    echo "Please specify the results directory."
    exit 1
fi

if [[ -f $filename ]]; then
    echo "$filename already exists"
    exit 1
fi

declare -A scenario_display_names

# Check test-metadata.json file
if [[ -f ${results_dir}/test-metadata.json ]]; then
    while IFS='=' read -r key value; do
        scenario_display_names["$key"]="$value"
    done < <(jq -r '.test_scenarios[] | "\(.name)=\(.display_name)"' ${results_dir}/test-metadata.json)
else
    echo "WARNING: Could not find test metadata."
fi

header_row=""
for ((i = 0; i < ${#headers[@]}; i++)); do
    if [ $i -gt 0 ]; then
        header_row+=","
    fi
    header_row+="${headers[$i]}"
done

echo -ne "${header_row}\r\n" >$filename

function write_column() {
    local data_file="$1"
    local name="$2"
    echo -n "," >>$filename
    echo -n "$(jq -r ".$name" "$data_file")" >>$filename
}

function get_value_from_gc_summary() {
    echo $(grep -m 1 $2\; $1 | sed -r 's/.*\;(.*)\;.*/\1/' | sed 's/,//g')
}

function add_gc_summary_details() {
    local server="$1"
    local gc_log_file="${current_dir}/${server}_gc.log"
    if [[ -f $gc_log_file ]]; then
        local gc_summary_file="${current_dir}/${server}_gc.txt"
        echo "Reading $gc_log_file"
        java -Xms128m -Xmx128m -jar $gcviewer_jar_path $gc_log_file $gc_summary_file -t SUMMARY &>/dev/null
        columns+=("$(get_value_from_gc_summary $gc_summary_file throughput)")
        columns+=("$(get_value_from_gc_summary $gc_summary_file footprint)")
        columns+=("$(get_value_from_gc_summary $gc_summary_file avgfootprintAfterFullGC)")
        columns+=("$(get_value_from_gc_summary $gc_summary_file avgfootprintAfterFullGCσ)")
    else
        echo "WARNING: File missing! $gc_log_file"
        columns+=("N/A" "N/A" "N/A" "N/A")
    fi
}

function add_sar_details() {
    local server="$1"
    declare -a sar_csv_reports
    for report in "loadavg" "cpu" "memory" "disk" "io" "task" "file" "network"; do
        local report_file="${current_dir}/${server}/${server}_sar_report_${report}.csv"
        if [[ -f $report_file ]]; then
            sar_csv_reports+=("$report_file")
        fi
    done
    local test_duration_file="${current_dir}/test_duration.json"
    if [[ ${#sar_csv_reports[@]} -gt 0 ]] && [[ -f $test_duration_file ]]; then
        sar_start_timestamp=$(jq -r '.start_timestamp' $test_duration_file)
        sar_end_timestamp=$(jq -r '.end_timestamp' $test_duration_file)
        sar_end_timestamp=$(($sar_end_timestamp + 60))
        # Create summary
        local sar_summary_file="${current_dir}/${server}_sar_summary.json"
        $script_dir/create-sar-summary.py --sar-csv-reports "${sar_csv_reports[@]}" \
            --start-timestamp $sar_start_timestamp --end-timestamp $sar_end_timestamp \
            --output-file "${sar_summary_file}"
        declare -A sar_averages
        while IFS="=" read -r key value; do
            sar_averages[$key]="$value"
        done < <(jq -r ".|to_entries|map(\"\(.key)=\(.value)\")|.[]" "${sar_summary_file}")
        # Queue length and load averages
        columns+=("${sar_averages[runqsz]}")
        columns+=("${sar_averages[plistsz]}")
        columns+=("${sar_averages[ldavg1]}")
        columns+=("${sar_averages[ldavg5]}")
        columns+=("${sar_averages[ldavg15]}")
        columns+=("${sar_averages[blocked]}")
        # CPU utilization
        columns+=("${sar_averages[user]}")
        columns+=("${sar_averages[nice]}")
        columns+=("${sar_averages[system]}")
        columns+=("${sar_averages[iowait]}")
        columns+=("${sar_averages[steal]}")
        columns+=("${sar_averages[idle]}")
        # Memory utilization statistics
        columns+=("${sar_averages[kbmemfree]}")
        columns+=("${sar_averages[kbavail]}")
        columns+=("${sar_averages[kbmemused]}")
        columns+=("${sar_averages[memused]}")
        columns+=("${sar_averages[kbbuffers]}")
        columns+=("${sar_averages[kbcached]}")
        columns+=("${sar_averages[kbcommit]}")
        columns+=("${sar_averages[commit]}")
        columns+=("${sar_averages[kbactive]}")
        columns+=("${sar_averages[kbinact]}")
        columns+=("${sar_averages[kbdirty]}")
        # Block device activity
        columns+=("${sar_averages[tps]}")
        columns+=("${sar_averages[rkBs]}")
        columns+=("${sar_averages[wkBs]}")
        columns+=("${sar_averages[dkBs]}")
        columns+=("${sar_averages[areqsz]}")
        columns+=("${sar_averages[aqusz]}")
        columns+=("${sar_averages[await]}")
        columns+=("${sar_averages[util]}")
        # I/O and transfer rate statistics
        columns+=("${sar_averages[tps]}")
        columns+=("${sar_averages[rtps]}")
        columns+=("${sar_averages[wtps]}")
        columns+=("${sar_averages[dtps]}")
        columns+=("${sar_averages[breads]}")
        columns+=("${sar_averages[bwrtns]}")
        columns+=("${sar_averages[bdscds]}")
        # Task creation and system switching activity
        columns+=("${sar_averages[procs]}")
        columns+=("${sar_averages[cswchs]}")
        # Status  of inode, file and other kernel tables
        columns+=("${sar_averages[dentunusd]}")
        columns+=("${sar_averages[filenr]}")
        columns+=("${sar_averages[inodenr]}")
        columns+=("${sar_averages[ptynr]}")
        # Network statistics
        columns+=("${sar_averages[rxpcks]}")
        columns+=("${sar_averages[txpcks]}")
        columns+=("${sar_averages[rxkBs]}")
        columns+=("${sar_averages[txkBs]}")
        columns+=("${sar_averages[rxcmps]}")
        columns+=("${sar_averages[txcmps]}")
        columns+=("${sar_averages[rxmcsts]}")
        columns+=("${sar_averages[ifutil]}")
    else
        echo "WARNING: SAR reports are not available!"
        for i in {1..52}; do
            columns+=("N/A")
        done
    fi
}

function add_perf_details() {
    local server="$1"
    local perf_file="${current_dir}/${server}/${server}_perf.csv"
    if [[ -f $perf_file ]]; then
        declare -A perf_counters
        while IFS=";" read -r value name; do
            perf_counters[$name]="$value"
        done < <(cat $perf_file | sed -e '/# /d' -e '/^$/d' -e '/<not supported>/d' -e 's/-//' | cut -d\; -f1,3)
        columns+=("${perf_counters[taskclock]}")
        columns+=("${perf_counters[contextswitches]}")
        columns+=("${perf_counters[cpumigrations]}")
        columns+=("${perf_counters[pagefaults]}")
    else
        echo "WARNING: Perf report is not available!"
        for i in {1..4}; do
            columns+=("N/A")
        done
    fi
}

data_file="results-measurement-summary.json"
if [[ $use_warmup == true ]]; then
    data_file="results-warmup-summary.json"
fi

for summary_json in $(find ${results_dir} -type f -name ${data_file} | sort -V); do
    echo "Reading results from ${summary_json}..."
    current_dir="$(dirname ${summary_json})"
    echo "Current directory: $current_dir"

    #Get labels
    jq -r 'keys[]' ${summary_json} | while read label; do
        echo "Getting summary results for label: ${label}..."
        declare -A summary_results
        while IFS="=" read -r key value; do
            summary_results[$key]="$value"
        done < <(jq -r ".[\"${label}\"]|to_entries|map(\"\(.key)=\(.value)\")|.[]" $summary_json)

        # All columns
        declare -ag columns=()

        IFS='/' read -ra directories <<<"$current_dir"
        start_index=$((${#directories[@]} - ${#header_names[@]} - 1))
        directory_names=("${directories[@]:$start_index}")
        # First directory is the scenario name
        scenario_name="${directory_names[0]}"
        columns+=("${scenario_display_names["$scenario_name"]="$scenario_name"}")
        for ((i = 0; i < ${#regexs[@]}; i++)); do
            value="$(echo "${directory_names[$((i + 1))]}" | sed -nE "s/${regexs[$i]}/\1/p")"
            columns+=("${value:-N/A}")
        done
        columns+=("${label}")
        columns+=("${summary_results[samples]}")
        columns+=("${summary_results[errors]}")
        columns+=("${summary_results[errorPercentage]}")
        columns+=("${summary_results[throughput]}")
        columns+=("${summary_results[mean]}")
        average_users="$(bc <<<"scale=0; ${summary_results[throughput]}*${summary_results[mean]}/1000")"
        columns+=("${average_users}")
        columns+=("${summary_results[stddev]}")
        columns+=("${summary_results[min]}")
        columns+=("${summary_results[max]}")
        columns+=("${summary_results[p75]}")
        columns+=("${summary_results[p90]}")
        columns+=("${summary_results[p95]}")
        columns+=("${summary_results[p98]}")
        columns+=("${summary_results[p99]}")
        columns+=("${summary_results[p999]}")
        columns+=("${summary_results[receivedKBytesRate]}")
        columns+=("${summary_results[sentKBytesRate]}")

        if [[ $application_instance_count -gt 1 ]]; then
            for ((i = 1; i <= $application_instance_count; i++)); do
                add_gc_summary_details "${file_prefix}${i}"
            done
        else
            add_gc_summary_details "${file_prefix}"
        fi
        if [ "$include_all" = true ]; then
            if [ "$exclude_netty" = false ]; then
                add_gc_summary_details netty
            fi
            add_gc_summary_details jmeter
            if [ $jmeter_servers -gt 1 ]; then
                for ((c = 1; c <= $jmeter_servers; c++)); do
                    add_gc_summary_details jmeter$c
                done
            fi
        fi

        if [[ $application_instance_count -gt 1 ]]; then
            for ((i = 1; i <= $application_instance_count; i++)); do
                add_sar_details "${file_prefix}${i}"
                add_perf_details "${file_prefix}${i}"
            done
        else
            add_sar_details "${file_prefix}"
            add_perf_details "${file_prefix}"
        fi
        if [ "$include_all" = true ]; then
            if [ "$exclude_netty" = false ]; then
                add_sar_details netty
                add_perf_details netty
            fi
            add_sar_details jmeter
            if [ $jmeter_servers -gt 1 ]; then
                for ((c = 1; c <= $jmeter_servers; c++)); do
                    add_sar_details jmeter$c
                done
            fi
        fi

        row=""
        for ((i = 0; i < ${#columns[@]}; i++)); do
            if [ $i -gt 0 ]; then
                row+=","
            fi
            row+="${columns[$i]}"
        done

        echo -ne "${row}\r\n" >>$filename
    done
done
echo "Wrote summary statistics to $filename."
