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

# Make sure the script is running as root.
if [ "$UID" -ne "0" ]; then
    echo "You must be root to run $0. Try following"; echo "sudo $0";
    exit 9
fi

#Install sysstat package
apt install sysstat

#Enable
sed -i "s|ENABLED=\"false\"|ENABLED=\"true\"|" /etc/default/sysstat

#Change interval to 1 minute
sed -i "s|^5-55/10|*/1|" /etc/cron.d/sysstat

#Restart the service
service sysstat restart
