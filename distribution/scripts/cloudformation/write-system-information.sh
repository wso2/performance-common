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
# Write system information to files
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")
default_output_directory="$PWD"
output_directory="$default_output_directory"

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 -o [<output_directory>] [-h]"
    echo ""
    echo "-o: Directory to store system information files. Default: $default_output_directory"
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "o:h" opt; do
    case "${opt}" in
    o)
        output_directory=${OPTARG}
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

if [[ ! -d $output_directory ]]; then
    echo "Please provide output directory."
    exit 1
fi

function command_exists() {
    command -v $1 >/dev/null 2>&1
}

# Collect system information
system_info_json=""

function add_json_object() {
    local class="$1"
    local subclass="$2"
    local description="$3"
    local value="$4"
    local json_string='{class: $class, subclass: $subclass, description: $description, value: $value}'
    system_info_json+=$(jq -n --arg class "$class" --arg subclass "$subclass" \
        --arg description "$description" --arg value "$value" \
        "$json_string")
}

function remove_quotes() {
    local var="$*"
    var="${var#\"}"
    var="${var%\"}"
    echo -n "$var"
}

function get_value() {
    local file="$1"
    local key="$2"
    local separator="$3"
    match="$(grep "^$key" $file)"
    echo $(remove_quotes ${match##*$separator})
}

if command_exists ec2metadata; then
    ec2metadata >$output_directory/ec2metadata.txt 2>&1
    add_json_object "AWS" "EC2" "AMI-ID" "$(get_value $output_directory/ec2metadata.txt 'ami-id' :)"
    add_json_object "AWS" "EC2" "Instance Type" "$(get_value $output_directory/ec2metadata.txt 'instance-type' :)"
fi

if command_exists lscpu; then
    lscpu >$output_directory/lscpu.txt 2>&1
    add_json_object "System" "Processor" "CPU(s)" "$(get_value $output_directory/lscpu.txt 'CPU(s)' :)"
    add_json_object "System" "Processor" "Thread(s) per core" "$(get_value $output_directory/lscpu.txt 'Thread(s) per core' :)"
    add_json_object "System" "Processor" "Core(s) per socket" "$(get_value $output_directory/lscpu.txt 'Core(s) per socket' :)"
    add_json_object "System" "Processor" "Socket(s)" "$(get_value $output_directory/lscpu.txt 'Socket(s)' :)"
    add_json_object "System" "Processor" "Model name" "$(get_value $output_directory/lscpu.txt 'Model name' :)"
fi

if command_exists lshw; then
    lshw >$output_directory/lshw.txt 2>&1
    lshw -short >$output_directory/lshw-short.txt 2>&1
    lshw -json >$output_directory/lshw.json 2>/dev/null
    while IFS=',' read id description size units capabilities; do
        description="$(remove_quotes $description)"
        units="$(remove_quotes $units)"
        capabilities="$(remove_quotes $capabilities)"

        value=""
        if [[ $units == bytes ]]; then
            one_kib=1024
            one_mib=$(bc <<<"scale=0; 1024*1024")
            one_gib=$(bc <<<"scale=0; 1024*1024*1024")
            if [[ $size -gt $one_gib && $(bc <<<"scale=0; ${size}%${one_gib}") -eq 0 ]]; then
                size=$(bc <<<"scale=0; ${size}/${one_gib}")
                units=GiB
            elif [[ $size -gt $one_mib && $(bc <<<"scale=0; ${size}%${one_mib}") -eq 0 ]]; then
                size=$(bc <<<"scale=0; ${size}/${one_mib}")
                units=MiB
            elif [[ $size -gt $one_kib && $(bc <<<"scale=0; ${size}%${one_kib}") -eq 0 ]]; then
                size=$(bc <<<"scale=0; ${size}/${one_kib}")
                units=KiB
            fi
            value="$size $units"
        else
            value="$size $units"
        fi
        if [[ ! -z $capabilities ]]; then
            value+=" ($capabilities)"
        fi
        add_json_object "System" "Memory" "$description" "$value"
    done <<<$(jq -r '.children[] | select(.id=="core") | .children[] | select(.class=="memory") | [.id,.description,.size,.units,.capabilities.data // .capabilities.instruction] | @csv' $output_directory/lshw.json)
fi

if command_exists lsblk; then
    lsblk >$output_directory/lsblk.txt 2>&1
    lsblk -J >$output_directory/lsblk.json 2>&1
    while IFS=',' read name size; do
        name="$(remove_quotes $name)"
        size="$(remove_quotes $size)"
        description="Block Device: $name"
        add_json_object "System" "Storage" "$description" "$size"
    done <<<$(jq -r  '.blockdevices[] | select(.type=="disk") | [.name,.size] | @csv' $output_directory/lsblk.json)
fi

if ls /etc/*release* 1>/dev/null 2>&1; then
    cat /etc/*release* >$output_directory/release-info.txt 2>&1
    add_json_object "Operating System" "Distribution" "Release" "$(get_value $output_directory/release-info.txt DISTRIB_DESCRIPTION =)"
fi

if command_exists uname; then
    uname -a >$output_directory/kernel.txt 2>&1
    add_json_object "Operating System" "Distribution" "Kernel" "$(cat $output_directory/kernel.txt)"
fi

jq -s '{system_info: .}' <<<"$system_info_json" >$output_directory/system-info.json
