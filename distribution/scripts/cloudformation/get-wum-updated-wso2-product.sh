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
# Get WSO2 product using WUM
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")
products_path="$HOME/.wum3/products"
wso2_product_code=""
wso2_product_version=""
wso2_product_link_path=""
default_wum_channel="full"
wum_channel="$default_wum_channel"

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 -p <wso2_product_code> -v <wso2_product_version> -l <wso2_product_link_path> [-c <wum_channel>] [-h]"
    echo ""
    echo "-p: WSO2 Product Code. eg: wso2am."
    echo "-v: WSO2 Product Version."
    echo "-l: Path to link the update WSO2 product."
    echo "-c: WUM Channel. Default: $default_wum_channel."
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "p:v:l:c:h" opt; do
    case "${opt}" in
    p)
        wso2_product_code=${OPTARG}
        ;;
    v)
        wso2_product_version=${OPTARG}
        ;;
    l)
        wso2_product_link_path=${OPTARG}
        ;;
    c)
        wum_channel=${OPTARG}
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

if [[ -z $wso2_product_code ]]; then
    echo "Please provide WSO2 Product Code."
    exit 1
fi
if [[ -z $wso2_product_version ]]; then
    echo "Please provide WSO2 Product Version."
    exit 1
fi
if [[ -z $wso2_product_link_path ]]; then
    echo "Please provide a path to link updated WSO2 product."
    exit 1
fi
if [[ ! -d $wso2_product_link_path ]]; then
    echo "Please provide a valid path to link updated WSO2 product."
    exit 1
fi
wso2_product_link_path=$(realpath $wso2_product_link_path)

if [[ -z $wum_channel ]]; then
    echo "Please provide the WUM channel."
    exit 1
fi

product_path="${products_path}/${wso2_product_code}/${wso2_product_version}"

if [[ ! -d $product_path ]]; then
    echo "Adding ${wso2_product_code}-${wso2_product_version}"
    wum add -y ${wso2_product_code}-${wso2_product_version}
fi

echo 'Updating the WUM Product....'
wum update ${wso2_product_code}-${wso2_product_version} ${wum_channel}
wum describe ${wso2_product_code}-${wso2_product_version} ${wum_channel}

product_path_with_channel="${products_path}/${wso2_product_code}/${wso2_product_version}/${wum_channel}"
product="$(ls $product_path_with_channel | sort -r | head -1)"

echo "Updated product is available at ${product_path_with_channel}/${product}"

link_name="${wso2_product_link_path}/${wso2_product_code}.zip"

if [[ -L $link_name ]]; then
    unlink $link_name
fi

ln -s ${product_path_with_channel}/${product} $link_name

echo "The link $link_name now points to updated WSO2 product."
ls -l $link_name
