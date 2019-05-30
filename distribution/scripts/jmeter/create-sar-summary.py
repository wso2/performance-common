#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright (c) 2019, WSO2 Inc. (http://wso2.org) All Rights Reserved.
#
# WSO2 Inc. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# ----------------------------------------------------------------------------
# Create summary of SAR reports
# ----------------------------------------------------------------------------

import argparse
import pandas as pd
import json
import re


def main():
    parser = argparse.ArgumentParser(
        description='Create SAR summary from CSV reports')
    parser.add_argument('--start-timestamp', required=True,
                        help='Start timestamp in seconds.', type=int)
    parser.add_argument('--end-timestamp', required=True,
                        help='End timestamp in seconds.', type=int)
    parser.add_argument('--sar-csv-reports', required=True,
                        help='SAR CSV reports.', nargs='+', type=str)
    parser.add_argument('--output-file', default="sar-summary.json", required=False,
                        help='Output JSON file')
    args = parser.parse_args()

    sar_averages = {}

    for sar_report in args.sar_csv_reports:
        try:
            print('Reading {filename}'.format(filename=sar_report))
            df = pd.read_csv(sar_report, sep=';')
        except pd.errors.EmptyDataError:
            print('WARNING: {filename} was empty. Skipping.'.format(
                filename=sar_report))
            continue

        df = df[(df['timestamp'] >= args.start_timestamp)
                & (df['timestamp'] <= args.end_timestamp)]
        df = df.drop(columns=['hostname', 'interval', 'timestamp'])
        df = df.rename(columns=lambda x: re.sub(r'[%/\-]', '', x))
        sar_averages.update(df.mean().round(2).to_dict())

    with open(args.output_file, 'w') as outfile:
        json.dump(sar_averages, outfile)


if __name__ == "__main__":
    main()
