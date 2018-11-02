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
# Installation script for setting up Java on Linux.
# This is a simplified version of the script in
# https://github.com/chrishantha/install-java
# ----------------------------------------------------------------------------

java_dist=""
java_dir=""

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 -f <java_dist> [-p <java_dir>] [-h]"
    echo ""
    echo "-f: The jdk tar.gz file."
    echo "-p: Java installation directory."
    echo "-h: Display this help and exit."
    echo ""
}

# Make sure the script is running as root.
if [ "$UID" -ne "0" ]; then
    echo "You must be root to run $0. Try following"
    echo "sudo $0"
    exit 9
fi

while getopts "f:p:h" opts; do
    case $opts in
    f)
        java_dist=${OPTARG}
        ;;
    p)
        java_dir=${OPTARG}
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

#Check whether unzip command exsits
if ! command -v unzip >/dev/null 2>&1; then
    echo "unzip command not found! Please install unzip."
    exit 1
fi

if [[ ! -f $java_dist ]]; then
    echo "Please specify the java distribution file (tar.gz)"
    help
    exit 1
fi

#If no directory was provided, we need to create the default one
if [[ -z $java_dir ]]; then
    java_dir="/usr/lib/jvm"
    mkdir -p $java_dir
fi

#Validate java directory
if [[ ! -d $java_dir ]]; then
    echo "Please specify a valid java installation directory"
    exit 1
fi

# Extract Java Distribution
java_dist_filename=$(basename $java_dist)

dirname=$(tar -tf $java_dist | head -1 | sed -e 's@/.*@@')

extracted_dirname=$java_dir"/"$dirname

if [[ ! -d $extracted_dirname ]]; then
    echo "Extracting $java_dist to $java_dir"
    tar -xof $java_dist -C $java_dir
    echo "JDK is extracted to $extracted_dirname"
else
    echo "JDK is already extracted to $extracted_dirname"
fi

if [[ ! -f $extracted_dirname"/bin/java" ]]; then
    echo "Couldn't check the extracted directory. Please check the installation script"
    exit 1
fi

# Install Unlimited JCE Policy

unlimited_jce_policy_dist=""

if [[ "$java_dist_filename" =~ ^jdk-7.* ]]; then
    unlimited_jce_policy_dist="$(dirname $java_dist)/UnlimitedJCEPolicyJDK7.zip"
elif [[ "$java_dist_filename" =~ ^jdk-8.* ]]; then
    unlimited_jce_policy_dist="$(dirname $java_dist)/jce_policy-8.zip"
fi

if [[ -f $unlimited_jce_policy_dist ]]; then
    echo "Extracting policy jars in $unlimited_jce_policy_dist to $extracted_dirname/jre/lib/security"
    unzip -j -o $unlimited_jce_policy_dist *.jar -d $extracted_dirname/jre/lib/security
fi

commands=("jar" "java" "javac" "javadoc" "javah" "javap" "javaws" "jcmd" "jconsole" "jarsigner" "jhat" "jinfo" "jmap" "jmc" "jps" "jstack" "jstat" "jstatd" "jvisualvm" "keytool" "policytool" "wsgen" "wsimport")

echo "Running update-alternatives --install and --config for ${commands[@]}"

for i in "${commands[@]}"; do
    command_path=$extracted_dirname/bin/$i
    if [[ -f $command_path ]]; then
        update-alternatives --install "/usr/bin/$i" "$i" "$command_path" 10000
        update-alternatives --set "$i" "$command_path"
    fi
done

# Create system preferences directory
java_system_prefs_dir="/etc/.java/.systemPrefs"
if [[ ! -d $java_system_prefs_dir ]]; then
    echo "Creating $java_system_prefs_dir and changing ownership to $SUDO_USER:$SUDO_USER"
    mkdir -p $java_system_prefs_dir
    chown -R $SUDO_USER:$SUDO_USER $java_system_prefs_dir
fi

user_bashrc_file=/home/$SUDO_USER/.bashrc

if [[ ! -f $user_bashrc_file ]]; then
    echo "Creating $user_bashrc_file"
    touch $user_bashrc_file
fi

if grep -q "export JAVA_HOME=.*" $user_bashrc_file; then
    sed -i "s|export JAVA_HOME=.*|export JAVA_HOME=$extracted_dirname|" $user_bashrc_file
else
    echo "export JAVA_HOME=$extracted_dirname" >>$user_bashrc_file
fi
source $user_bashrc_file
