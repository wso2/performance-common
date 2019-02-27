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
# Setup JMeter
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
export jmeter_dist=""
export oracle_jdk_dist=""

declare -a jmeter_plugins_array

function usageCommand() {
    echo "-i <installation_dir> -f <jmeter_dist> -d <oracle_jdk_dist> [-j <jmeter_plugin>]"
}
export -f usageCommand

function usageHelp() {
    echo "-i: Apache JMeter installation directory."
    echo "-f: Apache JMeter tgz distribution."
    echo "-d: Oracle JDK distribution. (If not provided, OpenJDK will be installed)"
    echo "-j: Apache JMeter plugin name. You can give multiple JMeter plugins to install."
}
export -f usageHelp

while getopts "gp:w:o:hi:f:d:j:" opt; do
    case "${opt}" in
    i)
        installation_dir=${OPTARG}
        ;;
    f)
        jmeter_dist=${OPTARG}
        ;;
    d)
        oracle_jdk_dist=${OPTARG}
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
    if [[ ! -f $jmeter_dist ]]; then
        echo "Please specify the JMeter distribution file (*.tgz)"
        exit 1
    fi
    if [[ ! $jmeter_dist =~ ^.*\.tgz$ ]]; then
        echo "Please provide the JMeter tgz distribution file (*.tgz)"
        exit 1
    fi
}
export -f validate

# Bash does not support exporting arrays
export jmeter_plugins="${jmeter_plugins_array[*]}"

function setup() {
    declare -a jmeter_plugins_array=($jmeter_plugins)

    if [[ -f $oracle_jdk_dist ]]; then
        echo "Installing Oracle JDK from $oracle_jdk_dist"
        $script_dir/../java/install-java.sh -f $oracle_jdk_dist
    fi

    echo "Setting up JMeter in $installation_dir"
    $script_dir/../jmeter/install-jmeter.sh -f $jmeter_dist -i $installation_dir "${jmeter_plugins_array[@]}" -p bzm-http2
}
export -f setup

if [[ ! -f $oracle_jdk_dist ]]; then
    SETUP_COMMON_ARGS+="-p openjdk-8-jdk"
fi

alpnboot_dir="/opt/alpnboot"
mkdir -p $alpnboot_dir

$script_dir/setup-common.sh "${opts[@]}" "$@" $SETUP_COMMON_ARGS -p zip -p unzip -p jq \
    -w http://search.maven.org/remotecontent?filepath=org/mortbay/jetty/alpn/alpn-boot/8.1.13.v20181017/alpn-boot-8.1.13.v20181017.jar \
    -o $alpnboot_dir/alpnboot.jar
