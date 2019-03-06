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
# Create charts from the summary.csv file
# ----------------------------------------------------------------------------
import matplotlib.pyplot as plt
import matplotlib.ticker as tkr
import pandas as pd
import seaborn as sns

import apimchart

sns.set_style("darkgrid")

df = pd.read_csv('summary.csv')
# Filter errors
df = df.loc[df['Error Count'] < 100]
# Format message size values
df['Message Size (Bytes)'] = df['Message Size (Bytes)'].map(apimchart.format_bytes)

unique_sleep_times = df['Sleep Time (ms)'].unique()
unique_message_sizes = df['Message Size (Bytes)'].unique()


def save_line_chart(chart, column, title, ylabel=None):
    filename = chart + "_" + str(sleep_time) + "ms.png"
    print("Creating chart: " + title + ", File name: " + filename)
    fig, ax = plt.subplots()
    fig.set_size_inches(8, 6)
    sns_plot = sns.pointplot(x="Concurrent Users", y=column, hue="Message Size (Bytes)",
                             data=df.loc[df['Sleep Time (ms)'] == sleep_time], ci=None, dodge=True)
    ax.yaxis.set_major_formatter(tkr.FuncFormatter(lambda y, p: "{:,}".format(y)))
    plt.suptitle(title)
    if ylabel is None:
        ylabel = column
    sns_plot.set(ylabel=ylabel)
    plt.legend(loc=2, frameon=True, title="Message Size")
    plt.savefig(filename)
    plt.clf()
    plt.close(fig)


def save_bar_chart(title):
    filename = "response_time_summary_" + message_size + "_" + str(sleep_time) + "ms.png"
    print("Creating chart: " + title + ", File name: " + filename)
    fig, ax = plt.subplots()
    fig.set_size_inches(8, 6)
    df_results = df.loc[(df['Message Size (Bytes)'] == message_size) & (df['Sleep Time (ms)'] == sleep_time)]
    df_results = df_results[
        ['Message Size (Bytes)', 'Concurrent Users', 'Min (ms)', '90th Percentile (ms)', '95th Percentile (ms)',
         '99th Percentile (ms)', 'Max (ms)']]
    df_results = df_results.set_index(['Message Size (Bytes)', 'Concurrent Users']).stack().reset_index().rename(
        columns={'level_2': 'Summary', 0: 'Response Time (ms)'})
    sns.barplot(x='Concurrent Users', y='Response Time (ms)', hue='Summary', data=df_results, ci=None)
    ax.yaxis.set_major_formatter(tkr.FuncFormatter(lambda y, p: "{:,}".format(y)))
    plt.suptitle(title)
    plt.legend(loc=2, frameon=True, title="Response Time Summary")
    plt.savefig(filename)
    plt.clf()
    plt.close(fig)


for sleep_time in unique_sleep_times:
    save_line_chart("thrpt", "Throughput", "Throughput vs Concurrent Users for " + str(sleep_time) + "ms backend delay",
                    ylabel="Throughput (Requests/sec)")
    save_line_chart("avgt", "Average (ms)",
                    "Average Response Time vs Concurrent Users for " + str(sleep_time) + "ms backend delay",
                    ylabel="Average Response Time (ms)")
    save_line_chart("gc", "API Manager GC Throughput (%)",
                    "GC Throughput vs Concurrent Users for " + str(sleep_time) + "ms backend delay",
                    ylabel="GC Throughput (%)")
    df_results = df.loc[df['Sleep Time (ms)'] == sleep_time]
    chart_suffix = "_" + str(sleep_time) + "ms"
    apimchart.save_multi_columns_categorical_charts(df_results, "loadavg" + chart_suffix,
                                                    ['API Manager Load Average - Last 1 minute',
                                                     'API Manager Load Average - Last 5 minutes',
                                                     'API Manager Load Average - Last 15 minutes'],
                                                    "Load Average", "API Manager",
                                                    "Load Average with " + str(sleep_time) + "ms backend delay")
    apimchart.save_multi_columns_categorical_charts(df_results, "network" + chart_suffix,
                                                    ['Received (KB/sec)', 'Sent (KB/sec)'],
                                                    "Network Throughput (KB/sec)", "Network",
                                                    "Network Throughput with " + str(sleep_time) + "ms backend delay")
    apimchart.save_multi_columns_categorical_charts(df_results, "response_time" + chart_suffix,
                                                    ['90th Percentile (ms)', '95th Percentile (ms)',
                                                     '99th Percentile (ms)'],
                                                    "Response Time (ms)", "Response Time",
                                                    "Response Time Percentiles with " + str(sleep_time)
                                                    + "ms backend delay", kind='bar')
    for message_size in unique_message_sizes:
        save_bar_chart(
            "Response Time Summary for " + message_size + " message size with " + str(sleep_time) + "ms backend delay")

print("Done")
