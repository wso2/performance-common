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
# Common python module to save charts
# ----------------------------------------------------------------------------
import matplotlib.pyplot as plt
import matplotlib.ticker as tkr
import pandas as pd
import seaborn as sns
import re

sns.set_style("darkgrid")

PLOT_COLUMN_RANGE_START = 9
PLOT_COLUMN_RANGE_END = 23


def get_filename(value):
    value = re.sub(r'\(.*\)', '', value).strip().lower()
    value = re.sub(r'[^\w\s-]', '', value).strip()
    value = re.sub(r'[-\s]+', '-', value)
    return value


def format_bytes(b):
    if b >= 1024 and b % 1024 == 0:
        return str(b // 1024) + 'KiB'
    return str(b) + 'B'


def format_time(t):
    if t >= 1000 and t % 1000 == 0:
        return str(t // 1000) + 's'
    return str(t) + 'ms'


def save_line_plot(filename, y, maintitle, subtitle, df):
    print("Creating " + filename)
    fig, ax = plt.subplots(figsize=(8, 6))
    sns.lineplot(x="Concurrent Users", y=y, hue="Scenario Name", data=df, markers=True, style="Scenario Name", dashes=False)
    ax.yaxis.set_major_formatter(tkr.FuncFormatter(lambda y, p: "{:,}".format(y)))
    plt.suptitle(maintitle)
    plt.title(subtitle)
    plt.savefig(filename)
    plt.clf()
    plt.close(fig)


def save_lm_plot(filename, x, y, maintitle, df):
    print("Creating " + filename)
    g = sns.lmplot(x=x, y=y, hue="Scenario Name", data=df, height=7)
    for ax in g.axes.flatten():
        ax.yaxis.set_major_formatter(tkr.FuncFormatter(lambda y_value, p: "{:,}".format(y_value)))
    g.set(ylim=(0, None), xlim=(0, None))
    plt.subplots_adjust(top=0.9)
    g.fig.suptitle(maintitle)
    g.savefig(filename)
    plt.clf()
    plt.close(g.fig)


def save_cat_plot(filename, y, maintitle, subtitle, df, col):
    print("Creating " + filename)
    g = sns.catplot(x="Concurrent Users", y=y, hue="Scenario Name", col=col, data=df, kind='point', height=7, col_wrap=2)
    for ax in g.axes.flatten():
        ax.yaxis.set_major_formatter(tkr.FuncFormatter(lambda y_value, p: "{:,}".format(y_value)))
    plt.subplots_adjust(top=0.9)
    g.fig.suptitle(maintitle + "\n" + subtitle)
    g.savefig(filename)
    plt.clf()
    plt.close(g.fig)
