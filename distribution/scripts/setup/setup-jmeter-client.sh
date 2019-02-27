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
export key_file=""
export script_dir=$(dirname "$0")
export installation_dir=""
export jmeter_dist=""
export oracle_jdk_dist=""
export ssh_config_location=""

declare -a ssh_aliases_array
declare -a ssh_hostnames_array
declare -a jmeter_plugins_array

function usageCommand() {
    echo "-k <key_file> -i <installation_dir> -f <jmeter_dist> -d <oracle_jdk_dist> -c <ssh_config_location> -a <ssh_alias> -n <ssh_hostname> [-j <jmeter_plugin>]"
}
export -f usageCommand

function usageHelp() {
    echo "-k: The key file location."
    echo "-i: The JMeter installation directory."
    echo "-f: Apache JMeter tgz distribution."
    echo "-d: Oracle JDK distribution. (If not provided, OpenJDK will be installed)"
    echo "-c: The SSH config location."
    echo "-a: SSH Alias. You can give multiple ssh aliases."
    echo "-n: SSH Hostname. You can give multiple ssh hostnames for a given set of ssh aliases."
    echo "-j: The JMeter plugin name. You can give multiple JMeter plugins to install."
}
export -f usageHelp

while getopts "gp:w:o:hk:i:f:d:c:a:n:j:" opt; do
    case "${opt}" in
    k)
        key_file=${OPTARG}
        ;;
    i)
        installation_dir=${OPTARG}
        ;;
    f)
        jmeter_dist=${OPTARG}
        ;;
    d)
        oracle_jdk_dist=${OPTARG}
        ;;
    c)
        ssh_config_location=${OPTARG}
        ;;
    a)
        ssh_aliases_array+=("${OPTARG}")
        ;;
    n)
        ssh_hostnames_array+=("${OPTARG}")
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

# Bash does not support exporting arrays
export ssh_aliases="${ssh_aliases_array[*]}"
export ssh_hostnames="${ssh_hostnames_array[*]}"
export jmeter_plugins="${jmeter_plugins_array[*]}"

function validate() {
    declare -a ssh_aliases_array=($ssh_aliases)
    declare -a ssh_hostnames_array=($ssh_hostnames)

    if [[ ! -f $key_file ]]; then
        echo "Please provide the private key location."
        exit 1
    fi
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
    if [[ ! -d $ssh_config_location ]]; then
        echo "Please provide the SSH config location."
        exit 1
    fi
    if [ ! "${#ssh_aliases_array[@]}" -eq "${#ssh_hostnames_array[@]}" ]; then
        echo "Number of SSH aliases should be equal to number of SSH hostnames."
        exit 1
    fi
}
export -f validate

function setup() {
    declare -a ssh_aliases_array=($ssh_aliases)
    declare -a ssh_hostnames_array=($ssh_hostnames)
    declare -a jmeter_plugins_array=($jmeter_plugins)

    ssh_config_file=$ssh_config_location/.ssh/config

    echo "Creating SSH configs in $ssh_config_file"

    if [[ -f ${ssh_config_file} ]]; then
        echo "WARNING: Replacing existing SSH config file."
        mv ${ssh_config_file}{,.bak$(date +%s)}
    fi

    # Configure SSH
    mkdir -p .ssh
    echo "Host *" >${ssh_config_file}
    echo "    StrictHostKeyChecking no" >>${ssh_config_file}
    echo -ne "\n" >>${ssh_config_file}
    for ix in ${!ssh_aliases_array[*]}; do
        echo "Host ${ssh_aliases_array[$ix]}" >>${ssh_config_file}
        echo "    HostName ${ssh_hostnames_array[$ix]}" >>${ssh_config_file}
        echo "    IdentityFile $key_file" >>${ssh_config_file}
        echo -ne "\n" >>${ssh_config_file}
    done

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

$script_dir/setup-common.sh "${opts[@]}" "$@" $SETUP_COMMON_ARGS -p zip -p unzip -p jq -p bc \
    -w http://search.maven.org/remotecontent?filepath=org/mortbay/jetty/alpn/alpn-boot/8.1.13.v20181017/alpn-boot-8.1.13.v20181017.jar \
    -o $alpnboot_dir/alpnboot.jar
