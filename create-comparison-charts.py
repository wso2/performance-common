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
    print(sys.argv[0] + " --summary1 <summary1.csv> --name1 <name1> --summary2 <summary2.csv> --name2 <name2>")

def main():
    global summary1_file
    global summary2_file
    global name1
    global name2
    try:
        opts, args = getopt.getopt(sys.argv[1:], "h", ["help", "summary1=", "name1=", "summary2=", "name2="])
    except getopt.GetoptError as err:
        # print help information and exit:
        print(err)  # will print something like "option -a not recognized"
        usage()
        sys.exit(2)
    for o, a in opts:
        if o == "--summary1":
            summary1_file = a
        elif o == "--name1":
            name1 = a
        elif o == "--summary2":
            summary2_file = a
        elif o == "--name2":
            name2 = a
        elif o in ("-h", "--help"):
            usage()
            sys.exit()
        else:
            assert False, "unhandled option"

if __name__ == "__main__":
    main()

if summary1_file == '' or summary2_file == '' or name1 == '' or name2 == '':
    print("Please provide arguments")
    usage()
    sys.exit(1)

def add_suffix(string, suffix):
    return string + " - " + suffix

print("Comparing " + name1 + " and " + name2)

df1 = pd.read_csv(summary1_file)
df2 = pd.read_csv(summary2_file)

keys=['Message Size (Bytes)', 'Sleep Time (ms)', 'Concurrent Users']

df = df1.merge(df2, on=keys, how='inner', suffixes=[add_suffix('', name1), add_suffix('', name2)])

sns.set_style("darkgrid")

unique_sleep_times=df['Sleep Time (ms)'].unique()

def save_multi_columns_categorical_charts(chart, sleep_time, columns, y, hue, title, kind='point'):
    comparison_columns = []
    for column in columns:
        comparison_columns.append(add_suffix(column, name1))
        comparison_columns.append(add_suffix(column, name2))
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
