#!/usr/bin/env python3
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
# Create comparison charts from multiple summary.csv files
# ----------------------------------------------------------------------------
import pandas as pd
import argparse
import plotcommon
import sys


def main():
    parser = argparse.ArgumentParser(description='Create comparison plots')
    parser.add_argument('-f', '--files', required=True,
                        help='The summary CSV file names.', nargs='+', type=str)
    parser.add_argument('-n', '--column-name', required=True,
                        help='The comparison column name.', type=str)
    parser.add_argument('-v', '--comparison-values', required=True,
                        help='The comparison column values for each summary file.', nargs='+', type=str)
    args = parser.parse_args()

    if len(args.files) < 2:
        print("Please provide at least two summary files with labels.")
        sys.exit(1)

    if len(args.files) != len(args.comparison_values):
        print("Please provide a label for each summary file.")
        sys.exit(1)

    df = None

    for value, csv_file in zip(args.comparison_values, args.files):
        print("Reading " + csv_file + " file for value: " + value)
        df_csv = pd.read_csv(csv_file)
        df_csv.insert(0, args.column_name, value)
        if df is None:
            df = df_csv.copy()
        else:
            df = df.append(df_csv, ignore_index=True)


    df.rename(columns={'Message Size (Bytes)': 'Message Size',
                       'Back-end Service Delay (ms)': 'Back-end Service Delay'},
              inplace=True)
    # Format message size values
    df['Message Size'] = df['Message Size'].map(plotcommon.format_bytes)
    # Format time
    df['Back-end Service Delay'] = df['Back-end Service Delay'].map(plotcommon.format_time)

    unique_heap_sizes = df['Heap Size'].unique()
    unique_backend_delays = df['Back-end Service Delay'].unique()
    unique_message_sizes = df['Message Size'].unique()

    PLOT_COLUMN_RANGE_START = plotcommon.PLOT_COLUMN_RANGE_START + 1
    PLOT_COLUMN_RANGE_END = plotcommon.PLOT_COLUMN_RANGE_END + 1

    for heap_size in unique_heap_sizes:
        df_heap = df.loc[df['Heap Size'] == heap_size]
        for backend_delay in unique_backend_delays:
            for message_size in unique_message_sizes:
                df_data = df_heap.loc[
                    (df_heap['Message Size'] == message_size) & (df_heap['Back-end Service Delay'] == backend_delay)]
                file_suffix = "-" + heap_size + "-" + message_size + "-" + backend_delay + ".png"
                subtitle = "Memory = " + heap_size + ", Message Size = " + message_size + ", Back-end Service Delay = " + backend_delay
                for ycolumn in df.columns[PLOT_COLUMN_RANGE_START:PLOT_COLUMN_RANGE_END]:
                    plotcommon.save_cat_plot("comparison-catplot-" + plotcommon.get_filename(ycolumn) + file_suffix,
                                             ycolumn, ycolumn + " vs Concurrent Users", subtitle, df_data,
                                             args.column_name)

    print("Done")


if __name__ == "__main__":
    main()
