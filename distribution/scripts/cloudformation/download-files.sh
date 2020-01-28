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
# Download files from EC2 instances and create a zip files
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")
private_ip_file=""
key_file=""
output_directory=""

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 -f <private_ip_file> -k <key_file> -o <output_directory> [-h]"
    echo ""
    echo "-f: Private IP file."
    echo "-k: Key file."
    echo "-o: Directory to store the zip file."
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "f:k:o:h" opt; do
    case "${opt}" in
    f)
        private_ip_file=${OPTARG}
        ;;
    k)
        key_file=${OPTARG}
        ;;
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

if [[ ! -f $private_ip_file ]]; then
    echo "Please provide the file containing private IP addresses."
    exit 1
fi

if [[ ! -f $key_file ]]; then
    echo "Please provide the key file."
    exit 1
fi

if [[ ! -d $output_directory ]]; then
    echo "Please provide output directory."
    exit 1
fi

zip_file="$(realpath $output_directory)/files.zip"

if [[ -f $zip_file ]]; then
    echo "The $zip_file already exists. It will be updated."
fi

declare -A names_and_ips

echo "Reading $private_ip_file"

while IFS='' read -r line || [[ -n "$line" ]]; do
    echo "Line: $line"
    name="${line%%/*}"
    ip="${line##*/}"
    echo "Name: $name, IP: $ip"
    names_and_ips[$name]="$ip"
done <"$private_ip_file"

declare -a remote_files=("/var/log/cloud-init.log" "/var/log/cloud-init-output.log"
    "/var/log/cfn-init.log" "/var/log/cfn-init-cmd.log" "/var/log/syslog" "/home/ubuntu/system-info/*")

temp_dir=$(mktemp -d)

key_file="$(realpath $key_file)"
cd $temp_dir

for name in "${!names_and_ips[@]}"; do
    mkdir $name
    for remote_file in "${remote_files[@]}"; do
        private_ip="${names_and_ips[$name]}"
        echo "Downloading $remote_file from $name [$private_ip] to $name"
        if scp -i $key_file -o "StrictHostKeyChecking=no" $private_ip:$remote_file $name/; then
            echo "File transfer succeeded."
        else
            echo "WARNING: File transfer failed!"
        fi
    done
done

echo "Zipping files to $zip_file"

zip -r $zip_file *
