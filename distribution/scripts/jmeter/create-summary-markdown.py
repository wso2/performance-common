#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright (c) 2018, WSO2 Inc. (http://wso2.org) All Rights Reserved.
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
# Create performance test results summary markdown file
# ----------------------------------------------------------------------------

import argparse
import csv
import json
import os
from jinja2 import Environment, FileSystemLoader

PATH = os.path.dirname(os.path.abspath(__file__))
TEMPLATE_ENVIRONMENT = Environment(
    autoescape=False,
    loader=FileSystemLoader(os.path.join(PATH, 'templates')),
    trim_blocks=False,
    keep_trailing_newline=True)


def render_template(template_filename, context):
    return TEMPLATE_ENVIRONMENT.get_template(template_filename).render(context)


def main():
    parser = argparse.ArgumentParser(description='Create summary report')
    parser.add_argument('--json-files', required=True, help='JSON files with parameters.', nargs='+', type=str)
    parser.add_argument('--column-names', required=True, help='Columns to include in the report.', nargs='+', type=str)
    args = parser.parse_args()

    json_parameters = {}

    for j in args.json_files:
        with open(j) as f:
            json_parameters.update(json.load(f))

    column_names_set = set(args.column_names)
    rows = []

    with open('summary.csv') as csv_file:
        reader = csv.DictReader(csv_file)
        for row in reader:
            filtered_row = dict(
                (name, value) for name, value in row.items() if name in column_names_set
            )
            rows.append(filtered_row)

        context = {
            'column_names': args.column_names,
            'parameters': json_parameters,
            'rows': rows
        }

    markdown_filename = "summary.md"
    with open(markdown_filename, 'wb') as f:
        markdown_file = render_template(markdown_filename, context)
        f.write(markdown_file.encode("utf-8"))


if __name__ == "__main__":
    main()
