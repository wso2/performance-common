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
default_java_dir="/usr/lib/jvm"
java_dir="$default_java_dir"
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
    echo "-p: Java installation directory. Default: $default_java_dir."
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

while getopts "f:p:u:h" opts; do
    case $opts in
    f)
        java_dist=${OPTARG}
        ;;
    p)
        java_dir=${OPTARG}
        ;;
    u)
        user=${OPTARG}
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
    echo "Please specify the Java distribution file."
    exit 1
fi

# Validate Java Distribution
java_dist_filename=$(basename $java_dist)

if [[ ${java_dist_filename: -7} != ".tar.gz" ]]; then
    echo "Java distribution must be a valid tar.gz file."
    exit 1
fi

# Create the default directory if user has not specified any other path
if [[ $java_dir == $default_java_dir ]]; then
    mkdir -p $java_dir
fi

#Validate java directory
if [[ ! -d $java_dir ]]; then
    echo "Please specify a valid Java installation directory."
    exit 1
fi

if ! id "$user" >/dev/null 2>&1; then
    echo "Please specify a valid user."
    exit 1
fi

echo "Installing: $java_dist_filename"

# Check Java executable
java_exec="$(tar -tzf $java_dist | grep ^[^/]*/bin/java$ || echo "")"

if [[ -z $java_exec ]]; then
    echo "Could not find \"java\" executable in the distribution. Please specify a valid Java distribution."
    exit 1
fi

# JDK Directory with version
jdk_dir="$(echo $java_exec | cut -f1 -d"/")"
extracted_dirname=$java_dir"/"$jdk_dir

# Extract Java Distribution
if [[ ! -d $extracted_dirname ]]; then
    echo "Extracting $java_dist to $java_dir"
    tar -xof $java_dist -C $java_dir
    echo "JDK is extracted to $extracted_dirname"
else
    echo "WARN: JDK was not extracted to $java_dir. There is an existing directory with name $jdk_dir."
    exit 1
fi

if [[ ! -f "${extracted_dirname}/bin/java" ]]; then
    echo "ERROR: The path $extracted_dirname is not a valid Java installation."
    exit 1
fi

# Install Unlimited JCE Policy (only for Oracle JDK 7 & 8)
# Java 9 and above: default JCE policy files already allow for \"unlimited\" cryptographic strengths.

unlimited_jce_policy_dist=""

if [[ $jdk_dir =~ ^jdk1\.7.* ]]; then
    unlimited_jce_policy_dist="$(dirname $java_dist)/UnlimitedJCEPolicyJDK7.zip"
elif [[ $jdk_dir =~ ^jdk1\.8.* ]]; then
    unlimited_jce_policy_dist="$(dirname $java_dist)/jce_policy-8.zip"
fi

if [[ -f $unlimited_jce_policy_dist ]]; then
    echo "Extracting policy jars in $unlimited_jce_policy_dist to $extracted_dirname/jre/lib/security"
    unzip -j -o $unlimited_jce_policy_dist *.jar -d $extracted_dirname/jre/lib/security
fi

echo "Running update-alternatives..."
declare -a commands=($(ls -1 ${extracted_dirname}/bin))
for command in "${commands[@]}"; do
    command_path=$extracted_dirname/bin/$command
    if [[ -x $command_path ]]; then
        update-alternatives --install "/usr/bin/$command" "$command" "$command_path" 10000
        update-alternatives --set "$command" "$command_path"
    fi
done

# Create system preferences directory
java_system_prefs_dir="/etc/.java/.systemPrefs"
if [[ ! -d $java_system_prefs_dir ]]; then
    echo "Creating $java_system_prefs_dir and changing ownership to $user:$user"
    mkdir -p $java_system_prefs_dir
    chown -R $user:$user $java_system_prefs_dir
fi

user_bashrc_file=/home/$user/.bashrc

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
