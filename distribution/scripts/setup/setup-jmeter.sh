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
# Setup JMeter Client
# ----------------------------------------------------------------------------

# Make sure the script is running as root.
if [ "$UID" -ne "0" ]; then
    echo "You must be root to run $0. Try following"
    echo "sudo $0"
    exit 9
fi

export script_name="$0"
export script_dir=$(dirname "$0")
export installation_dir=""

declare -a jmeter_plugins_array

function usageCommand() {
    echo "-i <installation_dir> [-j <jmeter_plugin>]"
}
export -f usageCommand

function usageHelp() {
    echo "-i: The JMeter installation directory."
    echo "-j: The JMeter plugin name. You can give multiple JMeter plugins to install."
}
export -f usageHelp

while getopts "gp:w:o:hi:j:" opt; do
    case "${opt}" in
    i)
        installation_dir=${OPTARG}
        ;;
    j)
        jmeter_plugins_array+=("-p" "${OPTARG}")
        ;;
    *)
        opts+=("-${opt}")
        [[ -n "$OPTARG" ]] && opts+=("$OPTARG")
        ;;
    esac
done
shift "$((OPTIND - 1))"

function validate() {
    if [[ ! -d $installation_dir ]]; then
        echo "Please provide the JMeter installation directory."
        exit 1
    fi
}
export -f validate

# Bash does not support exporting arrays
export jmeter_plugins="${jmeter_plugins_array[*]}"

function setup() {
    declare -a jmeter_plugins_array=($jmeter_plugins)
    echo "Setting up JMeter in $installation_dir"
    $script_dir/../jmeter/install-jmeter.sh -d -i $installation_dir "${jmeter_plugins_array[@]}"
}
export -f setup

$script_dir/setup-common.sh "${opts[@]}" "$@" -p openjdk-8-jdk -p zip -p jq
