#!/bin/bash -e
# Copyright 2019 WSO2 Inc. (http://wso2.org)
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
# Interrupt perf stat process
# ----------------------------------------------------------------------------

perf_pid=$(pgrep '^perf$' || echo "")
if [[ -n $perf_pid ]]; then
    kill -SIGINT $perf_pid
    echo "Sent interrupt signal to perf ($perf_pid) command."
else
    echo "INFO: perf command is not running."
fi
