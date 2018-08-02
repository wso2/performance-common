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
# Split JTL file
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")
jtl_file=""
warmup_time=""
delete_on_exit=""

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 -f <jtl_file> [-t <warmup_time>] [-d]"
    echo ""
    echo "-f: The JTL file."
    echo "-t: The warmup time. Default 5 minutes"
    echo ""
}

while getopts "f:t:d" opts; do
    case $opts in
    f)
        jtl_file=${OPTARG}
        ;;
    t)
        warmup_time=${OPTARG}
        ;;
    d)
        delete_on_exit="-d"
        ;;
    \?)
        usage
        exit 1
        ;;
    esac
done

if [ -z "$jtl_file" ]; then
    echo "JTL file not provided"
    exit
fi

if [ -z "$warmup_time" ]; then
    warmup_time=5
fi

java -jar $script_dir/jtl-splitter-${performance.common.version}.jar -f $jtl_file -t $warmup_time $delete_on_exit
