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
# Create AWS CloudFormation template
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
    parser = argparse.ArgumentParser(description='Create AWS CloudFormation template.')
    parser.add_argument('--template-name', required=True, help='The template file name.', type=str)
    parser.add_argument('--jmeter-servers', required=True, help='Number of JMeter Servers.', type=int)
    parser.add_argument('--output-name', required=True, help='Output file name.', type=str)

    args = parser.parse_args()

    context = {'jmeter_servers': args.jmeter_servers, 'start_bastian': True}

    with open(args.output_name, 'w') as f:
        markdown_file = render_template(args.template_name, context)
        f.write(markdown_file.encode("utf-8"))


if __name__ == "__main__":
    main()
