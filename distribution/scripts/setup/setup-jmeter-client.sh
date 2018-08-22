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
export key_file_url=""
export script_dir=$(dirname "$0")

declare -a ssh_aliases_array
declare -a ssh_hostnames_array
declare -a jmeter_plugins_array

function usageCommand() {
    echo "-k <key_file_url> -a <ssh_alias> -n <ssh_hostname> [-j <jmeter_plugin>]"
}
export -f usageCommand

function usageHelp() {
    echo "-k: The URL to download the private key."
    echo "-a: SSH Alias. You can give multiple ssh aliases."
    echo "-n: SSH Hostname. You can give multiple ssh hostnames for a given set of ssh aliases."
    echo "-j: The JMeter plugin name. You can give multiple JMeter plugins to install."
}
export -f usageHelp

while getopts "gp:w:o:hk:a:n:j:" opt; do
    case "${opt}" in
    k)
        key_file_url=${OPTARG}
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

    if [[ -z $key_file_url ]]; then
        echo "Please provide the URL to download the private key."
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

    echo "Setting up JMeter in $PWD"
    key_file_name="private_key.pem"
    if [[ ! -f $key_file_name ]]; then
        wget -q ${key_file_url} -O $key_file_name
    fi

    chmod 600 $key_file_name

    ssh_config_file=.ssh/config
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
        echo "    IdentityFile $PWD/$key_file_name" >>${ssh_config_file}
        echo -ne "\n" >>${ssh_config_file}
    done

    $script_dir/../jmeter/install-jmeter.sh -d -i $PWD "${jmeter_plugins_array[@]}"
}
export -f setup

$script_dir/setup-common.sh "${opts[@]}" "$@" -p openjdk-8-jdk -p zip -p jq -p bc
