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
# Create charts from the summary.csv file
# ----------------------------------------------------------------------------
import pandas as pd
import argparse
import plotcommon


def main():
    parser = argparse.ArgumentParser(description='Create plots')
    parser.add_argument('-f', '--file', required=False,
                        help='The summary CSV file name.', type=str, default='summary.csv')
    args = parser.parse_args()

    PLOT_COLUMN_RANGE_START = plotcommon.PLOT_COLUMN_RANGE_START
    PLOT_COLUMN_RANGE_END = plotcommon.PLOT_COLUMN_RANGE_END

    print("Reading " + args.file + " file...")
    df = pd.read_csv(args.file)
    # Save lmplots first
    unique_heap_sizes = df['Heap Size'].unique()
    for heap_size in unique_heap_sizes:
        df_heap = df.loc[df['Heap Size'] == heap_size]
        xcolumns = ["Concurrent Users", "GraphQL Query Number", "Back-end Service Delay (ms)"]
        for xcolumn in xcolumns:
            for ycolumn in df.columns[PLOT_COLUMN_RANGE_START:PLOT_COLUMN_RANGE_END]:
                file_suffix = "-" + heap_size + ".png"
                plotcommon.save_lm_plot(
                    "lmplot-" + plotcommon.get_filename(ycolumn) + "-" + plotcommon.get_filename(xcolumn) + file_suffix,
                    xcolumn, ycolumn, ycolumn + " vs " + xcolumn, df_heap)

    df.rename(columns={'GraphQL Query Number': 'Query Number',
                       'Back-end Service Delay (ms)': 'Back-end Service Delay'},
              inplace=True)
    # Format query number values
    df['Query Number'] = df['Query Number'].map(plotcommon.format_query_number)
    # Format time
    df['Back-end Service Delay'] = df['Back-end Service Delay'].map(plotcommon.format_time)

    unique_backend_delays = df['Back-end Service Delay'].unique()
    unique_query_numbers = df['Query Number'].unique()

    for heap_size in unique_heap_sizes:
        df_heap = df.loc[df['Heap Size'] == heap_size]

        for backend_delay in unique_backend_delays:
            # Plot individual charts for query numbers
            for query_number in unique_query_numbers:
                df_data = df_heap.loc[
                    (df_heap['Query Number'] == query_number) & (df_heap['Back-end Service Delay'] == backend_delay)]
                file_suffix = "-" + heap_size + "-" + query_number + "-" + backend_delay + ".png"
                subtitle = "Memory = " + heap_size + ", Query Number = " + query_number + ", Back-end Service Delay = " + backend_delay
                for ycolumn in df.columns[PLOT_COLUMN_RANGE_START:PLOT_COLUMN_RANGE_END]:
                    plotcommon.save_line_plot("lineplot-" + plotcommon.get_filename(ycolumn) + file_suffix, ycolumn,
                                              ycolumn + " vs Concurrent Users", subtitle, df_data)

            # Categorical plots by Query Number
            for ycolumn in df.columns[PLOT_COLUMN_RANGE_START:PLOT_COLUMN_RANGE_END]:
                # Cat plot for each backend delay, with GraphQL query number as column
                df_data = df_heap.loc[df_heap['Back-end Service Delay'] == backend_delay]
                file_suffix = "-" + heap_size + "-" + backend_delay + ".png"
                subtitle = "Memory = " + heap_size + ", Back-end Service Delay = " + backend_delay
                plotcommon.save_cat_plot("catplot-" + plotcommon.get_filename(ycolumn) + file_suffix, ycolumn,
                                         ycolumn + " vs Concurrent Users", subtitle, df_data, "Query Number")

    print("Done")


if __name__ == "__main__":
    main()
