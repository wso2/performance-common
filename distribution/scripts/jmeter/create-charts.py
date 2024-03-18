#!/usr/bin/env python3.6
# Copyright (c) 2024, WSO2 LLC. (https://www.wso2.com/).
# WSO2 LLC. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
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
# Format GraphQL Query Number values
# df['GraphQL Query Number'] = df['GraphQL Query Number'].map(apimchart.format_bytes)
df['GraphQL Query Number'] = df['GraphQL Query Number'].map(apimchart.format_query) #remove when required


unique_sleep_times = df['Back-end Service Delay (ms)'].unique()
unique_message_sizes = df['GraphQL Query Number'].unique()


def save_line_chart(chart, column, title, ylabel=None):
    filename = chart + "_" + str(sleep_time) + "ms.png"
    print("Creating chart: " + title + ", File name: " + filename)
    fig, ax = plt.subplots()
    fig.set_size_inches(10,8.5)
    sns_plot = sns.pointplot(x="Concurrent Users", y=column, hue="GraphQL Query Number",
                             data=df.loc[df['Back-end Service Delay (ms)'] == sleep_time], ci=None, dodge=True)
    ax.yaxis.set_major_formatter(tkr.FuncFormatter(lambda y, p: "{:,}".format(y)))
    plt.suptitle(title)
    if ylabel is None:
        ylabel = column
    sns_plot.set(ylabel=ylabel)
    box = ax.get_position()
    ax.set_position([box.x0, box.y0 + box.height * 0.1,
                    box.width, box.height * 0.9])
    # Put a legend below current axis
    ax.legend(loc='upper center', bbox_to_anchor=(0.5, -0.1),
          fancybox=True, title="GraphQL Query Number")
    # plt.legend(frameon=True, title="GraphQL Query Number")
    plt.savefig(filename)
    plt.clf()
    plt.close(fig)


def save_bar_chart(title):
    filename = "response_time_summary_" + str(message_size) + "_" + str(sleep_time) + "ms.png"
    print("Creating chart: " + title + ", File name: " + filename)
    fig, ax = plt.subplots()
    fig.set_size_inches(8, 6)
    df_results = df.loc[(df['GraphQL Query Number'] == message_size) & (df['Back-end Service Delay (ms)'] == sleep_time)]
    df_results = df_results[
        ['GraphQL Query Number', 'Concurrent Users', 'Minimum Response Time (ms)', '90th Percentile of Response Time (ms)', '95th Percentile of Response Time (ms)',
         '99th Percentile of Response Time (ms)', 'Maximum Response Time (ms)']]
    df_results = df_results.set_index(['GraphQL Query Number', 'Concurrent Users']).stack().reset_index().rename(
        columns={'level_2': 'Summary', 0: 'Response Time (ms)'})
    sns.barplot(x='Concurrent Users', y='Response Time (ms)', hue='Summary', data=df_results, ci=None)
    ax.yaxis.set_major_formatter(tkr.FuncFormatter(lambda y, p: "{:,}".format(y)))
    plt.suptitle(title)
    plt.legend(loc=2, frameon=True, title="Response Time Summary")
    plt.savefig(filename)
    plt.clf()
    plt.close(fig)


for sleep_time in unique_sleep_times:
    save_line_chart("thrpt", "Throughput (Requests/sec)", "Throughput vs Concurrent Users for " + str(sleep_time) + "ms backend delay",
                    ylabel="Throughput (Requests/sec)")
    save_line_chart("avgt", "Average Response Time (ms)",
                    "Average Response Time vs Concurrent Users for " + str(sleep_time) + "ms backend delay",
                    ylabel="Average Response Time (ms)")
    save_line_chart("gc", "WSO2 API Manager GC Throughput (%)",
                    "GC Throughput vs Concurrent Users for " + str(sleep_time) + "ms backend delay",
                    ylabel="GC Throughput (%)")
    df_results = df.loc[df['Back-end Service Delay (ms)'] == sleep_time]
    chart_suffix = "_" + str(sleep_time) + "ms"
    # apimchart.save_multi_columns_categorical_charts(df_results, "loadavg" + chart_suffix,
    #                                                 ['WSO2 API Manager - System Load Average - Last 1 minute',
    #                                                  'WSO2 API Manager - System Load Average - Last 5 minutes',
    #                                                  'WSO2 API Manager - System Load Average - Last 15 minutes'],
    #                                                 "Load Average", "API Manager",
    #                                                 "Load Average with " + str(sleep_time) + "ms backend delay")
    # apimchart.save_multi_columns_categorical_charts(df_results, "network" + chart_suffix,
    #                                                 ['Received (KB/sec)', 'Sent (KB/sec)'],
    #                                                 "Network Throughput (KB/sec)", "Network",
    #                                                 "Network Throughput with " + str(sleep_time) + "ms backend delay")
    # apimchart.save_multi_columns_categorical_charts(df_results, "response_time" + chart_suffix,
    #                                                 ['90th Percentile of Response Time (ms)', '95th Percentile of Response Time (ms)',
    #                                                  '99th Percentile of Response Time (ms)'],
    #                                                 "Response Time (ms)", "Response Time",
    #                                                 "Response Time Percentiles with " + str(sleep_time)
    #                                                 + "ms backend delay", kind='bar')
    for message_size in unique_message_sizes:
        save_bar_chart(
            "Response Time Summary for \nGraphQL Query Number " + str(message_size) + " \n(Operation count: 1 | Query depth: 2 | Query size: 157B | Response size: 790B)")

print("Done")
