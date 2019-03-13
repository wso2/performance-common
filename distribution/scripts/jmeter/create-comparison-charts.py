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

from . import draw_charts

sns.set_style("darkgrid")


def save_lmplots(df_original):
    xcolumns = ['Message Size (Bytes)', 'Back-end Service Delay (ms)', 'Concurrent Users']
    xcharts = ['message_size', 'sleep_time', 'concurrent_users']

    ycolumns = ['Throughput (Requests/sec)', 'Average Response Time (ms)', 'Maximum Response Time (ms)', '90th Percentile of Response Time (ms)', '95th Percentile of Response Time (ms)',
                '99th Percentile of Response Time (ms)', 'WSO2 API Manager GC Throughput (%)', 'WSO2 API Manager Load Average - Last 1 minute', 'WSO2 API Manager Load Average - Last 5 minutes',
                'WSO2 API Manager Load Average - Last 15 minutes']

    ycharts = ['lmplot_throughput', 'lmplot_average_time', 'lmplot_max_time', 'lmplot_p90', 'lmplot_p95', 'lmplot_p99',
               'lmplot_gc_throughput', 'lmplot_loadavg_1', 'lmplot_loadavg_5', 'lmplot_loadavg_15']

    ylabels = ['Throughput (Requests/sec)', 'Average Response Time (ms)', 'Maximum Response Time (ms)',
               '90th Percentile (ms)', '95th Percentile (ms)', '99th Percentile (ms)', 'GC Throughput (%)',
               'Load Average - Last 1 minute', 'Load Average - Last 5 minutes',
               'Load Average - Last 15 minutes']

    for ycolumn, ylabel, ychart in zip(ycolumns, ylabels, ycharts):
        for xcolumn, xchart in zip(xcolumns, xcharts):
            chart = ychart + '_vs_' + xchart
            title = ylabel + ' vs ' + xcolumn

            draw_charts.save_lmplot(df_original, chart, xcolumn, ycolumn, title, ylabel=ylabel)
            draw_charts.save_lmplot(df_original, chart + '_with_hue', xcolumn, ycolumn, title, hue='Scenario Name', ylabel=ylabel)


def save_point_plots(df):
    unique_delay_time = df['Back-end Service Delay (ms)'].unique()
    unique_message_sizes_in_df_all = df['Message Size (Bytes)'].unique()

    for sleep_time in unique_delay_time:
        for message_size in unique_message_sizes_in_df_all:

            df_filtered = df.loc[
                (df['Message Size (Bytes)'] == message_size) & (df['Back-end Service Delay (ms)'] == sleep_time)]

            chart_suffix = '_' + str(draw_charts.format_time(sleep_time)) + '_' + str(message_size)
            title_suffix = ' vs Concurrent Users for ' + str(
                message_size) + ' messages with ' + str(draw_charts.format_time(sleep_time)) + ' backend delay'

            ycolumns = ['Throughput (Requests/sec)', 'Average Response Time (ms)', 'Maximum Response Time (ms)', '90th Percentile of Response Time (ms)', '95th Percentile of Response Time (ms)',
                        '99th Percentile of Response Time (ms)', 'WSO2 API Manager GC Throughput (%)']
            charts = ['throughput', 'average_time', 'max_time', 'p90', 'p95', 'p99', 'gc_throughput']
            ylabels = ['Throughput (Requests/sec)', 'Average Response Time (ms)', 'Maximum Response Time (ms)',
                       '90th Percentile (ms)', '95th Percentile (ms)', '99th Percentile (ms)', 'GC Throughput (%)']

            for ycolumn, ylabel, chart in zip(ycolumns, ylabels, charts):
                draw_charts.save_point_plot(df_filtered, chart + chart_suffix, 'Concurrent Users', ycolumn,
                                            ylabel + title_suffix, hue='Scenario Name', ylabel=ylabel)


def save_comparison_plots(df):
    isSingleComparison = False
    unique_delay_time = df['Back-end Service Delay (ms)'].unique()
    unique_message_sizes_in_df = df['Message Size (Bytes)'].unique()

    comparison_columns = [['Throughput (Requests/sec)'], ['Average Response Time (ms)'],
                          ['90th Percentile of Response Time (ms)', '95th Percentile of Response Time (ms)',
                           '99th Percentile of Response Time (ms)'],
                          ['WSO2 API Manager Load Average - Last 1 minute',
                           'WSO2 API Manager Load Average - Last 5 minutes',
                           'WSO2 API Manager Load Average - Last 15 minutes'], ['Received (KB/sec)', 'Sent (KB/sec)'],
                          ['WSO2 API Manager GC Throughput (%)']
                          ]

    for sleep_time in unique_delay_time:

        df_temp = df.loc[df['Back-end Service Delay (ms)'] == sleep_time]

        draw_charts.save_multi_columns_categorical_charts(df_temp, "comparison_thrpt_" + str(sleep_time) + "ms",
                                                          comparison_columns[0],
                                                        "Throughput (Requests/sec)",
                                                        "Throughput vs Concurrent Users for " + str(
                                                            sleep_time) + "ms backend delay", 'Message Size (Bytes)',
                                                          isSingleComparison, len(comparison_columns[0]) == 1,
                                                          kind='point')

        draw_charts.save_multi_columns_categorical_charts(df_temp, "comparison_avgt_" + str(sleep_time) + "ms",
                                                          comparison_columns[1],
                                                        "Average Response Time (ms)",
                                                        "Average Response Time vs Concurrent Users for " + str(
                                                            sleep_time) + "ms backend delay", 'Message Size (Bytes)',
                                                          isSingleComparison, len(comparison_columns[1]) == 1,
                                                          kind='point')

        draw_charts.save_multi_columns_categorical_charts(df_temp, "comparison_response_time_" + str(sleep_time) + "ms",
                                                          comparison_columns[2], "Response Time (ms)",
                                                        "Response Time Percentiles for " + str(
                                                            sleep_time) + "ms backend delay", 'Message Size (Bytes)',
                                                          isSingleComparison, len(comparison_columns[2]) == 1,
                                                          kind='bar')

        draw_charts.save_multi_columns_categorical_charts(df_temp, "comparison_loadavg_" + str(sleep_time) + "ms",
                                                          comparison_columns[3], "Load Average",
                                                        "Load Average with " + str(sleep_time) + "ms backend delay",
                                                        'Message Size (Bytes)', isSingleComparison,
                                                          len(comparison_columns[3]) == 1, kind='point')

        draw_charts.save_multi_columns_categorical_charts(df_temp, "comparison_network" + str(sleep_time) + "ms",
                                                          comparison_columns[4],
                                                        "Network Throughput (KB/sec)",
                                                        "Network Throughput with " + str(
                                                            sleep_time) + "ms backend delay", 'Message Size (Bytes)',
                                                          isSingleComparison, len(comparison_columns[4]) == 1,
                                                          kind='point')

        draw_charts.save_multi_columns_categorical_charts(df_temp, "comparison_gc" + str(sleep_time) + "ms",
                                                          comparison_columns[5],
                                                        "WSO2 API Manager GC Throughput (%)",
                                                        "GC Throughput with " + str(sleep_time) + "ms backend delay",
                                                        'Message Size (Bytes)', isSingleComparison,
                                                          len(comparison_columns[5]) == 1, kind='point')

        for message_size in unique_message_sizes_in_df:
            df_message_temp = df_temp.loc[df_temp['Message Size (Bytes)'] == message_size]

            chart_suffix = '_' + draw_charts.format_time(sleep_time) + '_' + message_size
            title_suffix = " for " + message_size + " messages with " + draw_charts.format_time(
                sleep_time) + " backend delay"

            draw_charts.save_bar_plot(df_message_temp, 'response_time' + chart_suffix,
                                      comparison_columns[2],
                                    'Response Time (ms)',
                                    "Response Time Percentiles" + title_suffix)

            draw_charts.save_bar_plot(df_message_temp, 'loadavg' + chart_suffix,
                                      comparison_columns[3],
                                    "Load Average",
                                    "Load Average" + title_suffix)


def save_single_comparison_plots(df):
    isSingleComparison = True
    chart_prefix = 'comparison_'
    charts = ['thrpt', 'avgt', 'gc', 'response_time', 'loadavg', 'network']
    # Removed '90th Percentile (ms)'. Too much data points

    comparison_columns = [['Throughput (Requests/sec)'], ['Average Response Time (ms)'],
                          ['WSO2 API Manager GC Throughput (%)'],
                          ['95th Percentile of Response Time (ms)', '99th Percentile of Response Time (ms)'],
                          ['WSO2 API Manager Load Average - Last 1 minute',
                           'WSO2 API Manager Load Average - Last 5 minutes',
                           'WSO2 API Manager Load Average - Last 15 minutes'], ['Received (KB/sec)', 'Sent (KB/sec)']
                          ]

    ycolumns = ['Throughput (Requests/sec)', 'Average Response Time (ms)', 'WSO2 API Manager GC Throughput (%)',
                'Response Time (ms)', 'Load Average',
                'Network Throughput (KB/sec)']

    title_prefixes = ['Throughput', 'Average Response Time', 'GC Throughput', 'Response Time Percentiles',
                      'Load Average',
                      'Network Throughput']

    plot_kinds = ['point', 'point', 'point', 'bar', 'point', 'point']

    for chart, columns, y, title_prefix, plot_kind in zip(charts, comparison_columns, ycolumns, title_prefixes,
                                                          plot_kinds):
        draw_charts.save_multi_columns_categorical_charts(df, chart_prefix + chart, columns, y,
                                                          title_prefix + ' vs Concurrent Users',
                                                        'Back-end Service Delay (ms)', isSingleComparison,
                                                          len(columns) == 1, kind=plot_kind)


if __name__ == "__main__":
    df_original = pd.read_csv('summary.csv')
    # Filter errors
    df_original = df_original.loc[df_original['Error Count'] < 100]
    df = df_original.copy()
    df['Message Size (Bytes)'] = df['Message Size (Bytes)'].map(draw_charts.format_bytes)

    save_single_comparison_plots(df)
    save_comparison_plots(df)
    save_point_plots(df)
    save_lmplots(df_original)

    print("Done")