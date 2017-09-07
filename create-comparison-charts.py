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
import seaborn as sns
import sys
import apimchart

sns.set_style("darkgrid")

summary_files = []
names = []
summary_count = 0


def usage():
    print(sys.argv[0] + " summary1.csv name1 summary2.csv name2 <summary3.csv> <name3> ... ...")


def main():
    global summary_files
    global names
    global summary_count

    args = sys.argv[1:]
    args_count = len(args)

    if args_count < 4:
        print("Please provide arguments at least two summary files with names")
        usage()
        sys.exit(1)

    if args_count % 2 != 0:
        print("Please provide a name for each summary file")
        usage()
        sys.exit(1)

    summary_count = args_count // 2

    for index in range(0, args_count, 2):
        summary_files.append(args[index])
        names.append(args[index + 1])


if __name__ == "__main__":
    main()


def add_suffix(string, suffix):
    return string + " - " + suffix


print("Reading " + summary_files[0] + " with name " + names[0])
# DataFrame to merge all data
df = pd.read_csv(summary_files[0])
# Filter errors
df = df.loc[df['Error Count'] < 100]

# DataFrame to append all data
df_all = df.copy()
df_all.insert(0, 'Name', names[0])

keys = ['Message Size (Bytes)', 'Sleep Time (ms)', 'Concurrent Users']

for i in range(1, summary_count):
    print("Reading " + summary_files[i] + " with name " + names[i] + " to merge and append")
    df_read = pd.read_csv(summary_files[i])
    # Filter errors
    df_read = df_read.loc[df['Error Count'] < 100]
    if i == summary_count - 1:
        # Add suffixes to new right columns. Add suffixes to left columns using the first summary name
        suffixes = [add_suffix('', names[0]), add_suffix('', names[i])]
    else:
        # Add suffixes to new right columns. Keep the left column names unchanged till the last summary file.
        suffixes = ['', add_suffix('', names[i])]
    # Merge
    df = df.merge(df_read, on=keys, how='outer', suffixes=suffixes)

    # Append data frame
    df_to_concat = df_read.copy()
    df_to_concat.insert(0, 'Name', names[i])
    df_all = df_all.append(df_to_concat, ignore_index=True)

# Save all data frame
df_all.to_csv('all_results.csv')

# Format message size values
df['Message Size (Bytes)'] = df['Message Size (Bytes)'].map(apimchart.format_bytes)

# Save lmplots
xcolumns = ['Message Size (Bytes)', 'Sleep Time (ms)', 'Concurrent Users']
xcharts = ['message_size', 'sleep_time', 'concurrent_users']
ycolumns = ['Throughput', 'Average (ms)', 'Max (ms)', '90th Percentile (ms)', '95th Percentile (ms)',
            '99th Percentile (ms)', 'API Manager GC Throughput (%)', 'API Manager Load Average - Last 1 minute',
            'API Manager Load Average - Last 5 minutes', 'API Manager Load Average - Last 15 minutes']
ycharts = ['lmplot_throughput', 'lmplot_average_time', 'lmplot_max_time', 'lmplot_p90', 'lmplot_p95', 'lmplot_p99',
           'lmplot_gc_throughput', 'lmplot_loadavg_1', 'lmplot_loadavg_5', 'lmplot_loadavg_15']
ylabels = ['Throughput (Requests/sec)', 'Average Response Time (ms)', 'Maximum Response Time (ms)',
           '90th Percentile (ms)', '95th Percentile (ms)', '99th Percentile (ms)', 'API Manager GC Throughput (%)',
           'API Manager Load Average - Last 1 minute', 'API Manager Load Average - Last 5 minutes',
           'API Manager Load Average - Last 15 minutes']

for ycolumn, ylabel, ychart in zip(ycolumns, ylabels, ycharts):
    for xcolumn, xchart in zip(xcolumns, xcharts):
        chart = ychart + '_vs_' + xchart
        title = ylabel + ' vs ' + xcolumn
        apimchart.save_lmplot(df_all, chart, xcolumn, ycolumn, title, ylabel=ylabel)
        apimchart.save_lmplot(df_all, chart + '_with_hue', xcolumn, ycolumn, title, hue='Name', ylabel=ylabel)

unique_sleep_times_in_df_all = df_all['Sleep Time (ms)'].unique()
unique_message_sizes_in_df_all = df_all['Message Size (Bytes)'].unique()

for sleep_time in unique_sleep_times_in_df_all:
    for message_size in unique_message_sizes_in_df_all:
        df_filtered = df_all.loc[
            (df_all['Message Size (Bytes)'] == message_size) & (df_all['Sleep Time (ms)'] == sleep_time)]
        chart_suffix = '_' + apimchart.format_time(sleep_time) + '_' + apimchart.format_bytes(message_size)
        title_suffix = ' vs Concurrent Users for ' + apimchart.format_bytes(
            message_size) + ' messages with ' + apimchart.format_time(sleep_time) + ' backend delay'
        ycolumns = ['Throughput', 'Average (ms)', 'Max (ms)', '90th Percentile (ms)', '95th Percentile (ms)',
                    '99th Percentile (ms)', 'API Manager GC Throughput (%)']
        charts = ['throughput', 'average_time', 'max_time', 'p90', 'p95', 'p99', 'gc_throughput']
        ylabels = ['Throughput (Requests/sec)', 'Average Response Time (ms)', 'Maximum Response Time (ms)',
                   '90th Percentile (ms)', '95th Percentile (ms)', '99th Percentile (ms)', 'GC Throughput (%)']
        for ycolumn, ylabel, chart in zip(ycolumns, ylabels, charts):
            apimchart.save_point_plot(df_filtered, chart + chart_suffix, 'Concurrent Users', ycolumn,
                                      ylabel + title_suffix, hue='Name', ylabel=ylabel)


def save_multi_columns_categorical_charts(chart, columns, y, hue, title, kind='point'):
    comparison_columns = []
    for column in columns:
        for name in names:
            comparison_columns.append(add_suffix(column, name))
    apimchart.save_multi_columns_categorical_charts(df, chart, sleep_time, comparison_columns, y, hue, title,
                                                    len(columns) == 1, columns[0], kind)


def save_bar_plot(chart, columns, y, hue, title):
    comparison_columns = []
    for column in columns:
        for name in names:
            comparison_columns.append(add_suffix(column, name))
    df_results = df.loc[(df['Message Size (Bytes)'] == message_size) & (df['Sleep Time (ms)'] == sleep_time)]
    all_columns = ['Message Size (Bytes)', 'Concurrent Users']
    all_columns.extend(comparison_columns)
    df_results = df_results[all_columns]
    df_results = df_results.set_index(['Message Size (Bytes)', 'Concurrent Users']).stack().reset_index().rename(
        columns={'level_2': hue, 0: y})
    apimchart.save_bar_plot(df_results, chart, 'Concurrent Users', y, title, hue=hue)


unique_sleep_times_in_df = df['Sleep Time (ms)'].unique()
unique_message_sizes_in_df = df['Message Size (Bytes)'].unique()

for sleep_time in unique_sleep_times_in_df:
    save_multi_columns_categorical_charts("comparison_thrpt", ['Throughput'],
                                          "Throughput (Requests/sec)", "API Manager",
                                          "Throughput vs Concurrent Users for " + str(sleep_time) + "ms backend delay")
    save_multi_columns_categorical_charts("comparison_avgt", ['Average (ms)'],
                                          "Average Response Time (ms)", "API Manager",
                                          "Average Response Time vs Concurrent Users for " + str(
                                              sleep_time) + "ms backend delay")
    save_multi_columns_categorical_charts("comparison_response_time",
                                          ['90th Percentile (ms)', '95th Percentile (ms)',
                                           '99th Percentile (ms)'],
                                          "Response Time (ms)", "API Manager",
                                          "Response Time Percentiles for " + str(sleep_time) + "ms backend delay",
                                          kind='bar')
    save_multi_columns_categorical_charts("comparison_loadavg",
                                          ['API Manager Load Average - Last 1 minute',
                                           'API Manager Load Average - Last 5 minutes',
                                           'API Manager Load Average - Last 15 minutes'],
                                          "Load Average", "API Manager",
                                          "Load Average with " + str(sleep_time) + "ms backend delay")
    save_multi_columns_categorical_charts("comparison_network", ['Received (KB/sec)', 'Sent (KB/sec)'],
                                          "Network Throughput (KB/sec)", "Network",
                                          "Network Throughput with " + str(sleep_time) + "ms backend delay")
    save_multi_columns_categorical_charts("comparison_gc", ['API Manager GC Throughput (%)'],
                                          "GC Throughput (%)", "API Manager",
                                          "GC Throughput with " + str(sleep_time) + "ms backend delay")
    for message_size in unique_message_sizes_in_df:
        chart_suffix = '_' + apimchart.format_time(sleep_time) + '_' + message_size
        title_suffix = " for " + message_size + " messages with " + apimchart.format_time(sleep_time) + " backend delay"
        save_bar_plot('response_time' + chart_suffix,
                      ['90th Percentile (ms)', '95th Percentile (ms)', '99th Percentile (ms)'],
                      'Response Time (ms)', 'Summary',
                      "Response Time Percentiles" + title_suffix)
        save_bar_plot('loadavg' + chart_suffix,
                      ['API Manager Load Average - Last 1 minute',
                       'API Manager Load Average - Last 5 minutes',
                       'API Manager Load Average - Last 15 minutes'],
                      "Load Average", "API Manager",
                      "Load Average" + title_suffix)

print("Done")
