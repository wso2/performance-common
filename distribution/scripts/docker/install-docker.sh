#!/usr/bin/env bash
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
# Installation script for setting up docker on Linux.
# ----------------------------------------------------------------------------

default_user=""
if [[ ! -z $SUDO_USER ]]; then
    default_user="$SUDO_USER"
else
    default_user="ubuntu"
fi
user="$default_user"

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 -f <java_dist> [-p <java_dir>] [-u <user>] [-h]"
    echo ""
    echo "-f: The jdk tar.gz file."
    echo "-p: Java installation directory."
    echo "-u: Target user. Default: $default_user."
    echo "-h: Display this help and exit."
    echo ""
}

# Make sure the script is running as root.
if [ "$UID" -ne "0" ]; then
    echo "You must be root to run $0. Try following"
    echo "sudo $0"
    exit 9
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "docker is not installed! Installing docker.."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get install -y docker-ce
else
    echo "docker is already installed."
fi

