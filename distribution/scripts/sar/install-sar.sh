#!/bin/bash
# Copyright 2017 WSO2 Inc. (http://wso2.org)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ----------------------------------------------------------------------------
# Installation script for setting up System Activity Report
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")

# Make sure the script is running as root.
if [ "$UID" -ne "0" ]; then
    echo "You must be root to run $0. Try following"
    echo "sudo $0"
    exit 9
fi

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 [-h]"
    echo ""
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "h" opts; do
    case $opts in
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

#Install latest sysstat version
latest_version=$(curl -s https://api.github.com/repos/sysstat/sysstat/tags | jq -r '.[] | .name' | sort -rV | head -1 || echo "")
if [[ -z $latest_version ]]; then
    return 1
fi
sysstat_source_url="https://github.com/sysstat/sysstat/archive/$latest_version.tar.gz"
echo "Downloading latest sysstat version from $sysstat_source_url"
sar_dir=$(realpath $script_dir)
wget "$sysstat_source_url" -O $sar_dir/sysstat.tar.gz
extracted_dir_name="$(tar -tzf $sar_dir/sysstat.tar.gz | head -1 | cut -f1 -d"/")"
tar -xvf $sar_dir/sysstat.tar.gz -C $sar_dir
pushd $sar_dir/$extracted_dir_name
./configure --enable-install-cron --enable-collect-all
make
make install
popd

#Change interval to 1 minute
sed -i "s|^*/10|*/1|" /etc/cron.d/sysstat

#Restart the service
service sysstat restart

echo "Systat service started.. SAR version: "
sar -V
