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
# Setup Netty
# ----------------------------------------------------------------------------

# Make sure the script is running as root.
if [ "$UID" -ne "0" ]; then
    echo "You must be root to run $0. Try following"
    echo "sudo $0"
    exit 9
fi

export script_name="$0"
export script_dir=$(dirname "$0")
export oracle_jdk_dist=""

function usageCommand() {
    echo "-d <oracle_jdk_dist>"
}
export -f usageCommand

function usageHelp() {
    echo "-d: Oracle JDK distribution. (If not provided, OpenJDK will be installed)"
}
export -f usageHelp

while getopts "gp:w:o:hd:" opt; do
    case "${opt}" in
    d)
        oracle_jdk_dist=${OPTARG}
        ;;
    *)
        opts+=("-${opt}")
        [[ -n "$OPTARG" ]] && opts+=("$OPTARG")
        ;;
    esac
done
shift "$((OPTIND - 1))"

function setup() {
    if [[ -f $oracle_jdk_dist ]]; then
        echo "Installing Oracle JDK from $oracle_jdk_dist"
        $script_dir/../java/install-java.sh -f $oracle_jdk_dist
    fi
}
export -f setup

if [[ ! -f $oracle_jdk_dist ]]; then
    SETUP_COMMON_ARGS+="-p openjdk-8-jdk"
fi

$script_dir/setup-common.sh "${opts[@]}" "$@" $SETUP_COMMON_ARGS -p unzip
