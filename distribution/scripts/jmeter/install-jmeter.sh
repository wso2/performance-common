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
# Installation script for setting up Apache JMeter
# ----------------------------------------------------------------------------

jmeter_dist="$1"
current_dir=$(dirname "$0")

if [[ ! -f $jmeter_dist ]]; then
    echo "Please specify the jmeter distribution file (apache-jmeter-*.tgz)"
    exit 1
fi

# Extract JMeter Distribution
jmeter_dist_filename=$(basename $jmeter_dist)

dirname=$(echo $jmeter_dist_filename | sed 's/apache-jmeter-\([0-9]\.[0-9]\).*/apache-jmeter-\1/')

extracted_dirname=$HOME"/"$dirname

if [[ ! -d $extracted_dirname ]]; then
    echo "Extracting $jmeter_dist to $HOME"
    tar -xof $jmeter_dist -C $HOME
    echo "JMeter is extracted to $extracted_dirname"
else 
    echo "JMeter is already extracted to $extracted_dirname"
fi

properties_file=$current_dir/user.properties

echo "Copying $properties_file file to $extracted_dirname/bin"
cp $properties_file $extracted_dirname/bin

if grep -q "export JMETER_HOME=.*" $HOME/.bashrc; then
    sed -i "s|export JMETER_HOME=.*|export JMETER_HOME=$extracted_dirname|" $HOME/.bashrc
else
    echo "export JMETER_HOME=$extracted_dirname" >> $HOME/.bashrc
fi
source $HOME/.bashrc
