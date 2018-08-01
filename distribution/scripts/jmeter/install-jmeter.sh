#!/bin/bash -e
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

current_dir=$(dirname "$0")
jmeter_dist=""
installation_dir=""
# JMeter Plugins
declare -a plugins

function usage {
    echo ""
    echo "Usage: "
    echo "$0 -f <jmeter_dist> -i <installation_dir> [-p <jmeter_plugin_name>] [-h]"
    echo ""
    echo "-f: The JMeter tgz distribution."
    echo "-i: The JMeter installation directory."
    echo "-p: The name of the JMeter Plugin to install. You can provide multiple names."
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "f:i:p:h" opts
do
  case $opts in
    f)
        jmeter_dist=${OPTARG}
        ;;
    i)
        installation_dir=${OPTARG}
        ;;
    p)
        plugins+=("${OPTARG}")
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

if [[ ! -f $jmeter_dist ]]; then
    echo "Please specify the jmeter distribution file (apache-jmeter-*.tgz)"
    exit 1
fi

if [[ ! $jmeter_dist =~ ^.*\.tgz$ ]]; then
    echo "Please provide the jmeter tgz distribution file (apache-jmeter-*.tgz)"
    exit 1
fi

if [[ ! -d $installation_dir ]]; then
    echo "Please provide the JMeter installation direcory."
    exit 1
fi

# Install following plugins to generate AggregateReport from command line.
# For example:
# JMeterPluginsCMD.sh --generate-csv test.csv --input-jtl results.jtl --plugin-type AggregateReport
plugins+=( "jpgc-cmd" "jpgc-synthesis" )

# Extract JMeter Distribution
jmeter_dist_filename=$(basename $jmeter_dist)

dirname=$(echo $jmeter_dist_filename | sed 's/apache-jmeter-\([0-9]\.[0-9]\).*/apache-jmeter-\1/')

extracted_dirname=$installation_dir"/"$dirname

if [[ ! -d $extracted_dirname ]]; then
    echo "Extracting $jmeter_dist to $installation_dir"
    tar -xof $jmeter_dist -C $installation_dir
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

# Install JMeter Plugins Manager. Refer https://jmeter-plugins.org/wiki/PluginsManagerAutomated/
wget_useragent="Linux Server"
plugins_manager_output_file=jmeter-plugins-manager.jar

# Download plugins manager JAR file

if ! ls $extracted_dirname/lib/ext/jmeter-plugins-manager*.jar 1> /dev/null 2>&1; then
    wget -U "${wget_useragent}" https://jmeter-plugins.org/get/ -O /tmp/${plugins_manager_output_file}
    cp /tmp/$plugins_manager_output_file $extracted_dirname/lib/ext/
fi

# Run Command Line Installer
tmp=($extracted_dirname/lib/ext/jmeter-plugins-manager*.jar)
plugin_manager_jar="${tmp[0]}"

java -cp $plugin_manager_jar org.jmeterplugins.repository.PluginManagerCMDInstaller

plugins_manager_cmd=$extracted_dirname/bin/PluginsManagerCMD.sh

if [[ ! -f $plugins_manager_cmd ]]; then
    echo "Plugins Manager Command Line Installer is not available!"
    exit 1
fi

cmdrunner_version=$(grep -o 'cmdrunner-\(.*\)\.jar' $plugins_manager_cmd | sed -nE 's/cmdrunner-(.*)\.jar/\1/p')
cmdrunner_jar=cmdrunner-${cmdrunner_version}.jar

if [[ ! -f $extracted_dirname/lib/${cmdrunner_jar} ]]; then
    wget -U "${wget_useragent}" http://search.maven.org/remotecontent?filepath=kg/apc/cmdrunner/${cmdrunner_version}/${cmdrunner_jar} -O /tmp/${cmdrunner_jar}
    cp /tmp/${cmdrunner_jar} $extracted_dirname/lib/
fi

PluginsManagerCMD=$plugins_manager_cmd

upgrade_response="$(echo "$($PluginsManagerCMD upgrades)" | tail -1)"

if [[ "$upgrade_response" =~ nothing ]]; then
    echo "No upgrades"
else
    echo "Installing upgrades"
    upgrades=$(tr -d '[:space:]' <<<"$upgrade_response")
    upgrades=$(sed -e 's/^\[//' -e 's/\]$//' <<<"$upgrades")
    # Install Upgrades
    $PluginsManagerCMD install "$upgrades"
fi

for plugin in ${plugins[@]}; do
    echo "Installing $plugin plugin"
    $PluginsManagerCMD install $plugin
done

# Set cmdrunner version in JMeterPluginsCMD.sh
sed -i "s/cmdrunner-.*\.jar/$cmdrunner_jar/g" $extracted_dirname/bin/JMeterPluginsCMD.sh
