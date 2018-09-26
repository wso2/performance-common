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
# Common functions for performance testing script
# ----------------------------------------------------------------------------

# Any script depending on this script must define test scenarios as follows:
#
# declare -A test_scenario0=(
#     [name]="test_scenario_name1"
#     [jmx]="test_scenario_name1.jmx"
#     [use_backend]=true
#     [skip]=false
# )
# declare -A test_scenario1=(
#     [name]="test_scenario_name2"
#     [jmx]="test_scenario_name2.jmx"
#     [use_backend]=true
#     [skip]=false
# )
#
# Then define following functions in the script
# 1. before_execute_test_scenario
# 2. after_execute_test_scenario
#
# In above functions, following variables may be used
# 1. scenario_name
# 2. heap
# 3. users
# 4. msize
# 5. sleep_time
# 6. report_location
#
# Use jmeter_params array in before_execute_test_scenario to provide JMeter parameters.
#
# In before_execute_test_scenario JMETER_JVM_ARGS variable can be set to provide
# additional JVM arguments to JMETER.
#
# Finally, execute test scenarios using the function test_scenarios

# Concurrent users (these will by multiplied by the number of JMeter servers)
default_concurrent_users="50 100 150 500 1000"
declare -a concurrent_users
# Message Sizes
default_message_sizes="50 1024 10240"
declare -a message_sizes
# Common backend sleep times (in milliseconds).
default_backend_sleep_times="0 30 500 1000"
declare -a backend_sleep_times
# Application heap Sizes
default_heap_sizes="2g"
declare -a heap_sizes

# Test Duration in seconds
default_test_duration=900
test_duration=$default_test_duration
# Warm-up time in minutes
default_warmup_time=5
warmup_time=$default_warmup_time
# Heap size of JMeter Client
default_jmeter_client_heap_size=2g
jmeter_client_heap_size=$default_jmeter_client_heap_size
# Heap size of JMeter Server
default_jmeter_server_heap_size=4g
jmeter_server_heap_size=$default_jmeter_server_heap_size

# Heap size of Netty Service
default_netty_service_heap_size=4g
netty_service_heap_size=$default_netty_service_heap_size

# Scenario names to include
declare -a include_scenario_names
# Scenario names to exclude
declare -a exclude_scenario_names

backend_ssh_host=netty

# JMeter Servers
# If jmeter_servers = 1, only client will be used. If jmeter_servers > 1, remote JMeter servers will be used.
default_jmeter_servers=1
jmeter_servers=$default_jmeter_servers
# JMeter SSH hosts array depending on the number of servers. For example, jmeter1 and jmeter2 for two servers.
declare -a jmeter_ssh_hosts

payload_type=ARRAY
# Estimate flag
estimate=false
# Estimated processing time in between tests
default_estimated_processing_time_in_between_tests=60
estimated_processing_time_in_between_tests=$default_estimated_processing_time_in_between_tests

# Start time of the test
test_start_time=$(date +%s)
# Scenario specific counters
declare -A scenario_counter
# Scenario specific durations
declare -A scenario_duration

function get_ssh_hostname() {
    ssh -G $1 | awk '/^hostname / { print $2 }'
}

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 [-u <concurrent_users>] [-b <message_sizes>] [-s <sleep_times>] [-m <heap_sizes>] [-d <test_duration>] [-w <warmup_time>]"
    echo "   [-n <jmeter_servers>] [-j <jmeter_server_heap_size>] [-k <jmeter_client_heap_size>] [-l <netty_service_heap_size>]"
    echo "   [-i <include_scenario_name>] [-e <include_scenario_name>] [-t] [-p <estimated_processing_time_in_between_tests>] [-h]"
    echo ""
    echo "-u: Concurrent Users to test. You can give multiple options to specify multiple users. Default \"$default_concurrent_users\"."
    echo "-b: Message sizes in bytes. You can give multiple options to specify multiple message sizes. Default \"$default_message_sizes\"."
    echo "-s: Backend Sleep Times in milliseconds. You can give multiple options to specify multiple sleep times. Default \"$default_backend_sleep_times\"."
    echo "-m: Application heap memory sizes. You can give multiple options to specify multiple heap memory sizes. Default \"$default_heap_sizes\"."
    echo "-d: Test Duration in seconds. Default $default_test_duration."
    echo "-w: Warm-up time in minutes. Default $default_warmup_time."
    echo "-n: Number of JMeter servers. If n=1, only client will be used. If n > 1, remote JMeter servers will be used. Default $default_jmeter_servers."
    echo "-j: Heap Size of JMeter Server. Default $default_jmeter_server_heap_size."
    echo "-k: Heap Size of JMeter Client. Default $default_jmeter_client_heap_size."
    echo "-l: Heap Size of Netty Service. Default $default_netty_service_heap_size."
    echo "-i: Scenario name to to be included. You can give multiple options to filter scenarios."
    echo "-e: Scenario name to to be excluded. You can give multiple options to filter scenarios."
    echo "-t: Estimate time without executing tests."
    echo "-p: Estimated processing time in between tests in seconds. Default $default_estimated_processing_time_in_between_tests."
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "u:b:s:m:d:w:n:j:k:l:i:e:tp:h" opts; do
    case $opts in
    u)
        concurrent_users+=("${OPTARG}")
        ;;
    b)
        message_sizes+=("${OPTARG}")
        ;;
    s)
        backend_sleep_times+=("${OPTARG}")
        ;;
    m)
        heap_sizes+=("${OPTARG}")
        ;;
    d)
        test_duration=${OPTARG}
        ;;
    w)
        warmup_time=${OPTARG}
        ;;
    n)
        jmeter_servers=${OPTARG}
        ;;
    j)
        jmeter_server_heap_size=${OPTARG}
        ;;
    k)
        jmeter_client_heap_size=${OPTARG}
        ;;
    l)
        netty_service_heap_size=${OPTARG}
        ;;
    i)
        include_scenario_names+=("${OPTARG}")
        ;;
    e)
        exclude_scenario_names+=("${OPTARG}")
        ;;
    t)
        estimate=true
        ;;
    p)
        estimated_processing_time_in_between_tests=${OPTARG}
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

# Validate options
number_regex='^[0-9]+$'

if [[ -z $test_duration ]]; then
    echo "Please provide the test duration."
    exit 1
fi

if ! [[ $test_duration =~ $number_regex ]]; then
    echo "Test duration must be a positive number."
    exit 1
fi

if [[ -z $warmup_time ]]; then
    echo "Please provide the warmup time."
    exit 1
fi

if ! [[ $warmup_time =~ $number_regex ]]; then
    echo "Warmup time must be a positive number."
    exit 1
fi

if [[ $(($warmup_time * 60)) -ge $test_duration ]]; then
    echo "The warmup time must be less than the test duration."
    exit 1
fi

if [[ -z $jmeter_servers ]]; then
    echo "Please specify the number of JMeter servers."
    exit 1
fi

if ! [[ $jmeter_servers =~ $number_regex ]]; then
    echo "JMeter Servers must be a positive number."
    exit 1
fi

heap_regex='^[0-9]+[mg]$'

if ! [[ $jmeter_server_heap_size =~ $heap_regex ]]; then
    echo "Please specify a valid heap for JMeter Server."
    exit 1
fi

if ! [[ $jmeter_client_heap_size =~ $heap_regex ]]; then
    echo "Please specify a valid heap for JMeter Client."
    exit 1
fi

if ! [[ $netty_service_heap_size =~ $heap_regex ]]; then
    echo "Please specify a valid heap for Netty Service."
    exit 1
fi

declare -a jmeter_hosts
for ((c = 1; c <= $jmeter_servers; c++)); do
    jmeter_ssh_hosts+=("jmeter$c")
    jmeter_hosts+=($(get_ssh_hostname jmeter$c))
done

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
        echo "WARN: File transfer failed!"
    fi
}

function record_scenario_duration() {
    local scenario_name="$1"
    local duration="$2"
    # Increment counter
    local current_scenario_counter="${scenario_counter[$scenario_name]}"
    if [[ ! -z $current_scenario_counter ]]; then
        scenario_counter[$scenario_name]=$(echo "$current_scenario_counter+1" | bc)
    else
        # Initialize counter
        scenario_counter[$scenario_name]=1
    fi
    # Save duration
    current_scenario_duration="${scenario_duration[$scenario_name]}"
    if [[ ! -z $current_scenario_duration ]]; then
        scenario_duration[$scenario_name]=$(echo "$current_scenario_duration+$duration" | bc)
    else
        # Initialize counter
        scenario_duration[$scenario_name]="$duration"
    fi
}

function print_durations() {
    local time_header=""
    if [ "$estimate" = true ]; then
        time_header="Estimated"
    else
        time_header="Actual"
    fi

    echo "$time_header execution times:"
    local sorted_names=($(
        for name in "${!scenario_counter[@]}"; do
            echo "$name"
        done | sort
    ))
    if [[ ${#sorted_names[@]} -gt 0 ]]; then
        # Count scenarios
        local total_counter=0
        local total_duration=0
        printf "%-40s  %20s  %50s\n" "Scenario" "Combination(s)" "$time_header Time"
        for name in "${sorted_names[@]}"; do
            let total_counter=total_counter+${scenario_counter[$name]}
            let total_duration=total_duration+${scenario_duration[$name]}
            printf "%-40s  %20s  %50s\n" "$name" "${scenario_counter[$name]}" "$(format_time ${scenario_duration[$name]})"
        done
        printf "%40s  %20s  %50s\n" "Total" "$total_counter" "$(format_time $total_duration)"
    else
        echo "WARNING: There were no scenarios to test."
    fi
    printf "Script execution time: %s\n" "$(format_time $(measure_time $test_start_time))"
}

function initiailize_test() {
    # Filter scenarios
    if [[ ${#include_scenario_names[@]} -gt 0 ]] || [[ ${#exclude_scenario_names[@]} -gt 0 ]]; then
        declare -n scenario
        for scenario in ${!test_scenario@}; do
            scenario[skip]=true
            for name in ${include_scenario_names[@]}; do
                if [[ ${scenario[name]} =~ $name ]]; then
                    scenario[skip]=false
                fi
            done
            for name in ${exclude_scenario_names[@]}; do
                if [[ ${scenario[name]} =~ $name ]]; then
                    scenario[skip]=true
                fi
            done
        done
    fi

    if [ "$estimate" = false ]; then
        jmeter_dir=""
        for dir in $HOME/apache-jmeter*; do
            [ -d "${dir}" ] && jmeter_dir="${dir}" && break
        done
        if [[ -d $jmeter_dir ]]; then
            export JMETER_HOME="${jmeter_dir}"
            export PATH=$JMETER_HOME/bin:$PATH
        else
            echo "WARNING: Could not find JMeter directory."
        fi

        if [[ -d results ]]; then
            echo "Results directory already exists. Please backup."
            exit 1
        fi
        if [[ -f results.zip ]]; then
            echo "The results.zip file already exists. Please backup."
            exit 1
        fi
        mkdir results
        cp $0 results

        declare -a message_sizes_array
        if [ ${#message_sizes[@]} -eq 0 ]; then
            message_sizes_array+=($default_message_sizes)
        else
            message_sizes_array+=("${message_sizes[@]}")
        fi
        declare -a payload_sizes
        for msize in ${message_sizes_array[@]}; do
            payload_sizes+=("-s" "$msize")
        done

        if [[ $jmeter_servers -gt 1 ]]; then
            for jmeter_ssh_host in ${jmeter_ssh_hosts[@]}; do
                echo "Generating Payloads in $jmeter_ssh_host"
                ssh $jmeter_ssh_host "./payloads/generate-payloads.sh" -p $payload_type ${payload_sizes[@]}
            done
        else
            pushd $HOME
            # Payloads should be created in the $HOME directory
            ./payloads/generate-payloads.sh -p $payload_type ${payload_sizes[@]}
            popd
        fi
    fi
}

function exit_handler() {
    if [[ "$estimate" == false ]] && [[ -d results ]]; then
        echo "Zipping results directory..."
        zip -9qr results.zip results/
    fi
    print_durations
}

trap exit_handler EXIT

function test_scenarios() {
    initiailize_test
    declare -a heap_sizes_array
    if [ ${#heap_sizes[@]} -eq 0 ]; then
        heap_sizes_array+=($default_heap_sizes)
    else
        heap_sizes_array+=("${heap_sizes[@]}")
    fi
    declare -a concurrent_users_array
    if [ ${#concurrent_users[@]} -eq 0 ]; then
        concurrent_users_array+=($default_concurrent_users)
    else
        concurrent_users_array+=("${concurrent_users[@]}")
    fi
    declare -a message_sizes_array
    if [ ${#message_sizes[@]} -eq 0 ]; then
        message_sizes_array+=($default_message_sizes)
    else
        message_sizes_array+=("${message_sizes[@]}")
    fi
    declare -a backend_sleep_times_array
    if [ ${#backend_sleep_times[@]} -eq 0 ]; then
        backend_sleep_times_array+=($default_backend_sleep_times)
    else
        backend_sleep_times_array+=("${backend_sleep_times[@]}")
    fi
    for heap in ${heap_sizes_array[@]}; do
        declare -ng scenario
        for scenario in ${!test_scenario@}; do
            local skip=${scenario[skip]}
            if [ $skip = true ]; then
                continue
            fi
            local scenario_name=${scenario[name]}
            local jmx_file=${scenario[jmx]}
            declare -a sleep_times_array
            if [ ${scenario[use_backend]} = true ]; then
                sleep_times_array=("${backend_sleep_times_array[@]}")
            else
                sleep_times_array=("-1")
            fi
            for users in ${concurrent_users_array[@]}; do
                for msize in ${message_sizes_array[@]}; do
                    for sleep_time in ${sleep_times_array[@]}; do
                        if [ "$estimate" = true ]; then
                            record_scenario_duration $scenario_name $(($test_duration + $estimated_processing_time_in_between_tests))
                            continue
                        fi
                        local start_time=$(date +%s)
                        #requests served by multiple jmeter servers if $jmeter_servers > 1
                        local total_users=$(($users * $jmeter_servers))

                        local scenario_desc="Scenario Name: ${scenario_name}, Duration: $test_duration"
                        scenario_desc+=", Concurrent Users ${total_users}, Msg Size: ${msize}, Sleep Time: ${sleep_time}"
                        echo -n "# Starting the performance test."
                        echo " $scenario_desc"

                        report_location=$PWD/results/${scenario_name}/${heap}_heap/${total_users}_users/${msize}B/${sleep_time}ms_sleep

                        echo "Report location is ${report_location}"
                        mkdir -p $report_location

                        if [[ $sleep_time -ge 0 ]]; then
                            echo "Starting Backend Service. Sleep Time: $sleep_time"
                            ssh $backend_ssh_host "./netty-service/netty-start.sh -m $netty_service_heap_size -w \
                                -- --worker-threads $total_users --sleep-time $sleep_time"
                        fi

                        declare -ag jmeter_params=("users=$users" "duration=$test_duration")

                        before_execute_test_scenario

                        if [[ $jmeter_servers -gt 1 ]]; then
                            echo "Starting Remote JMeter servers"
                            for ix in ${!jmeter_ssh_hosts[@]}; do
                                echo "Starting Remote JMeter server. SSH Host: ${jmeter_ssh_hosts[ix]}, IP: ${jmeter_hosts[ix]}, Path: $HOME, Heap: $jmeter_server_heap_size"
                                ssh ${jmeter_ssh_hosts[ix]} "./jmeter/jmeter-server-start.sh -n ${jmeter_hosts[ix]} -i $HOME -m $jmeter_server_heap_size -- $JMETER_JVM_ARGS"
                            done
                        fi

                        export JVM_ARGS="-Xms$jmeter_client_heap_size -Xmx$jmeter_client_heap_size -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:$report_location/jmeter_gc.log $JMETER_JVM_ARGS"

                        local jmeter_command="jmeter -n -t $script_dir/${jmx_file} $jmeter_remote_args"
                        if [[ $jmeter_servers -gt 1 ]]; then
                            jmeter_command+=" -R $(
                                IFS=","
                                echo "${jmeter_hosts[*]}"
                            ) -X"
                            for param in ${jmeter_params[@]}; do
                                jmeter_command+=" -G$param"
                            done
                        else
                            for param in ${jmeter_params[@]}; do
                                jmeter_command+=" -J$param"
                            done
                        fi
                        jmeter_command+=" -l ${report_location}/results.jtl"

                        echo "Starting JMeter Client with JVM_ARGS=$JVM_ARGS"
                        echo "$jmeter_command"
                        # Run JMeter
                        $jmeter_command

                        write_server_metrics jmeter
                        write_server_metrics netty $backend_ssh_host netty
                        write_server_metrics jmeter1 $jmeter1_ssh_host
                        write_server_metrics jmeter2 $jmeter2_ssh_host

                        $HOME/jtl-splitter/jtl-splitter.sh -- -f ${report_location}/results.jtl -t $warmup_time -s

                        echo "Zipping JTL files in ${report_location}"
                        zip -jm ${report_location}/jtls.zip ${report_location}/results*.jtl

                        if [[ $sleep_time -ge 0 ]]; then
                            download_file $backend_ssh_host netty-service/logs/netty.log netty.log
                            download_file $backend_ssh_host netty-service/logs/nettygc.log netty_gc.log
                        fi
                        if [[ $jmeter_servers -gt 1 ]]; then
                            for jmeter_ssh_host in ${jmeter_ssh_hosts[@]}; do
                                download_file $jmeter_ssh_host jmetergc.log ${jmeter_ssh_host}_gc.log
                            done
                        fi

                        after_execute_test_scenario

                        local current_execution_duration="$(measure_time $start_time)"
                        echo -n "# Completed the performance test."
                        echo " $scenario_desc"
                        echo -e "Test execution time: $(format_time $current_execution_duration)\n"
                        record_scenario_duration $scenario_name $current_execution_duration
                    done
                done
            done
        done
    done
}
