#!/usr/bin/env python3.6
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
# Create comparison charts from two summary.csv files
# ----------------------------------------------------------------------------
import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
import matplotlib.ticker as tkr
import getopt, sys
import apimchart

def usage():
    print(sys.argv[0] + " summary1.csv name1 summary2.csv name2 <summary3.csv> <name3> ... ...")

def main():
    global summary_files
    global names
    global summary_count

    summary_files=[]
    names=[]

    args=sys.argv[1:]

    args_count=len(args)

    if args_count < 4:
        print("Please provide arguments at least two summary files with names")
        usage()
        sys.exit(1)

    if args_count % 2 != 0:
        print("Please provide a name for each summary file")
        usage()
        sys.exit(1)

    summary_count=args_count // 2

    for i in range(0, args_count, 2):
        summary_files.append(args[i])
        names.append(args[i + 1])

if __name__ == "__main__":
    main()

def add_suffix(string, suffix):
    return string + " - " + suffix

print("Reading " + summary_files[0] + " with name " + names[0])
df = pd.read_csv(summary_files[0])

keys=['Message Size (Bytes)', 'Sleep Time (ms)', 'Concurrent Users']

for i in range(1, summary_count):
    print("Merging " + summary_files[i] + " with name " + names[i])
    df_merge=pd.read_csv(summary_files[i])
    if i == summary_count - 1:
        # Add suffixes to new right columns. Add suffixes to left columns using the first summary name
        suffixes=[add_suffix('', names[0]), add_suffix('', names[i])]
    else:
        # Add suffixes to new right columns. Keep the left column names unchanged till the last summary file.
        suffixes=['', add_suffix('', names[i])]
    df = df.merge(df_merge, on=keys, how='inner', suffixes=suffixes)

sns.set_style("darkgrid")

unique_sleep_times=df['Sleep Time (ms)'].unique()

def save_multi_columns_categorical_charts(chart, sleep_time, columns, y, hue, title, kind='point'):
    comparison_columns = []
    for column in columns:
        for name in names:
            comparison_columns.append(add_suffix(column, name))
    apimchart.save_multi_columns_categorical_charts(df, chart, sleep_time, comparison_columns, y, hue, title, kind)

for sleep_time in unique_sleep_times:
    save_multi_columns_categorical_charts("comparison_thrpt", sleep_time, ['Throughput'],
        "Throughput", "API Manager", "Throughput (Requests/sec) vs Concurrent Users for " + str(sleep_time) + "ms backend delay");
    save_multi_columns_categorical_charts("comparison_avgt", sleep_time, ['Average (ms)'],
        "Average Response Time", "API Manager", "Average Response Time (ms) vs Concurrent Users for " + str(sleep_time) + "ms backend delay");
    save_multi_columns_categorical_charts("comparison_response_time_summary", sleep_time, ['Min (ms)','90th Percentile (ms)','95th Percentile (ms)','99th Percentile (ms)','Max (ms)'],
        "Response Time", "API Manager", "Response Time Summary for " + str(sleep_time) + "ms backend delay", kind='bar');
    save_multi_columns_categorical_charts("comparison_loadavg", sleep_time, ['API Manager Load Average - Last 1 minute','API Manager Load Average - Last 5 minutes','API Manager Load Average - Last 15 minutes'],
        "Load Average", "API Manager", "Load Average with " + str(sleep_time) + "ms backend delay");
    save_multi_columns_categorical_charts("comparison_network", sleep_time, ['Received (KB/sec)', 'Sent (KB/sec)'],
        "Network Throughput (KB/sec)", "Network", "Network Throughput with " + str(sleep_time) + "ms backend delay");
    save_multi_columns_categorical_charts("comparison_gc", sleep_time, ['API Manager GC Throughput (%)'],
        "GC Throughput", "API Manager", "GC Throughput with " + str(sleep_time) + "ms backend delay")

print("Done")
