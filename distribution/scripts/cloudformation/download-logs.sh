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
# Download logs and create logs.zip
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")
output_directory=""

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 -o <output_directory> [-h]"
    echo ""
    echo "-o: Directory to store the logs.zip file."
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

logs_zip_file="$output_directory/logs.zip"

if [[ -f $logs_zip_file ]]; then
    echo "WARNING: The logs.zip already exists."
fi

declare -a log_files=("cloud-init.log" "cloud-init-output.log" "cfn-init.log" "cfn-init-cmd.log" "syslog")

temp_dir=$(mktemp -d)

cd $temp_dir

mkdir jmeter

for log_file in "${log_files[@]}"; do
    local_log_file="/var/log/$log_file"
    destination_file="jmeter/$log_file"
    echo "Copying $local_log_file to $destination_file"
    if cp $local_log_file $destination_file; then
        echo "File copied."
    else
        echo "WARNING: File copy failed!"
    fi
done

for host in $(sed -nE 's/^\s*Host\s+([^[*]]*)\s*/\1/ip' ~/.ssh/config); do
    mkdir $host
    for log_file in "${log_files[@]}"; do
        remote_log_file="/var/log/$log_file"
        destination_file="$host/$log_file"
        echo "Downloading $remote_log_file from $host to $destination_file"
        if scp -qp $host:$remote_log_file $destination_file; then
            echo "File transfer succeeded."
        else
            echo "WARNING: File transfer failed!"
        fi
    done
done

echo "Zipping log files to $logs_zip_file"

zip -r $logs_zip_file *
