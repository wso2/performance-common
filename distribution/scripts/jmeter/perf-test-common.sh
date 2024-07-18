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
#     [display_name]="Test Scenario 1"
#     [description]="Description of Test Scenario 1"
#     [jmx]="test_scenario_name1.jmx"
#     [use_backend]=true
#     [skip]=false
# )
# declare -A test_scenario1=(
#     [name]="test_scenario_name2"
#     [display_name]="Test Scenario 2"
#     [description]="Description of Test Scenario 2"
#     [jmx]="test_scenario_name2.jmx"
#     [use_backend]=true
#     [skip]=false
# )
#
# Then define following functions in the script
# 1. initialize
# 2. before_execute_test_scenario
# 3. after_execute_test_scenario
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

# Source common script
script_dir=$(dirname "$0")
. $script_dir/../common/common.sh

# Application heap Sizes
declare -a heap_sizes_array
# Concurrent users (will be divided among JMeter servers)
declare -a concurrent_users_array
# Message Sizes
declare -a message_sizes_array
# Common backend sleep times (in milliseconds).
declare -a backend_sleep_times_array

# Message Iterations
declare -a message_iteratations_array

#--cpus option for docker
default_cpus=1
cpus=$default_cpus

# Test Duration in seconds
default_test_duration=900
test_duration=$default_test_duration
# Warm-up time in seconds
default_warmup_time=300
warmup_time=$default_warmup_time
# Heap size of JMeter Client
default_jmeter_client_heap_size=2G
jmeter_client_heap_size=$default_jmeter_client_heap_size
# Heap size of JMeter Server
default_jmeter_server_heap_size=4G
jmeter_server_heap_size=$default_jmeter_server_heap_size

# Heap size of Netty Service
default_netty_service_heap_size=4G
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

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 -m <heap_sizes> -u <concurrent_users> -b <message_sizes> -s <sleep_times>"
    if function_exists usageCommand; then
        echo "   $(usageCommand)"
    fi
    echo "   [-d <test_duration>] [-w <warmup_time>]"
    echo "   [-n <jmeter_servers>] [-j <jmeter_server_heap_size>] [-k <jmeter_client_heap_size>] [-l <netty_service_heap_size>]"
    echo "   [-i <include_scenario_name>] [-e <include_scenario_name>] [-t] [-p <estimated_processing_time_in_between_tests>] [-h]"
    echo ""
    echo "-m: Application heap memory sizes. You can give multiple options to specify multiple heap memory sizes. Allowed suffixes: M, G."
    echo "-u: Concurrent Users to test. You can give multiple options to specify multiple users."
    echo "-b: Message sizes in bytes. You can give multiple options to specify multiple message sizes."
    echo "-q: Message Iterations"
    echo "-s: Backend Sleep Times in milliseconds. You can give multiple options to specify multiple sleep times."
    if function_exists usageHelp; then
        echo "$(usageHelp)"
    fi
    echo "-d: Test Duration in seconds. Default $default_test_duration."
    echo "-w: Warm-up time in seconds. Default $default_warmup_time."
    echo "-n: Number of JMeter servers. If n=1, only client will be used. If n > 1, remote JMeter servers will be used. Default $default_jmeter_servers."
    echo "-j: Heap Size of JMeter Server. Allowed suffixes: M, G. Default $default_jmeter_server_heap_size."
    echo "-k: Heap Size of JMeter Client. Allowed suffixes: M, G. Default $default_jmeter_client_heap_size."
    echo "-l: Heap Size of Netty Service. Allowed suffixes: M, G. Default $default_netty_service_heap_size."
    echo "-i: Scenario name to to be included. You can give multiple options to filter scenarios."
    echo "-e: Scenario name to to be excluded. You can give multiple options to filter scenarios."
    echo "-t: Estimate time without executing tests."
    echo "-p: Estimated processing time in between tests in seconds. Default $default_estimated_processing_time_in_between_tests."
    echo "-c: --cpus option for the the docker container. Default $default_cpus"
    echo "-h: Display this help and exit."
    echo ""
}

# Reset getopts
OPTIND=0
while getopts "u:b:q:s:m:c:d:w:n:j:k:l:i:e:tp:h" opts; do
    case $opts in
    u)
        concurrent_users_array+=("${OPTARG}")
        ;;
    b)
        message_sizes_array+=("${OPTARG}")
        ;;
    q)
        message_iteratations_array+=("${OPTARG}")
        ;;
    s)
        backend_sleep_times_array+=("${OPTARG}")
        ;;
    m)
        heap_sizes_array+=("${OPTARG}")
        ;;
    c)
        cpus=${OPTARG}
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
float_number_regex="^[0-9]+\.?[0-9]*$"
heap_regex='^[0-9]+[MG]$'

if [ ${#heap_sizes_array[@]} -eq 0 ]; then
    echo "Please provide application heap memory sizes."
    exit 1
fi

if [ ${#concurrent_users_array[@]} -eq 0 ]; then
    echo "Please provide concurrent users to test."
    exit 1
fi

if [ ${#message_sizes_array[@]} -eq 0 ]; then
    echo "Please provide message sizes."
    exit 1
fi

if [ ${#backend_sleep_times_array[@]} -eq 0 ]; then
    echo "Please provide backend sleep rimes."
    exit 1
fi

if function_exists validate; then
    validate
fi

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

if [[ $warmup_time -ge $test_duration ]]; then
    echo "The warmup time must be less than the test duration."
    exit 1
fi

for heap in ${heap_sizes_array[@]}; do
    if ! [[ $heap =~ $heap_regex ]]; then
        echo "Please specify a valid heap size for the application."
        exit 1
    fi
done

if ! [[ $cpus =~ $float_number_regex ]]; then
    echo "cpus must be a positive floating/int number."
    exit 1
fi

for users in ${concurrent_users_array[@]}; do
    if ! [[ $users =~ $number_regex ]]; then
        echo "Please specify a valid number for concurrent users."
        exit 1
    fi
done

for msize in ${message_sizes_array[@]}; do
    if ! [[ $msize =~ $number_regex ]]; then
        echo "Please specify a valid number for message size."
        exit 1
    fi
done

for iteration in ${message_iteratations_array[@]}; do
    if ! [[ $iteration =~ $number_regex ]]; then
        echo "Please specify a valid number for message iterations."
        exit 1
    fi
done

for sleep_time in ${backend_sleep_times_array[@]}; do
    if ! [[ $sleep_time =~ $number_regex ]]; then
        echo "Please specify a valid number for backend sleep time."
        exit 1
    fi
done

if [[ -z $jmeter_servers ]]; then
    echo "Please specify the number of JMeter servers."
    exit 1
fi

if ! [[ $jmeter_servers =~ $number_regex ]]; then
    echo "JMeter Servers must be a positive number."
    exit 1
fi

for users in ${concurrent_users_array[@]}; do
    remainder=$(bc <<<"scale=0; ${users}%${jmeter_servers}")
    if ! [[ $remainder -eq 0 ]]; then
        echo "Unable to split $users users into $jmeter_servers JMeter servers."
        exit 1
    fi
done

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
    # Count scenarios
    local total_counter=0
    local total_duration=0
    if [[ ${#sorted_names[@]} -gt 0 ]]; then
        printf "%-40s  %20s  %50s\n" "Scenario" "Combination(s)" "$time_header Time"
        for name in "${sorted_names[@]}"; do
            let total_counter=total_counter+${scenario_counter[$name]}
            let total_duration=total_duration+${scenario_duration[$name]}
            printf "%-40s  %20s  %50s\n" "$name" "${scenario_counter[$name]}" "$(format_time ${scenario_duration[$name]})"
        done
        printf "%40s  %20s  %50s\n" "Total" "$total_counter" "$(format_time $total_duration)"
    else
        echo "WARNING: None of the test scenarios were executed."
        exit 1
    fi
    local test_total_duration_json='.'
    test_total_duration_json+=' | .["test_scenarios"]=$test_scenarios'
    test_total_duration_json+=' | .["total_duration"]=$total_duration'
    jq -n \
        --arg test_scenarios "$total_counter" \
        --arg total_duration "$total_duration" \
        "$test_total_duration_json" >test-duration.json
    printf "Script execution time: %s\n" "$(format_time $(measure_time $test_start_time))"
}

function initialize_test() {
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

    # Save test metadata
    declare -n scenario
    local all_scenarios=""
    for scenario in ${!test_scenario@}; do
        local skip=${scenario[skip]}
        if [ $skip = true ]; then
            continue
        fi
        all_scenarios+=$(jq -n \
            --arg name "${scenario[name]}" \
            --arg display_name "${scenario[display_name]}" \
            --arg description "${scenario[description]}" \
            --arg jmx "${scenario[jmx]}" \
            --arg use_backend "${scenario[use_backend]}" \
            '. | .["name"]=$name | .["display_name"]=$display_name | .["description"]=$description | .["jmx"]=$jmx | .["use_backend"]=$use_backend')
    done

    local test_parameters_json='.'
    test_parameters_json+=' | .["test_duration"]=$test_duration'
    test_parameters_json+=' | .["warmup_time"]=$warmup_time'
    test_parameters_json+=' | .["jmeter_servers"]=$jmeter_servers'
    test_parameters_json+=' | .["jmeter_client_heap_size"]=$jmeter_client_heap_size'
    test_parameters_json+=' | .["jmeter_server_heap_size"]=$jmeter_server_heap_size'
    test_parameters_json+=' | .["netty_service_heap_size"]=$netty_service_heap_size'
    test_parameters_json+=' | .["test_scenarios"]=$test_scenarios'
    test_parameters_json+=' | .["heap_sizes"]=$heap_sizes | .["concurrent_users"]=$concurrent_users'
    test_parameters_json+=' | .["message_sizes"]=$message_sizes | .["backend_sleep_times"]=$backend_sleep_times'
    test_parameters_json+=' | .["iteration_elements"]=$iteration_elements'
    jq -n \
        --arg test_duration "$test_duration" \
        --arg warmup_time "$warmup_time" \
        --arg jmeter_servers "$jmeter_servers" \
        --arg jmeter_client_heap_size "$jmeter_client_heap_size" \
        --arg jmeter_server_heap_size "$jmeter_server_heap_size" \
        --arg netty_service_heap_size "$netty_service_heap_size" \
        --argjson test_scenarios "$(echo "$all_scenarios" | jq -s '.')" \
        --argjson heap_sizes "$(printf '%s\n' "${heap_sizes_array[@]}" | jq -nR '[inputs]')" \
        --argjson concurrent_users "$(printf '%s\n' "${concurrent_users_array[@]}" | jq -nR '[inputs]')" \
        --argjson message_sizes "$(printf '%s\n' "${message_sizes_array[@]}" | jq -nR '[inputs]')" \
        --argjson iteration_elements "$(printf '%s\n' "${message_iteratations_array[@]}" | jq -nR '[inputs]')" \
        --argjson backend_sleep_times "$(printf '%s\n' "${backend_sleep_times_array[@]}" | jq -nR '[inputs]')" \
        "$test_parameters_json" >test-metadata.json

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
        cp $0 results/
        mv test-metadata.json results/

        declare -a payload_sizes
        for msize in ${message_sizes_array[@]}; do
            payload_sizes+=("-s" "$msize")
        done

        if [[ $jmeter_servers -gt 1 ]]; then
            for jmeter_ssh_host in ${jmeter_ssh_hosts[@]}; do
                echo "Generating Payloads in $jmeter_ssh_host"
                ssh $jmeter_ssh_host "/home/ubuntu/ballerina-performance-distribution-1.1.1-SNAPSHOT/payloads/generate-payloads.sh" -p $payload_type ${payload_sizes[@]}
            done
        else
            pushd $HOME
            # Payloads should be created in the $HOME directory
            if ! /home/ubuntu/ballerina-performance-distribution-1.1.1-SNAPSHOT/payloads/generate-payloads.sh -p $payload_type ${payload_sizes[@]}; then
                echo "WARNING: Failed to generate payloads!"
            fi
            popd
        fi

        if declare -F initialize >/dev/null 2>&1; then
            initialize
        fi
    fi
}

function exit_handler() {
    if [[ "$estimate" == false ]] && [[ -d results ]]; then
        echo "Zipping results directory..."
        # Create zip file without JTLs first (in case of limited disc space)
        zip -9qr results-without-jtls.zip results/ -x '*jtls.zip'
        zip -9qr results.zip results/
    fi
    print_durations
}

trap exit_handler EXIT

function test_scenarios() {
    initialize_test
    local test_counter=0
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
                        local users_per_jmeter=$(bc <<<"scale=0; ${users}/${jmeter_servers}")

                        test_counter=$((test_counter + 1))
                        local scenario_desc="Test No: ${test_counter}, Scenario Name: ${scenario_name}, Duration: $test_duration"
                        scenario_desc+=", Concurrent Users ${users}, Msg Size: ${msize}, Sleep Time: ${sleep_time}"
                        echo -n "# Starting the performance test."
                        echo " $scenario_desc"

                        report_location=$PWD/results/${scenario_name}/${heap}_heap/${users}_users/${msize}B/${sleep_time}ms_sleep

                        echo "Report location is ${report_location}"
                        mkdir -p $report_location

                        if [[ $sleep_time -ge 0 ]]; then
                            local backend_flags="${scenario[backend_flags]}"
                            echo "Starting Backend Service. Delay: $sleep_time, Additional Flags: ${backend_flags:-N/A}"
                            ssh $backend_ssh_host "/home/ubuntu/ballerina-performance-distribution-1.1.1-SNAPSHOT/netty-service/netty-start.sh -m $netty_service_heap_size -w \
                                -- ${backend_flags} --delay $sleep_time"
                            collect_server_metrics netty $backend_ssh_host netty
                        fi

                        declare -ag jmeter_params=("users=$users_per_jmeter" "duration=$test_duration")

                        before_execute_test_scenario

                        if [[ $jmeter_servers -gt 1 ]]; then
                            echo "Starting Remote JMeter servers"
                            for ix in ${!jmeter_ssh_hosts[@]}; do
                                echo "Starting Remote JMeter server. SSH Host: ${jmeter_ssh_hosts[ix]}, IP: ${jmeter_hosts[ix]}, Path: $HOME, Heap: $jmeter_server_heap_size"
                                ssh ${jmeter_ssh_hosts[ix]} "/home/ubuntu/ballerina-performance-distribution-1.1.1-SNAPSHOT/jmeter/jmeter-server-start.sh -n ${jmeter_hosts[ix]} -i $HOME -m $jmeter_server_heap_size -- $JMETER_JVM_ARGS"
                                collect_server_metrics ${jmeter_ssh_hosts[ix]} ${jmeter_ssh_hosts[ix]} ApacheJMeter.jar
                            done
                        fi

                        export JVM_ARGS="-Xms$jmeter_client_heap_size -Xmx$jmeter_client_heap_size -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:$report_location/jmeter_gc.log $JMETER_JVM_ARGS"

                        local jmeter_command="jmeter -n -t $script_dir/${jmx_file} -j $report_location/jmeter.log $jmeter_remote_args"
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

                        # Start timestamp
                        test_start_timestamp=$(date +%s)
                        echo "Start timestamp: $test_start_timestamp"
                        # Run JMeter in background
                        $jmeter_command &
                        collect_server_metrics jmeter ApacheJMeter.jar
                        local jmeter_pid="$!"
                        if ! wait $jmeter_pid; then
                            echo "WARNING: JMeter execution failed."
                        fi
                        # End timestamp
                        test_end_timestamp="$(date +%s)"
                        echo "End timestamp: $test_end_timestamp"

                        local test_duration_file="${report_location}/test_duration.json"
                        if jq -n --arg start_timestamp "$test_start_timestamp" \
                            --arg end_timestamp "$test_end_timestamp" \
                            --arg test_duration "$(($test_end_timestamp - $test_start_timestamp))" \
                            '. | .["start_timestamp"]=$start_timestamp | .["end_timestamp"]=$end_timestamp | .["test_duration"]=$test_duration' >$test_duration_file; then
                            echo "Wrote test start timestamp, end timestamp and test duration to $test_duration_file."
                        fi

                        write_server_metrics jmeter ApacheJMeter.jar
                        if [[ $jmeter_servers -gt 1 ]]; then
                            for jmeter_ssh_host in ${jmeter_ssh_hosts[@]}; do
                                write_server_metrics $jmeter_ssh_host $jmeter_ssh_host ApacheJMeter.jar
                            done
                        fi
                        if [[ $sleep_time -ge 0 ]]; then
                            write_server_metrics netty $backend_ssh_host netty
                        fi

                        if [[ -f ${report_location}/results.jtl ]]; then
                            # Delete the original JTL file to save space.
                            # Can merge files using the command: awk 'FNR==1 && NR!=1{next;}{print}'
                            # However, the merged file may not be same as original and that should be okay
                            /home/ubuntu/ballerina-performance-distribution-1.1.1-SNAPSHOT/jtl-splitter/jtl-splitter.sh -- -f ${report_location}/results.jtl -d -t $warmup_time -u SECONDS -s
                            echo "Zipping JTL files in ${report_location}"
                            zip -jm ${report_location}/jtls.zip ${report_location}/results*.jtl
                        fi

                        if [[ $sleep_time -ge 0 ]]; then
                            download_file $backend_ssh_host netty-service/logs/netty.log netty.log
                            download_file $backend_ssh_host netty-service/logs/nettygc.log netty_gc.log
                        fi
                        if [[ $jmeter_servers -gt 1 ]]; then
                            for jmeter_ssh_host in ${jmeter_ssh_hosts[@]}; do
                                download_file $jmeter_ssh_host jmetergc.log ${jmeter_ssh_host}_gc.log
                                download_file $jmeter_ssh_host server.out ${jmeter_ssh_host}_server.out
                                download_file $jmeter_ssh_host jmeter-server.log ${jmeter_ssh_host}_server.log
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
